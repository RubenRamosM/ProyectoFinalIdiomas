# leccion/serializers.py
from rest_framework import serializers
from .models import (
    Lesson, LessonLocalization,
    Exercise, ExerciseLocalization, ExerciseOption,
    UserLessonProgress
)

# ---------------------------
# Helpers
# ---------------------------
def _get_lang_codes_from_context(serializer):
    """
    Obtiene native/target desde:
      1) serializer.context['native'], serializer.context['target']
      2) request.query_params (?native=es&target=en)
      3) defaults: native='es', target='en'
    """
    native = serializer.context.get('native')
    target = serializer.context.get('target')

    request = serializer.context.get('request')
    if request:
        native = native or request.query_params.get('native')
        target = target or request.query_params.get('target')

    return (native or 'es', target or 'en')


# ---------------------------
# Exercise options
# ---------------------------
class ExerciseOptionSerializer(serializers.ModelSerializer):
    class Meta:
        model = ExerciseOption
        fields = ['id', 'text', 'is_correct', 'feedback']

    def to_representation(self, instance):
        data = super().to_representation(instance)
        # Ocultar is_correct para usuarios no staff
        request = self.context.get('request')
        if not (request and getattr(request, 'user', None) and request.user.is_staff):
            data.pop('is_correct', None)
        return data


# ---------------------------
# Exercise localization (texto visible)
# ---------------------------
class ExerciseLocalizationSerializer(serializers.ModelSerializer):
    # `source='options'` is redundant because the field name equals the related_name.
    options = ExerciseOptionSerializer(many=True, read_only=True)

    class Meta:
        model = ExerciseLocalization
        fields = [
            'id', 'native_language', 'target_language',
            'question', 'instructions',
            'audio_url', 'expected_audio_text',
            'matching_pairs', 'correct_order',
            'assets', 'options'
        ]


# ---------------------------
# Exercise (molde) + localización elegida
# ---------------------------
class ExerciseSerializer(serializers.ModelSerializer):
    localization = serializers.SerializerMethodField()

    class Meta:
        model = Exercise
        fields = ['id', 'exercise_type', 'sequence', 'localization']

    def get_localization(self, obj):
        native_code, target_code = _get_lang_codes_from_context(self)

        # Si el view hizo prefetch: obj.localizations.all() ya está en memoria
        loc = next(
            (l for l in obj.localizations.all()
             if l.native_language.code == native_code and l.target_language.code == target_code),
            None
        )
        if not loc:
            return None
        # Pasamos el mismo context para heredar request y ocultar is_correct
        return ExerciseLocalizationSerializer(loc, context=self.context).data


# ---------------------------
# Lesson localization (contenido/título visible)
# ---------------------------
class LessonLocalizationSerializer(serializers.ModelSerializer):
    class Meta:
        model = LessonLocalization
        fields = ['id', 'native_language', 'target_language', 'title', 'content', 'hero_image', 'resources']


# ---------------------------
# Lesson (molde) + localización elegida + ejercicios localizados
# ---------------------------
class LessonSerializer(serializers.ModelSerializer):
    localization = serializers.SerializerMethodField()
    exercises = serializers.SerializerMethodField()

    class Meta:
        model = Lesson
        fields = [
            'id', 'title_key', 'level', 'lesson_type',
            'sequence', 'difficulty', 'priority',
            'is_active', 'created_at',
            'localization', 'exercises'
        ]

    def get_localization(self, obj):
        native_code, target_code = _get_lang_codes_from_context(self)
        loc = next(
            (l for l in obj.localizations.all()
             if l.native_language.code == native_code and l.target_language.code == target_code),
            None
        )
        if not loc:
            return None
        return LessonLocalizationSerializer(loc, context=self.context).data

    def get_exercises(self, obj):
        # Serializa cada Exercise incluyendo SOLO la localización del par native→target
        # Se asume prefetch de: exercises__localizations__options en la vista
        ex_list = []
        for ex in obj.exercises.all():
            ex_list.append(ExerciseSerializer(ex, context=self.context).data)
        return ex_list


# ---------------------------
# Progress
# ---------------------------
class UserLessonProgressSerializer(serializers.ModelSerializer):
    lesson = LessonSerializer(read_only=True)
    success_rate = serializers.ReadOnlyField()
    is_passed = serializers.ReadOnlyField()

    class Meta:
        model = UserLessonProgress
        fields = [
            'id', 'lesson',
            'native_language', 'target_language',
            'completed', 'score', 'completed_at',
            'total_exercises', 'correct_exercises', 'incorrect_exercises',
            'started_at', 'last_attempt_at',
            'success_rate', 'is_passed'
        ]
