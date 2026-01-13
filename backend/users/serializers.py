from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers
from .models import LEVEL_CHOICES, UserProgress, LearningStats

User = get_user_model()

class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)
    password2 = serializers.CharField(write_only=True)
    age = serializers.IntegerField(required=False, allow_null=True)
    level = serializers.ChoiceField(choices=LEVEL_CHOICES, required=False, allow_null=True)
    nationality = serializers.CharField(required=False, allow_null=True, allow_blank=True)

    class Meta:
        model = User
        fields = (
            "username", "first_name", "last_name", "email",
            "password", "password2",
            "native_language", "target_language",
            "nationality",
            "age", "level",
        )

    def validate_email(self, value):
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError("Este email ya está registrado.")
        return value

    def validate_age(self, value):
        if value is None:
            return value
        if value < 5 or value > 120:
            raise serializers.ValidationError("Edad inválida.")
        return value

    def validate(self, data):
        if data["password"] != data["password2"]:
            raise serializers.ValidationError({"password2": "Las contraseñas no coinciden."})
        validate_password(data["password"])
        return data

    def create(self, validated_data):
        validated_data.pop("password2")
        raw_password = validated_data.pop("password")
        user = User(**validated_data)
        user.set_password(raw_password)
        user.save()
        return user


class UserUpdateSerializer(serializers.ModelSerializer):
    age = serializers.IntegerField(required=False, allow_null=True)
    nationality = serializers.CharField(required=False, allow_null=True, allow_blank=True)

    class Meta:
        model = User
        fields = (
            "first_name", "last_name",
            "native_language", "target_language",
            "nationality",
            "age",
        )

    def validate_age(self, value):
        if value is None:
            return value
        if value < 5 or value > 120:
            raise serializers.ValidationError("Edad inválida.")
        return value


class UserProgressSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserProgress
        fields = '__all__'

class LearningStatsSerializer(serializers.ModelSerializer):
    class Meta:
        model = LearningStats
        fields = '__all__'

class UserPublicSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = (
            "id", "username", "first_name", "last_name", "email",
            "native_language", "target_language", "nationality", "age", "level"
        )

class UserStatsSerializer(serializers.ModelSerializer):
    """Serializer para devolver estadísticas completas del usuario"""
    learning_stats = LearningStatsSerializer(read_only=True)
    total_lessons_completed = serializers.SerializerMethodField()
    total_exercises_completed = serializers.SerializerMethodField()
    
    class Meta:
        model = User
        fields = (
            "id", "username", "first_name", "last_name", 
            "points", "streak_count", "longest_streak", 
            "total_lessons_completed", "total_exercises_completed",
            "level", "learning_stats"
        )
    
    def get_total_lessons_completed(self, obj):
        """Calcula lecciones totales desde el modelo User y UserProgress"""
        from leccion.models import UserLessonProgress
        # Contar lecciones completadas desde UserLessonProgress
        completed_from_lessons = UserLessonProgress.objects.filter(
            user=obj, 
            completed=True
        ).count()
        # Retornar el mayor entre el campo directo y el conteo real
        return max(obj.total_lessons_completed, completed_from_lessons)
    
    def get_total_exercises_completed(self, obj):
        """Calcula ejercicios totales desde UserProgress histórico"""
        # Sumar todos los ejercicios de UserProgress histórico
        from django.db.models import Sum
        total_from_progress = UserProgress.objects.filter(user=obj).aggregate(
            total=Sum('exercises_completed')
        )['total'] or 0
        # Retornar el mayor entre el campo directo y la suma histórica
        return max(obj.total_exercises_completed, total_from_progress)
