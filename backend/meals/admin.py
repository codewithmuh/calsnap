from django.contrib import admin

from .models import Meal


@admin.register(Meal)
class MealAdmin(admin.ModelAdmin):
    list_display = ("food_name", "meal_type", "calories", "user", "created_at")
    list_filter = ("meal_type", "created_at")
    search_fields = ("food_name", "user__email")
