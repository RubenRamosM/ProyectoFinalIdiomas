# leccion/migrations/0007_multi_language_refactor.py
from django.db import migrations, models
import django.core.validators
import django.db.models.deletion
from django.utils.text import slugify


def fill_title_key(apps, schema_editor):
    Lesson = apps.get_model('leccion', 'Lesson')
    for l in Lesson.objects.all():
        base = getattr(l, 'title', None) or f"lesson-{l.pk}"
        slug = slugify(str(base))[:200] or f"lesson-{l.pk}"
        candidate = slug
        n = 1
        while Lesson.objects.filter(title_key=candidate).exclude(id=l.id).exists():
            n += 1
            candidate = f"{slug}-{n}"[:200]
        l.title_key = candidate
        l.save(update_fields=['title_key'])


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0001_initial'),
        ('leccion', '0006_exercise_audio_url_exercise_correct_order_and_more'),
        migrations.swappable_dependency('users.User'),
    ]

    operations = [

        # 1) Añadir title_key primero
        migrations.AddField(
            model_name='lesson',
            name='title_key',
            field=models.CharField(
                max_length=200,
                default='TEMP-KEY',
                help_text="Clave interna/slug estable. Ej: 'greetings_basics'"
            ),
            preserve_default=False,
        ),

        # 2) Poblar title_key desde title existente
        migrations.RunPython(fill_title_key, migrations.RunPython.noop),

        # 3) Crear LessonLocalization
        migrations.CreateModel(
            name='LessonLocalization',
            fields=[
                ('id', models.BigAutoField(primary_key=True, serialize=False)),
                ('title', models.CharField(max_length=200)),
                ('content', models.TextField(help_text='HTML/Markdown con el contenido pedagógico')),
                ('hero_image', models.URLField(blank=True, null=True)),
                ('resources', models.JSONField(blank=True, null=True)),
                ('lesson', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='localizations', to='leccion.lesson')),
                ('native_language', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='native_lesson_localizations', to='core.language')),
                ('target_language', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='target_lesson_localizations', to='core.language')),
            ],
        ),

        # 4) Crear ExerciseLocalization
        migrations.CreateModel(
            name='ExerciseLocalization',
            fields=[
                ('id', models.BigAutoField(primary_key=True, serialize=False)),
                ('question', models.TextField()),
                ('instructions', models.TextField(blank=True, null=True)),
                ('audio_url', models.URLField(blank=True, null=True)),
                ('expected_audio_text', models.TextField(blank=True, null=True)),
                ('matching_pairs', models.JSONField(blank=True, null=True)),
                ('correct_order', models.JSONField(blank=True, null=True)),
                ('assets', models.JSONField(blank=True, null=True)),
                ('exercise', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='localizations', to='leccion.exercise')),
                ('native_language', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='native_exercise_localizations', to='core.language')),
                ('target_language', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='target_exercise_localizations', to='core.language')),
            ],
        ),

        # 5) Actualizar ExerciseOption para apuntar a localización
        migrations.AddField(
            model_name='exerciseoption',
            name='exercise_localization',
            field=models.ForeignKey(
                to='leccion.exerciselocalization',
                related_name='options',
                on_delete=django.db.models.deletion.CASCADE,
                null=True,
                blank=True,
            ),
        ),

        # 6) Quitar campos antiguos de Lesson
        migrations.RemoveField(model_name='lesson', name='title'),
        migrations.RemoveField(model_name='lesson', name='content'),
        migrations.RemoveField(model_name='lesson', name='target_language'),
        migrations.RemoveField(model_name='lesson', name='native_language'),

        # 7) Quitar campos antiguos de Exercise
        migrations.RemoveField(model_name='exercise', name='question'),
        migrations.RemoveField(model_name='exercise', name='instructions'),
        migrations.RemoveField(model_name='exercise', name='audio_url'),
        migrations.RemoveField(model_name='exercise', name='expected_audio_text'),
        migrations.RemoveField(model_name='exercise', name='matching_pairs'),
        migrations.RemoveField(model_name='exercise', name='correct_order'),
        migrations.RemoveField(model_name='exercise', name='native_language'),
        migrations.RemoveField(model_name='exercise', name='target_language'),

        # 8) Sync nuevos campos
        migrations.AddField(
            model_name='exercise',
            name='instructions_key',
            field=models.CharField(max_length=200, blank=True),
        ),

        migrations.AlterModelOptions(
            name='exercise',
            options={'ordering': ['lesson', 'sequence', 'id']},
        ),

        # 9) Reglas de unicidad (luego de crear title_key)
        migrations.AlterUniqueTogether(
            name='lesson',
            unique_together={('title_key', 'level', 'lesson_type')},
        ),
        migrations.AlterUniqueTogether(
            name='lessonlocalization',
            unique_together={('lesson', 'native_language', 'target_language')},
        ),
        migrations.AlterUniqueTogether(
            name='exerciselocalization',
            unique_together={('exercise', 'native_language', 'target_language')},
        ),
    ]
