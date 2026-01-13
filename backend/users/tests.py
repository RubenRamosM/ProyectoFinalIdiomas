from rest_framework.test import APITestCase
from rest_framework import status
from django.urls import reverse
from django.contrib.auth import get_user_model

User = get_user_model()

class UserRegistrationTest(APITestCase):
    def test_register_user_success(self):
        """
        Ensure we can create a new user.
        """
        url = reverse('users-register')
        data = {
            "username": "newuser",
            "email": "newuser@example.com",
            "password": "Str0ngP@ssw0rd!",
            "password2": "Str0ngP@ssw0rd!",
            "first_name": "New",
            "last_name": "User",
            "native_language": "es",
            "target_language": "en"
        }
        response = self.client.post(url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(User.objects.count(), 1)
        self.assertEqual(User.objects.get().username, 'newuser')
        self.assertIn('email', response.data)
        self.assertNotIn('password', response.data)

    def test_register_user_password_mismatch(self):
        """
        Ensure user registration fails when passwords do not match.
        """
        url = reverse('users-register')
        data = {
            "username": "newuser2",
            "email": "newuser2@example.com",
            "password": "Str0ngP@ssw0rd!",
            "password2": "password456",
        }
        response = self.client.post(url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('password2', response.data)

    def test_register_user_existing_email(self):
        """
        Ensure user registration fails when using an existing email.
        """
        User.objects.create_user(username='testuser', email='test@example.com', password='Str0ngP@ssw0rd!')
        url = reverse('users-register')
        data = {
            "username": "newuser3",
            "email": "test@example.com",
            "password": "Str0ngP@ssw0rd!",
            "password2": "Str0ngP@ssw0rd!",
        }
        response = self.client.post(url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('email', response.data)


class MeViewTest(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser',
            email='test@test.com',
            password='Str0ngP@ssw0rd!',
            first_name='Test',
            last_name='User',
            native_language='en',
            target_language='es',
            age=30
        )
        self.url = reverse('users-me')

    def test_get_me_unauthenticated(self):
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_get_me_authenticated(self):
        self.client.force_authenticate(user=self.user)
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['email'], self.user.email)
        self.assertEqual(response.data['first_name'], 'Test')

    def test_put_me_authenticated(self):
        self.client.force_authenticate(user=self.user)
        data = {
            "first_name": "Updated First",
            "last_name": "Updated Last",
            "native_language": "fr",
            "target_language": "de",
            "age": 40
        }
        response = self.client.put(self.url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.user.refresh_from_db()
        self.assertEqual(self.user.first_name, "Updated First")
        self.assertEqual(self.user.age, 40)

    def test_patch_me_authenticated(self):
        self.client.force_authenticate(user=self.user)
        data = {"age": 35}
        response = self.client.patch(self.url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.user.refresh_from_db()
        self.assertEqual(self.user.age, 35)
        self.assertEqual(self.user.first_name, "Test") # Should not change)


class UserStatsViewTest(APITestCase):
    def setUp(self):
        """Configura el entorno de prueba."""
        self.user = User.objects.create_user(
            username='testuser', 
            password='Str0ngP@ssw0rd!',
            level='A1'
        )
        from .models import LearningStats
        LearningStats.objects.create(user=self.user)
        self.client.force_authenticate(user=self.user)
        self.url = reverse('users-stats')

    def test_get_user_stats_authenticated(self):
        """Asegura que los usuarios autenticados pueden obtener sus estadísticas."""
        response = self.client.get(self.url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('points', response.data)
        self.assertIn('streak_count', response.data)
        self.assertIn('total_lessons_completed', response.data)

    def test_get_user_stats_unauthenticated(self):
        """Asegura que los usuarios no autenticados no pueden acceder a las estadísticas."""
        self.client.force_authenticate(user=None)
        response = self.client.get(self.url)
        
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)


class UserProgressViewTest(APITestCase):
    def setUp(self):
        """Configura el entorno de prueba."""
        self.user = User.objects.create_user(
            username='testuser', 
            password='Str0ngP@ssw0rd!',
            level='A1'
        )
        self.client.force_authenticate(user=self.user)
        self.url = reverse('users-progress')

    def test_get_user_progress_authenticated(self):
        """Asegura que los usuarios autenticados pueden obtener su historial de progreso."""
        from .models import UserProgress
        from django.utils import timezone
        # Crear un registro de progreso
        UserProgress.objects.create(
            user=self.user,
            date=timezone.now().date(),
            lessons_completed=2,
            exercises_completed=5,
            points_earned=50,
            time_spent=30
        )
        
        response = self.client.get(self.url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)

    def test_post_user_progress_authenticated(self):
        """Asegura que los usuarios autenticados pueden actualizar su progreso."""
        data = {
            'lessons_completed': 1,
            'exercises_completed': 3,
            'points_earned': 25,
            'time_spent': 20
        }
        
        response = self.client.post(self.url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['lessons_completed'], 1)
        self.assertEqual(response.data['exercises_completed'], 3)

    def test_get_user_progress_unauthenticated(self):
        """Asegura que los usuarios no autenticados no pueden acceder al historial de progreso."""
        self.client.force_authenticate(user=None)
        response = self.client.get(self.url)
        
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)


class LearningStatsViewTest(APITestCase):
    def setUp(self):
        """Configura el entorno de prueba."""
        from .models import LearningStats
        self.user = User.objects.create_user(
            username='testuser', 
            password='Str0ngP@ssw0rd!',
            level='A1'
        )
        self.client.force_authenticate(user=self.user)
        self.url = reverse('users-learning-stats')
        LearningStats.objects.create(
            user=self.user,
            vocabulary_learned=10,
            grammar_topics_completed=2
        )

    def test_get_learning_stats_authenticated(self):
        """Asegura que los usuarios autenticados pueden obtener sus estadísticas de aprendizaje."""
        response = self.client.get(self.url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('vocabulary_learned', response.data)
        self.assertIn('grammar_topics_completed', response.data)

    def test_get_learning_stats_unauthenticated(self):
        """Asegura que los usuarios no autenticados no pueden acceder a las estadísticas de aprendizaje."""
        self.client.force_authenticate(user=None)
        response = self.client.get(self.url)
        
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)