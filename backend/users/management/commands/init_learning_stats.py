from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from users.models import LearningStats

User = get_user_model()

class Command(BaseCommand):
    help = 'Inicializa LearningStats para usuarios existentes'

    def handle(self, *args, **options):
        users_without_stats = User.objects.filter(learning_stats__isnull=True)
        
        created_count = 0
        for user in users_without_stats:
            LearningStats.objects.create(user=user)
            created_count += 1
        
        self.stdout.write(
            self.style.SUCCESS(
                f'¡Se crearon {created_count} registros de LearningStats!'
            )
        )