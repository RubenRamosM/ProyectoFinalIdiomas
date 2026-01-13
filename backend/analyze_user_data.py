import os
import sys
import django

# Configurar Django
sys.path.append('C:/UAGRM/SW1/PROYFINAL/backend')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'idiomasapp.settings')
django.setup()

from django.contrib.auth import get_user_model
from users.models import UserProgress
from leccion.models import UserLessonProgress

User = get_user_model()

# Analizar datos de todos los usuarios
users = User.objects.all()

print("=== ANÁLISIS DE DATOS DE USUARIOS ===\n")

for user in users:
    print(f"Usuario: {user.username}")
    print(f"  Campos directos en User:")
    print(f"    - total_lessons_completed: {user.total_lessons_completed}")
    print(f"    - total_exercises_completed: {user.total_exercises_completed}")
    print(f"    - points: {user.points}")
    print(f"    - streak_count: {user.streak_count}")
    
    # Datos de UserLessonProgress
    lessons_completed = UserLessonProgress.objects.filter(user=user, completed=True).count()
    lessons_in_progress = UserLessonProgress.objects.filter(user=user, completed=False).count()
    print(f"\n  Datos de UserLessonProgress:")
    print(f"    - Lecciones completadas: {lessons_completed}")
    print(f"    - Lecciones en progreso: {lessons_in_progress}")
    
    # Datos de UserProgress (histórico diario)
    progress_records = UserProgress.objects.filter(user=user).order_by('-date')
    total_exercises = sum(p.exercises_completed for p in progress_records)
    total_points = sum(p.points_earned for p in progress_records)
    print(f"\n  Datos de UserProgress (histórico):")
    print(f"    - Registros: {progress_records.count()} días")
    print(f"    - Total ejercicios: {total_exercises}")
    print(f"    - Total puntos: {total_points}")
    
    print("\n" + "="*60 + "\n")
