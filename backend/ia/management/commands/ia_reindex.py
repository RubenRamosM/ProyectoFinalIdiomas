# ia/management/commands/ia_reindex.py
from django.core.management.base import BaseCommand
from ia.services.ai_recommender import bulk_index_all

class Command(BaseCommand):
    help = "Reindexa todos los ejercicios con contexto de lección"

    def handle(self, *args, **options):
        n = bulk_index_all()
        self.stdout.write(self.style.SUCCESS(f"Embeddings generados: {n} ejercicios"))
