# users/admin.py
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import User, UserProgress, LearningStats


class UserProgressInline(admin.TabularInline):
    model = UserProgress
    extra = 0
    readonly_fields = ("date",)


class LearningStatsInline(admin.StackedInline):
    model = LearningStats
    can_delete = False
    verbose_name = "Estadísticas de aprendizaje"


@admin.register(User)
class CustomUserAdmin(UserAdmin):
    fieldsets = UserAdmin.fieldsets + (
        ("Perfil", {"fields": ("native_language", "target_language", "age", "level", "nationality")} ),
    )

    inlines = (LearningStatsInline, UserProgressInline)

    list_display = ("username", "email", "first_name", "last_name", "level", "target_language", "native_language", "is_staff", "last_login")
    list_filter = ("level", "target_language", "is_staff", "is_superuser", "is_active")
    search_fields = ("username", "email", "first_name", "last_name")
    readonly_fields = ("date_joined", "last_login", "registration_date")
