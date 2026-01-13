# app: ia/models.py
from django.db import models
from django.conf import settings
from django.utils import timezone

User = settings.AUTH_USER_MODEL

class ExerciseEmbedding(models.Model):
    """
    Embedding del ejercicio para recuperación por similitud.
    Guarda el vector en binario (p.ej. float32 bytes) o JSON (lista).
    """
    exercise = models.OneToOneField('leccion.Exercise', on_delete=models.CASCADE, related_name='embedding')
    vector = models.BinaryField()  # o JSONField si prefieres
    dim = models.PositiveIntegerField(default=768)
    updated_at = models.DateTimeField(auto_now=True)

class ExerciseAttempt(models.Model):
    """
    Log de intentos para analítica y entrenamiento.
    """
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='exercise_attempts')
    exercise = models.ForeignKey('leccion.Exercise', on_delete=models.CASCADE, related_name='attempts')
    is_correct = models.BooleanField(default=False)
    score = models.FloatField(null=True, blank=True)  # p.ej. 0..100
    user_answer = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(default=timezone.now)

    # tags/skills asociados (normaliza si quieres)
    topic = models.CharField(max_length=64, blank=True, null=True)      # p.ej. greetings
    skill = models.CharField(max_length=32, blank=True, null=True)      # reading/listening/speaking/grammar

class UserWeakness(models.Model):
    """
    Estado agregado de debilidades por usuario y tópico/skill.
    Se actualiza al registrar intentos.
    """
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='weaknesses')
    topic = models.CharField(max_length=64)
    skill = models.CharField(max_length=32, blank=True, null=True)
    # métrica simple: ratio fallos/total y fuerza de recomendación
    attempts = models.PositiveIntegerField(default=0)
    errors = models.PositiveIntegerField(default=0)
    error_rate = models.FloatField(default=0.0)  # errors/attempts
    priority = models.FloatField(default=0.0)    # ponderada por recencia/SRS

    class Meta:
        unique_together = ('user', 'topic', 'skill')

class RecommendationQueue(models.Model):
    """
    Cola de recomendaciones personalizadas pendientes para el usuario.
    """
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='recommendations')
    exercise = models.ForeignKey('leccion.Exercise', on_delete=models.CASCADE)
    reason = models.CharField(max_length=128)  # p.ej. SIMILAR_TO_FAILED, SRS_DUE, TOPIC_WEAKNESS
    score = models.FloatField(default=0.0)     # ranking final
    created_at = models.DateTimeField(default=timezone.now)
    served = models.BooleanField(default=False)

class TranslatorSession(models.Model):
    """
    Sesión de traducción en tiempo real (metadatos).
    """
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='translator_sessions')
    source_lang = models.CharField(max_length=8, default='auto')  # 'auto' -> detección
    target_lang = models.CharField(max_length=8, default='en')
    created_at = models.DateTimeField(default=timezone.now)
    last_activity = models.DateTimeField(default=timezone.now)
    is_active = models.BooleanField(default=True)


class TutorConversation(models.Model):
    """
    Conversación con el tutor inteligente.
    """
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='tutor_conversations')
    title = models.CharField(max_length=200, default='Nueva conversación')
    target_language = models.CharField(max_length=50, default='inglés')  # idioma que estudia
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ['-updated_at']

    def __str__(self):
        return f"{self.user.username} - {self.title}"


class TutorMessage(models.Model):
    """
    Mensaje individual dentro de una conversación con el tutor.
    """
    ROLE_CHOICES = [
        ('user', 'Usuario'),
        ('assistant', 'Tutor'),
    ]
    
    conversation = models.ForeignKey(TutorConversation, on_delete=models.CASCADE, related_name='messages')
    role = models.CharField(max_length=10, choices=ROLE_CHOICES)
    content = models.TextField()
    audio_b64 = models.TextField(blank=True, null=True)  # Audio TTS en base64
    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        ordering = ['created_at']

    def __str__(self):
        return f"{self.conversation.id} - {self.role}: {self.content[:50]}"
