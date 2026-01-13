# leccion/admin.py
from django.contrib import admin
from .models import (
    Lesson, LessonLocalization,
    Exercise, ExerciseLocalization, ExerciseOption,
    UserLessonProgress
)

class ExerciseOptionInline(admin.TabularInline):
    model = ExerciseOption
    extra = 1

class ExerciseLocalizationInline(admin.StackedInline):
    model = ExerciseLocalization
    extra = 1

@admin.register(Exercise)
class ExerciseAdmin(admin.ModelAdmin):
    list_display = ("id", "lesson", "exercise_type", "sequence")
    list_filter = ("exercise_type", "lesson__level")
    search_fields = ("lesson__title_key",)
    inlines = [ExerciseLocalizationInline]

class LessonLocalizationInline(admin.StackedInline):
    model = LessonLocalization
    extra = 1

@admin.register(Lesson)
class LessonAdmin(admin.ModelAdmin):
    list_display = ("id", "title_key", "level", "lesson_type", "sequence", "difficulty", "is_active", "priority")
    list_filter = ("level", "lesson_type", "is_active")
    search_fields = ("title_key",)
    inlines = [LessonLocalizationInline]

@admin.register(LessonLocalization)
class LessonLocalizationAdmin(admin.ModelAdmin):
    list_display = ("id", "lesson", "native_language", "target_language", "title")
    list_filter = ("native_language", "target_language", "lesson__level")
    search_fields = ("lesson__title_key", "title")

@admin.register(ExerciseLocalization)
class ExerciseLocalizationAdmin(admin.ModelAdmin):
    list_display = ("id", "exercise", "native_language", "target_language")
    list_filter = ("native_language", "target_language", "exercise__exercise_type")
    search_fields = ("exercise__lesson__title_key", "question")
    inlines = [ExerciseOptionInline]

@admin.register(ExerciseOption)
class ExerciseOptionAdmin(admin.ModelAdmin):
    list_display = ("id", "exercise_localization", "text", "is_correct")
    list_filter = ("is_correct",)
    search_fields = ("text",)

@admin.register(UserLessonProgress)
class UserLessonProgressAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "lesson", "native_language", "target_language",
                    "completed", "score", "total_exercises", "correct_exercises", "incorrect_exercises")
    list_filter = ("completed", "native_language", "target_language", "lesson__level")
    search_fields = ("user__username", "lesson__title_key")
