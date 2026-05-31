from django.urls import path

from .views import MealDetailView, MealListCreateView, weekly_stats

urlpatterns = [
    path("meals/", MealListCreateView.as_view(), name="meal-list-create"),
    path("meals/<int:pk>/", MealDetailView.as_view(), name="meal-detail"),
    path("stats/weekly", weekly_stats, name="weekly-stats"),
]
