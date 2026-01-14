# lessons/models.py
from django.db import models
from django.conf import settings
from django.core.validators import MinValueValidator, MaxValueValidator

# Reutiliza tus choices existentes (A1, A2, B1, B2, C1, C2, etc.)
from users.models import LEVEL_CHOICES

# Importa el catálogo de idiomas normalizado (debes crearlo en core/models.py)
# class Language(models.Model): code='en', 'fr', ... ; name='English', 'Français', ...
from core.models import Language


class Lesson(models.Model):
    """
    Molde pedagógico independiente del idioma.
    La localización (título, contenido) vive en LessonLocalization.
    """
    LESSON_TYPES = [
        ('vocabulary', 'Vocabulario'),
        ('grammar', 'Gramática'),
        ('conversation', 'Conversación'),
        ('pronunciation', 'Pronunciación'),
        ('shadowing', 'Shadowing'),
    ]

    # Clave interna estable (slug/llave funcional) para identificar la lección
    title_key = models.CharField(
        max_length=200,
        help_text="Clave interna/slug estable. Ej: 'greetings_basics'"
    )

    level = models.CharField(max_length=2, choices=LEVEL_CHOICES)
    lesson_type = models.CharField(max_length=20, choices=LESSON_TYPES)

    # Metadatos para orden/adaptatividad
    created_at = models.DateTimeField(auto_now_add=True)
    is_active = models.BooleanField(default=True)
    sequence = models.PositiveIntegerField(
        default=10,
        help_text="Orden dentro del nivel. Usa saltos de 10 (10, 20, 30...)"
    )
    difficulty = models.PositiveSmallIntegerField(
        default=1,
        validators=[MinValueValidator(1), MaxValueValidator(5)],
        help_text="1 (muy fácil) … 5 (muy difícil)"
    )
    priority = models.IntegerField(
        default=0,
        help_text="Mayor prioridad puede subir la lección en orden adaptativo"
    )

    class Meta:
        ordering = ['level', 'sequence', 'difficulty', '-priority', 'created_at']
        unique_together = ('title_key', 'level', 'lesson_type')
        indexes = [
            models.Index(fields=['level', 'sequence']),
            models.Index(fields=['lesson_type']),
            models.Index(fields=['-priority', 'created_at']),
        ]

    def __str__(self):
        return f"{self.level} · {self.sequence} · {self.title_key}"


class LessonLocalization(models.Model):
    """
    Contenido localizado para un par de idiomas (nativo -> objetivo).
    Permite usar el mismo molde de Lesson para múltiples idiomas sin duplicar lógica.
    """
    lesson = models.ForeignKey(
        Lesson,
        related_name='localizations',
        on_delete=models.CASCADE
    )

    native_language = models.ForeignKey(
        Language,
        on_delete=models.CASCADE,
        related_name='native_lesson_localizations',
        help_text="Idioma del estudiante (UI/explicaciones). Ej: 'es'"
    )
    target_language = models.ForeignKey(
        Language,
        on_delete=models.CASCADE,
        related_name='target_lesson_localizations',
        help_text="Idioma objetivo que se aprende. Ej: 'en', 'fr', 'de'"
    )

    # Contenido visible (ya no vive en Lesson base)
    title = models.CharField(max_length=200)
    content = models.TextField(help_text="HTML/Markdown con el contenido pedagógico")

    # Opcional: assets comunes por localización
    hero_image = models.URLField(blank=True, null=True)
    resources = models.JSONField(
        blank=True, null=True,
        help_text="Enlaces/recursos auxiliares (JSON)"
    )

    class Meta:
        unique_together = ('lesson', 'native_language', 'target_language')
        indexes = [
            models.Index(fields=['native_language', 'target_language']),
        ]

    def __str__(self):
        return f"{self.lesson.title_key} [{self.native_language.code}→{self.target_language.code}]"


class Exercise(models.Model):
    """
    Ejercicio como molde (tipo, pertenencia a Lesson).
    Los textos/pistas/opciones viven en ExerciseLocalization.
    """
    EXERCISE_TYPES = [
        ('multiple_choice', 'Opción múltiple'),
        ('translation', 'Traducción'),
        ('pronunciation', 'Pronunciación'),
        ('shadowing', 'Shadowing'),
        ('fill_blank', 'Completar espacios'),
        ('audio_listening', 'Escucha de audio'),
        ('matching', 'Emparejar'),
        ('drag_drop', 'Arrastrar y soltar'),
        ('speaking', 'Hablar'),
        ('true_false', 'Verdadero/Falso'),
        ('ordering', 'Ordenar'),
        ('word_formation', 'Formación de palabras'),
    ]

    lesson = models.ForeignKey(
        Lesson,
        related_name='exercises',
        on_delete=models.CASCADE
    )
    exercise_type = models.CharField(max_length=20, choices=EXERCISE_TYPES)

    # Opcional: clave/instrucción genérica sin idioma
    instructions_key = models.CharField(
        max_length=200, blank=True,
        help_text="Clave interna opcional, útil para i18n"
    )

    # Orden relativo dentro de la lección
    sequence = models.PositiveIntegerField(
        default=10,
        help_text="Orden dentro de la lección. Usa saltos de 10"
    )

    class Meta:
        ordering = ['lesson', 'sequence', 'id']
        indexes = [
            models.Index(fields=['lesson', 'sequence']),
            models.Index(fields=['exercise_type']),
        ]

    def __str__(self):
        return f"{self.exercise_type} · L{self.lesson_id} · #{self.sequence}"


class ExerciseLocalization(models.Model):
    """
    Localización del ejercicio para el par de idiomas.
    Aquí viven los textos, enunciados, pistas y estructuras específicas.
    """
    exercise = models.ForeignKey(
        Exercise,
        related_name='localizations',
        on_delete=models.CASCADE
    )
    native_language = models.ForeignKey(
        Language,
        on_delete=models.CASCADE,
        related_name='native_exercise_localizations'
    )
    target_language = models.ForeignKey(
        Language,
        on_delete=models.CASCADE,
        related_name='target_exercise_localizations'
    )

    # Enunciado e instrucciones visibles
    question = models.TextField()
    instructions = models.TextField(blank=True, null=True)

    # Campos adicionales para tipos especiales
    audio_url = models.URLField(blank=True, null=True, help_text="URL de audio si aplica")
    expected_audio_text = models.TextField(blank=True, null=True, help_text="Texto esperado en ejercicios de audio")
    matching_pairs = models.JSONField(blank=True, null=True, help_text="Lista de pares (JSON)")
    correct_order = models.JSONField(blank=True, null=True, help_text="Orden correcto (JSON)")

    # Adjuntos/recursos opcionales
    assets = models.JSONField(blank=True, null=True, help_text="Archivos/recursos auxiliares (JSON)")

    class Meta:
        unique_together = ('exercise', 'native_language', 'target_language')
        indexes = [
            models.Index(fields=['native_language', 'target_language']),
        ]

    def __str__(self):
        return f"Ex{self.exercise_id} [{self.native_language.code}→{self.target_language.code}]"


class ExerciseOption(models.Model):
    """
    Opciones (respuestas) asociadas a una ExerciseLocalization (no al molde),
    para que cada par de idiomas tenga sus propias alternativas.
    """
    exercise_localization = models.ForeignKey(
        ExerciseLocalization,
        related_name='options',
        on_delete=models.CASCADE,
        null=True,
        blank=True
    )
    text = models.CharField(max_length=255)
    is_correct = models.BooleanField(default=False)

    # Opcional: feedback específico por opción
    feedback = models.CharField(max_length=255, blank=True)

    class Meta:
        indexes = [
            models.Index(fields=['exercise_localization']),
            models.Index(fields=['is_correct']),
        ]

    def __str__(self):
        return f"{self.text} ({'correcta' if self.is_correct else 'incorrecta'})"


class UserLessonProgress(models.Model):
    """
    Progreso del usuario por lección (molde), registrando además el par de idiomas
    con el que cursó (útil si una misma Lesson se toma en diferentes pares).
    """
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    lesson = models.ForeignKey(Lesson, on_delete=models.CASCADE)

    native_language = models.ForeignKey(
        Language, on_delete=models.SET_NULL, null=True, blank=True, related_name='progress_native'
    )
    target_language = models.ForeignKey(
        Language, on_delete=models.SET_NULL, null=True, blank=True, related_name='progress_target'
    )

    completed = models.BooleanField(default=False)
    score = models.FloatField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)

    # Estadísticas detalladas
    total_exercises = models.PositiveIntegerField(default=0)
    correct_exercises = models.PositiveIntegerField(default=0)
    incorrect_exercises = models.PositiveIntegerField(default=0)
    started_at = models.DateTimeField(null=True, blank=True)
    last_attempt_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        unique_together = ('user', 'lesson', 'native_language', 'target_language')
        indexes = [
            models.Index(fields=['user', 'lesson']),
            models.Index(fields=['native_language', 'target_language']),
            models.Index(fields=['completed']),
        ]

    def __str__(self):
        pair = ""
        if self.native_language_id and self.target_language_id:
            pair = f" [{self.native_language.code}→{self.target_language.code}]"
        return f"{self.user} - {self.lesson.title_key}{pair}"

    @property
    def success_rate(self) -> float:
        if self.total_exercises == 0:
            return 0.0
        return (self.correct_exercises / max(1, self.total_exercises)) * 100

    @property
    def is_passed(self) -> bool:
        # Mantén tu regla (por ejemplo: 11+ correctos)
        return self.correct_exercises >= 11
