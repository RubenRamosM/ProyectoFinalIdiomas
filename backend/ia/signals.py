# ia/signals.py
from django.db.models.signals import post_save
from django.dispatch import receiver
from leccion.models import Exercise
from ia.services.ai_recommender import index_exercise

@receiver(post_save, sender=Exercise)
def reindex_exercise_on_save(sender, instance: Exercise, **kwargs):
    try:
        index_exercise(instance)
    except Exception:
        pass
