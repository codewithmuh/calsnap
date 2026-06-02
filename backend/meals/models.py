from django.conf import settings
from django.db import models


class Meal(models.Model):
    class MealType(models.TextChoices):
        BREAKFAST = "breakfast", "Breakfast"
        LUNCH = "lunch", "Lunch"
        DINNER = "dinner", "Dinner"

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="meals",
    )
    image = models.ImageField(upload_to="meals/%Y/%m/%d/", blank=True, null=True)
    meal_type = models.CharField(
        max_length=20, choices=MealType.choices, default=MealType.LUNCH
    )
    food_name = models.CharField(max_length=200)
    calories = models.PositiveIntegerField(default=0)
    protein = models.PositiveIntegerField(default=0)
    carbs = models.PositiveIntegerField(default=0)
    fat = models.PositiveIntegerField(default=0)
    confidence = models.FloatField(default=0.0)
    note = models.CharField(max_length=280, blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("-created_at",)

    def __str__(self):
        return f"{self.food_name} ({self.calories} kcal)"
