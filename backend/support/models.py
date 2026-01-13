from django.db import models
from users.models import User


class FAQ(models.Model):
    """Modelo para Preguntas Frecuentes"""
    CATEGORY_CHOICES = [
        ('general', 'General'),
        ('account', 'Cuenta y Perfil'),
        ('lessons', 'Lecciones'),
        ('technical', 'Técnico'),
        ('payment', 'Pagos'),
    ]

    question = models.CharField(max_length=500, help_text="Pregunta frecuente")
    answer = models.TextField(help_text="Respuesta detallada")
    category = models.CharField(max_length=20, choices=CATEGORY_CHOICES, default='general')
    order = models.IntegerField(default=0, help_text="Orden de visualización")
    is_active = models.BooleanField(default=True, help_text="¿Mostrar esta FAQ?")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['category', 'order']
        verbose_name = 'FAQ'
        verbose_name_plural = 'FAQs'

    def __str__(self):
        return f"[{self.get_category_display()}] {self.question[:50]}"


class SupportTicket(models.Model):
    """Modelo para Tickets de Soporte"""
    STATUS_CHOICES = [
        ('open', 'Abierto'),
        ('in_progress', 'En Progreso'),
        ('resolved', 'Resuelto'),
        ('closed', 'Cerrado'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='support_tickets')
    subject = models.CharField(max_length=200, help_text="Asunto del ticket")
    message = models.TextField(help_text="Descripción del problema o consulta")
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='open')
    admin_response = models.TextField(blank=True, null=True, help_text="Respuesta del administrador")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Ticket de Soporte'
        verbose_name_plural = 'Tickets de Soporte'

    def __str__(self):
        return f"#{self.id} - {self.subject} ({self.get_status_display()})"
