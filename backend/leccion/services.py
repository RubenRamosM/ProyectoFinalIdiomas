# leccion/services.py
from typing import Optional, Iterable
from django.db.models import Prefetch, QuerySet
from .models import (
    Lesson, LessonLocalization,
    Exercise, ExerciseLocalization,
    UserLessonProgress
)
from core.models import Language


def lessons_for_pair(level: str, native_code: str, target_code: str) -> QuerySet:
    """
    Retorna las lecciones ACTIVAS del nivel indicado que tengan localización
    para el par nativo→objetivo. Incluye prefetch para rendimiento.
    Orden: sequence, difficulty, -priority, created_at.
    """
    return (
        Lesson.objects
        .filter(
            is_active=True,
            level=level,
            localizations__native_language__code=native_code,
            localizations__target_language__code=target_code
        )
        .prefetch_related(
            'localizations',
            Prefetch(
                'exercises__localizations',
                queryset=ExerciseLocalization.objects.filter(
                    native_language__code=native_code,
                    target_language__code=target_code
                ).prefetch_related('options')
            )
        )
        .order_by('sequence', 'difficulty', '-priority', 'created_at')
        .distinct()
    )


def _get_done_ids_for_pair(user, native_code: str, target_code: str) -> set:
    """
    IDs de lecciones completadas por el usuario para el par nativo→objetivo.
    """
    return set(
        UserLessonProgress.objects.filter(
            user=user,
            completed=True,
            native_language__code=native_code,
            target_language__code=target_code
        ).values_list('lesson_id', flat=True)
    )


def _get_prereq_ids(lesson: Lesson) -> set:
    """
    Devuelve IDs de prerequisitos si el modelo Lesson define ese M2M.
    Si no existe, retorna conjunto vacío (sin prerequisitos).
    """
    if hasattr(lesson, 'prerequisites'):
        try:
            return set(lesson.prerequisites.values_list('id', flat=True))
        except Exception:
            return set()
    return set()


def next_lesson_for_user(
    user,
    level: str,
    native_code: str = 'es',
    target_code: str = 'en'
) -> Optional[Lesson]:
    """
    Devuelve la siguiente lección pendiente para el usuario en el nivel dado,
    considerando SOLO lecciones con localización para (native_code → target_code).

    Criterios:
      1) Orden por sequence, difficulty, -priority, created_at.
      2) La lección no debe estar completada para ese par.
      3) Debe cumplir prerequisitos (si el modelo los define).
    """
    qs = lessons_for_pair(level, native_code, target_code)
    done_ids = _get_done_ids_for_pair(user, native_code, target_code)

    for lesson in qs:
        prereq_ids = _get_prereq_ids(lesson)
        if prereq_ids.issubset(done_ids) and lesson.id not in done_ids:
            return lesson
    return None


# (Opcional) helper si usas Language FK en tu User
def next_lesson_for_user_from_user_prefs(user, level: str) -> Optional[Lesson]:
    """
    Igual que next_lesson_for_user pero tomando los códigos desde atributos del usuario,
    si existen; cae a 'es'→'en' por defecto.
    """
    n = getattr(getattr(user, 'native_language', None), 'code', None) or getattr(user, 'native_language', None) or 'es'
    t = getattr(getattr(user, 'target_language', None), 'code', None) or getattr(user, 'target_language', None) or 'en'
    return next_lesson_for_user(user, level, n, t)
