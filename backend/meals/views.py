from datetime import datetime, timedelta

from django.db.models import Sum
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view, parser_classes, permission_classes
from rest_framework.generics import ListCreateAPIView
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .claude import ClaudeError, analyze_meal
from .models import Meal
from .serializers import MealSerializer


def _to_int(value, default=0):
    try:
        return max(0, int(round(float(value))))
    except (TypeError, ValueError):
        return default


def _to_float(value, default=0.0):
    try:
        return max(0.0, min(1.0, float(value)))
    except (TypeError, ValueError):
        return default


class MealListCreateView(ListCreateAPIView):
    """GET ?date=YYYY-MM-DD -> meals for that day. POST image -> Claude -> meal."""

    serializer_class = MealSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        qs = Meal.objects.filter(user=self.request.user)
        date_str = self.request.query_params.get("date")
        if date_str:
            try:
                day = datetime.strptime(date_str, "%Y-%m-%d").date()
                qs = qs.filter(created_at__date=day)
            except ValueError:
                pass
        return qs

    def create(self, request, *args, **kwargs):
        image = request.FILES.get("image")
        note = request.data.get("note", "")

        # Pre-analyzed save: the client already ran /api/analyze/ (or is migrating
        # guest meals) and sends the nutrition values, so we skip Claude here.
        if request.data.get("food_name") and request.data.get("calories") is not None:
            meal = Meal.objects.create(
                user=request.user,
                image=image if image is not None else None,
                food_name=str(request.data["food_name"])[:200],
                calories=_to_int(request.data.get("calories")),
                protein=_to_int(request.data.get("protein")),
                carbs=_to_int(request.data.get("carbs")),
                fat=_to_int(request.data.get("fat")),
                confidence=_to_float(request.data.get("confidence")),
                note=note,
            )
            return Response(self.get_serializer(meal).data, status=status.HTTP_201_CREATED)

        # Legacy path: image only -> run Claude, then save.
        if image is None:
            return Response(
                {"detail": "An 'image' file is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        image_bytes = image.read()
        try:
            result = analyze_meal(image_bytes, note=note)
        except ClaudeError as exc:
            return Response(
                {"detail": str(exc)},
                status=status.HTTP_502_BAD_GATEWAY,
            )

        # rewind so ImageField can save the file
        image.seek(0)
        meal = Meal.objects.create(
            user=request.user,
            image=image,
            food_name=result["food"],
            calories=result["calories"],
            protein=result["protein_g"],
            carbs=result["carbs_g"],
            fat=result["fat_g"],
            confidence=result["confidence"],
            note=note,
        )
        serializer = self.get_serializer(meal)
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class MealDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def delete(self, request, pk):
        deleted, _ = Meal.objects.filter(user=request.user, pk=pk).delete()
        if not deleted:
            return Response(status=status.HTTP_404_NOT_FOUND)
        return Response(status=status.HTTP_204_NO_CONTENT)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def weekly_stats(request):
    """Per-day totals for the last 7 days (oldest -> newest)."""
    today = timezone.localdate()
    days = []
    for offset in range(6, -1, -1):
        day = today - timedelta(days=offset)
        agg = Meal.objects.filter(user=request.user, created_at__date=day).aggregate(
            calories=Sum("calories"),
            protein=Sum("protein"),
            carbs=Sum("carbs"),
            fat=Sum("fat"),
        )
        days.append({
            "date": day.isoformat(),
            "calories": agg["calories"] or 0,
            "protein": agg["protein"] or 0,
            "carbs": agg["carbs"] or 0,
            "fat": agg["fat"] or 0,
        })

    goal = request.user.daily_calorie_goal
    return Response({"goal": goal, "days": days})


@api_view(["POST"])
@permission_classes([AllowAny])
@parser_classes([MultiPartParser, FormParser])
def analyze(request):
    """Anonymous: image -> Claude -> nutrition JSON. Nothing is saved.

    Powers guest mode — the camera -> Claude moneyshot works without an account.
    The app saves the result locally (guest) or POSTs it to /api/meals/ (logged in).
    """
    image = request.FILES.get("image")
    if image is None:
        return Response(
            {"detail": "An 'image' file is required."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    note = request.data.get("note", "")
    try:
        result = analyze_meal(image.read(), note=note)
    except ClaudeError as exc:
        return Response({"detail": str(exc)}, status=status.HTTP_502_BAD_GATEWAY)

    # Return field names matching the iOS Meal/Analysis shape (snake_case).
    return Response({
        "food_name": result["food"],
        "calories": result["calories"],
        "protein": result["protein_g"],
        "carbs": result["carbs_g"],
        "fat": result["fat_g"],
        "confidence": result["confidence"],
    })
