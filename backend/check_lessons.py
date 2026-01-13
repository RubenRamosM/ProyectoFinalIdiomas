import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'idiomasapp.settings')
django.setup()

from leccion.models import Lesson

lessons = Lesson.objects.all().order_by('level', 'sequence')

print("=" * 70)
print("RESUMEN DE LECCIONES CREADAS")
print("=" * 70)

for level in ['A1', 'A2', 'B1', 'B2', 'C1', 'C2']:
    level_lessons = lessons.filter(level=level)
    print(f"\n{level} ({level_lessons.count()} lecciones):")
    for i, l in enumerate(level_lessons):
        print(f"  {i+1}. {l.title_key}")
        print(f"     Secuencia: {l.sequence}, Dificultad: {l.difficulty}, Tipo: {l.lesson_type}")
        from leccion.models import Exercise
        ex_count = Exercise.objects.filter(lesson=l).count()
        print(f"     Ejercicios: {ex_count}")

print("\n" + "=" * 70)
print(f"TOTAL: {lessons.count()} lecciones")
print("=" * 70)

