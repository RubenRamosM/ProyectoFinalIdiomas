from django.db import models

class Language(models.Model):
    """
    Catálogo de idiomas disponibles para las lecciones.
    Ejemplos: 'en' → Inglés, 'es' → Español, 'fr' → Francés, 'de' → Alemán, etc.
    """
    code = models.CharField(max_length=10, unique=True, help_text="Código ISO 639-1, ej: 'en', 'es', 'fr'")
    name = models.CharField(max_length=50)

    def __str__(self):
        return f"{self.name} ({self.code})"
