from rest_framework import generics, permissions, response, status
from django.contrib.auth import get_user_model
from .serializers import RegisterSerializer, UserPublicSerializer, UserUpdateSerializer, UserStatsSerializer, UserProgressSerializer, LearningStatsSerializer
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from .models import UserProgress, LearningStats
from leccion.models import UserLessonProgress
from django.db.models import Count, Sum
from django.utils import timezone
from datetime import timedelta, date


User = get_user_model()

class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = RegisterSerializer
    # Do not attempt authentication on the public registration endpoint
    authentication_classes = []
    permission_classes = [permissions.AllowAny]

    def create(self, request, *args, **kwargs):
        ser = self.get_serializer(data=request.data)
        ser.is_valid(raise_exception=True)
        user = ser.save()
        data = UserPublicSerializer(user).data
        headers = self.get_success_headers(data)
        return response.Response(data, status=status.HTTP_201_CREATED, headers=headers)

class MeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        serializer = UserPublicSerializer(request.user)
        return Response(serializer.data)

    def put(self, request):
        serializer = UserUpdateSerializer(request.user, data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(UserPublicSerializer(request.user).data)

    def patch(self, request):
        serializer = UserUpdateSerializer(request.user, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(UserPublicSerializer(request.user).data)


class UserStatsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """Devuelve las estadísticas completas del usuario."""
        user = request.user
        
        # Asegurarse de que exista LearningStats para el usuario
        learning_stats, created = LearningStats.objects.get_or_create(user=user)
        
        serializer = UserStatsSerializer(user)
        return Response(serializer.data)


class UserProgressView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """Devuelve el historial de progreso del usuario."""
        user = request.user
        days = request.query_params.get('days', 7)  # Por defecto, últimos 7 días
        
        try:
            days = int(days)
        except ValueError:
            days = 7
        
        start_date = timezone.now().date() - timedelta(days=days-1)
        progress_records = UserProgress.objects.filter(
            user=user,
            date__gte=start_date
        ).order_by('-date')
        
        serializer = UserProgressSerializer(progress_records, many=True)
        return Response(serializer.data)

    def post(self, request):
        """Actualiza o crea un registro de progreso para hoy."""
        user = request.user
        today = timezone.now().date()
        
        # Datos a actualizar
        lessons_completed = request.data.get('lessons_completed', 0)
        exercises_completed = request.data.get('exercises_completed', 0)
        points_earned = request.data.get('points_earned', 0)
        time_spent = request.data.get('time_spent', 0)
        
        # Obtener o crear el registro de hoy
        progress_record, created = UserProgress.objects.get_or_create(
            user=user,
            date=today,
            defaults={
                'lessons_completed': lessons_completed,
                'exercises_completed': exercises_completed,
                'points_earned': points_earned,
                'time_spent': time_spent
            }
        )
        
        if not created:
            # Actualizar el registro existente
            if lessons_completed > 0:
                progress_record.lessons_completed += lessons_completed
            if exercises_completed > 0:
                progress_record.exercises_completed += exercises_completed
            if points_earned > 0:
                progress_record.points_earned += points_earned
            if time_spent > 0:
                progress_record.time_spent += time_spent
            
            progress_record.save()
        
        # Actualizar estadísticas generales del usuario
        user.total_lessons_completed += lessons_completed
        user.total_exercises_completed += exercises_completed
        user.points += points_earned
        
        # Actualizar streak
        yesterday = today - timedelta(days=1)
        if user.last_lesson_date is None:
            # Primer día
            user.streak_count = 1
        elif (today - user.last_lesson_date.date()).days == 1:
            # Siguiente día consecutivo
            user.streak_count += 1
            if user.streak_count > user.longest_streak:
                user.longest_streak = user.streak_count
        elif (today - user.last_lesson_date.date()).days > 1:
            # Rompió la racha
            user.streak_count = 1
        
        user.last_lesson_date = timezone.now()
        user.save()
        
        serializer = UserProgressSerializer(progress_record)
        return Response(serializer.data)


class LearningStatsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """Devuelve las estadísticas de aprendizaje detalladas del usuario."""
        user = request.user
        
        # Asegurarse de que exista LearningStats para el usuario
        learning_stats, created = LearningStats.objects.get_or_create(user=user)
        
        serializer = LearningStatsSerializer(learning_stats)
        return Response(serializer.data)