from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from django.db.models import Sum, Count
from users.models import UserProgress, LearningStats
from leccion.models import UserLessonProgress

User = get_user_model()


class Command(BaseCommand):
    help = 'Recalcula las estadísticas de todos los usuarios basándose en datos reales'

    def handle(self, *args, **options):
        users = User.objects.all()
        total_users = users.count()
        
        self.stdout.write(f'Recalculando estadísticas para {total_users} usuarios...\n')
        
        for idx, user in enumerate(users, 1):
            # Calcular lecciones completadas desde UserLessonProgress
            lessons_completed = UserLessonProgress.objects.filter(
                user=user,
                completed=True
            ).count()
            
            # Calcular ejercicios completados desde UserProgress histórico
            exercises_completed = UserProgress.objects.filter(
                user=user
            ).aggregate(total=Sum('exercises_completed'))['total'] or 0
            
            # Calcular puntos totales desde UserProgress
            total_points = UserProgress.objects.filter(
                user=user
            ).aggregate(total=Sum('points_earned'))['total'] or 0
            
            # Actualizar solo si los valores calculados son mayores
            updated = False
            
            if lessons_completed > user.total_lessons_completed:
                user.total_lessons_completed = lessons_completed
                updated = True
                
            if exercises_completed > user.total_exercises_completed:
                user.total_exercises_completed = exercises_completed
                updated = True
                
            if total_points > user.points:
                user.points = total_points
                updated = True
            
            if updated:
                user.save()
                self.stdout.write(
                    self.style.SUCCESS(
                        f'[{idx}/{total_users}] ✓ {user.username}: '
                        f'{lessons_completed} lecciones, '
                        f'{exercises_completed} ejercicios, '
                        f'{total_points} puntos'
                    )
                )
            else:
                self.stdout.write(
                    f'[{idx}/{total_users}] - {user.username}: sin cambios'
                )
            
            # Asegurar que existe LearningStats
            LearningStats.objects.get_or_create(user=user)
        
        self.stdout.write(
            self.style.SUCCESS(
                f'\n✓ Recálculo completado para {total_users} usuarios'
            )
        )
