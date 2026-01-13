# leccion/urls.py
from django.urls import path
from .views import (
    # Lecciones
    LessonDetailView, AllLessonsView, ExercisesByLevelLessonView,
    # Adaptatividad
    AdaptiveLessonView, NextAvailableLessonView,
    # Progreso
    LessonProgressView,
    # Ejercicios / Pronunciación
    ShadowingExerciseView, ExerciseSubmissionView,
    PronunciationFeedbackView, PronunciationSubmissionView,
)

urlpatterns = [
    # Detalle de lección: /api/lessons/<pk>/?native=es&target=en
    path('<int:pk>/', LessonDetailView.as_view(), name='lesson-detail'),

    # Listado general: /api/lessons/all-lessons/?level=A1&native=es&target=en
    path('all-lessons/', AllLessonsView.as_view(), name='all-lessons'),

    # Ejercicios por nivel y lección:
    # /api/lessons/levels/A1/lessons/12/exercises/?native=es&target=en
    path(
        'levels/<str:level>/lessons/<int:lesson_id>/exercises/',
        ExercisesByLevelLessonView.as_view(),
        name='exercises-by-level-lesson'
    ),

    # Adaptatividad
    # /api/lessons/adaptive/?native=es&target=fr
    path('adaptive/', AdaptiveLessonView.as_view(), name='adaptive-lesson'),
    # /api/lessons/next-available/?native=es&target=fr
    path('next-available/', NextAvailableLessonView.as_view(), name='next-available-lesson'),

    # Progreso
    # GET/POST /api/lessons/progress/?native=es&target=en
    path('progress/', LessonProgressView.as_view(), name='lesson-progress'),
    # Backwards-compatible URL used by older clients
    path('lesson-progress/', LessonProgressView.as_view(), name='lesson-progress-legacy'),

    # Ejercicios especiales / envío
    path('exercises/shadowing/', ShadowingExerciseView.as_view(), name='shadowing-exercise'),
    path('exercises/submit/', ExerciseSubmissionView.as_view(), name='exercise-submit'),

    # Pronunciación (Whisper real y simulación)
    path('pronunciation/feedback/', PronunciationFeedbackView.as_view(), name='pronunciation-feedback'),
    path('pronunciation/simulate/', PronunciationSubmissionView.as_view(), name='pronunciation-simulate'),
]
