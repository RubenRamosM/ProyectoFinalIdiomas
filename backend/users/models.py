from django.contrib.auth.models import AbstractUser
from django.db import models
from django.utils import timezone
from datetime import timedelta

LEVEL_CHOICES = [
    ("A1", "A1"),
    ("A2", "A2"),
    ("B1", "B1"),
    ("B2", "B2"),
    ("C1", "C1"),
    # ("C2", "C2"),
]

class User(AbstractUser):
    email = models.EmailField(unique=True)
    native_language = models.CharField("Idioma nativo", max_length=32, blank=True, null=True)
    target_language = models.CharField("Idioma objetivo", max_length=32, default="en")
    age = models.PositiveSmallIntegerField("Edad", blank=True, null=True)

    # NUEVO: nacionalidad
    nationality = models.CharField("Nacionalidad", max_length=64, blank=True, null=True)

    level = models.CharField("Nivel", max_length=2, choices=LEVEL_CHOICES, blank=True, null=True)
    
    # Campos para estadísticas y progreso
    points = models.PositiveIntegerField("Puntos acumulados", default=0)
    streak_count = models.PositiveIntegerField("Racha actual", default=0)
    longest_streak = models.PositiveIntegerField("Racha más larga", default=0)
    total_lessons_completed = models.PositiveIntegerField("Lecciones completadas", default=0)
    total_exercises_completed = models.PositiveIntegerField("Ejercicios completados", default=0)
    registration_date = models.DateTimeField("Fecha de registro", auto_now_add=True, null=True, blank=True)
    last_lesson_date = models.DateTimeField("Última lección", null=True, blank=True)

    def __str__(self):
        return self.username

    def save(self, *args, **kwargs):
        if not self.pk:
            self.registration_date = timezone.now()
        super().save(*args, **kwargs)


class UserProgress(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='progress_records')
    date = models.DateField("Fecha", default=timezone.now)
    lessons_completed = models.PositiveIntegerField("Lecciones completadas hoy", default=0)
    exercises_completed = models.PositiveIntegerField("Ejercicios completados hoy", default=0)
    points_earned = models.PositiveIntegerField("Puntos ganados hoy", default=0)
    time_spent = models.PositiveIntegerField("Tiempo de estudio (minutos)", default=0)

    class Meta:
        unique_together = ('user', 'date')
        ordering = ['-date']

    def __str__(self):
        return f"{self.user.username} - {self.date}"


class LearningStats(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='learning_stats')
    vocabulary_learned = models.PositiveIntegerField("Vocabulario aprendido", default=0)
    grammar_topics_completed = models.PositiveIntegerField("Temas de gramática completados", default=0)
    listening_time = models.PositiveIntegerField("Tiempo de escucha (minutos)", default=0)
    speaking_practice = models.PositiveIntegerField("Práctica de habla (minutos)", default=0)
    accuracy_rate = models.FloatField("Tasa de acierto promedio", default=0.0)
    updated_at = models.DateTimeField("Última actualización", auto_now=True)

    def __str__(self):
        return f"Estadísticas de {self.user.username}"
