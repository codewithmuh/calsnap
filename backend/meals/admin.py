from django.contrib import admin

from .models import Meal


@admin.register(Meal)
class MealAdmin(admin.ModelAdmin):
    list_display = ("food_name", "calories", "user", "created_at")
    list_filter = ("created_at",)
    search_fields = ("food_name", "user__email")
