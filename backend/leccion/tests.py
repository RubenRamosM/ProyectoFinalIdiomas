from rest_framework.test import APITestCase
from rest_framework import status
from django.urls import reverse
from django.contrib.auth import get_user_model
from django.core.management import call_command
from .models import Choice, Lesson, VocabularyItem, Exercise, UserLessonProgress
from django.core.files.uploadedfile import SimpleUploadedFile

User = get_user_model()

class PlacementTestViewTest(APITestCase):
    def setUp(self):
        """Set up the test environment."""
        # Create a user for authentication
        self.user = User.objects.create_user(username='testuser', password='Str0ngP@ssw0rd!')
        
        # Seed the database with questions to ensure data is available for tests
        call_command('seed_questions')

    def test_get_placement_test_unauthenticated(self):
        """Ensure unauthenticated users cannot access the test."""
        self.client.force_authenticate(user=None)
        url = reverse('placement-test')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_get_placement_test_authenticated(self):
        """Ensure authenticated users can get the list of questions."""
        self.client.force_authenticate(user=self.user)
        url = reverse('placement-test')
        response = self.client.get(url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        # The view fetches 2 questions per level, and there are 5 levels
        self.assertEqual(len(response.data), 10)
        
        # Check structure of the first question
        first_question = response.data[0]
        self.assertIn('id', first_question)
        self.assertIn('text', first_question)
        self.assertIn('level', first_question)
        self.assertIn('choices', first_question)
        self.assertIsInstance(first_question['choices'], list)
        self.assertIn('id', first_question['choices'][0])
        self.assertIn('text', first_question['choices'][0])

    def test_submit_answers_and_update_level(self):
        """Ensure submitting answers calculates and updates the user's level."""
        self.client.force_authenticate(user=self.user)
        
        # Let's get 5 correct choices: 2 from A1, 2 from A2, 1 from B1
        # This should result in a B1 level (5 correct // 2 = index 2 -> B1)
        correct_choices = Choice.objects.filter(is_correct=True).order_by('question__level')[:5]
        choice_ids = [choice.id for choice in correct_choices]
        
        url = reverse('placement-test')
        data = {'choices': choice_ids}
        response = self.client.post(url, data, format='json')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['correct_answers'], 5)
        self.assertEqual(response.data['new_level'], 'B1')

        # Verify the user's level was updated in the database
        self.user.refresh_from_db()
        self.assertEqual(self.user.level, 'B1')

    def test_submit_invalid_data_format(self):
        """Ensure submitting invalid data (not a list) returns a 400 error."""
        self.client.force_authenticate(user=self.user)
        url = reverse('placement-test')
        data = {'choices': 'this-is-not-a-list'}
        response = self.client.post(url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

class PronunciationFeedbackViewTest(APITestCase):
    def setUp(self):
        """Configura el entorno de prueba."""
        self.user = User.objects.create_user(username='testuser', password='Str0ngP@ssw0rd!')
        self.client.force_authenticate(user=self.user)
        self.url = reverse('pronunciation-feedback')

    def test_upload_audio_for_feedback_success(self):
        """Asegura que se puede subir un audio y recibir una respuesta simulada."""
        # Crear un archivo de audio simulado en memoria
        audio_content = b'simulated audio content'
        audio_file = SimpleUploadedFile("pronunciation.wav", audio_content, content_type="audio/wav")

        response = self.client.post(self.url, {'file': audio_file})

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('score', response.data)
        self.assertIn('feedback', response.data)
        self.assertIn('transcription', response.data)
        self.assertEqual(response.data['score'], 85)

    def test_upload_audio_no_file_provided(self):
        """Asegura que se devuelve un error 400 si no se proporciona ningún archivo."""
        response = self.client.post(self.url, {})

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('error', response.data)
        self.assertEqual(response.data['error'], 'No se proporcionó ningún archivo')


class AdaptiveLessonViewTest(APITestCase):
    def setUp(self):
        """Configura el entorno de prueba."""
        self.user = User.objects.create_user(username='testuser', password='Str0ngP@ssw0rd!', level='A1')
        self.client.force_authenticate(user=self.user)
        self.url = reverse('adaptive-lesson')
        
        # Crear una lección de ejemplo
        self.lesson = Lesson.objects.create(
            title='Saludos básicos',
            content='Aprende a saludar y presentarte en el idioma objetivo.',
            level='A1',
            lesson_type='vocabulary',
            target_language='en',
            native_language='es'
        )

    def test_get_adaptive_lesson_authenticated(self):
        """Asegura que los usuarios autenticados pueden obtener una lección adaptativa."""
        response = self.client.get(self.url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('title', response.data)
        self.assertIn('content', response.data)
        self.assertEqual(response.data['level'], 'A1')

    def test_get_adaptive_lesson_unauthenticated(self):
        """Asegura que los usuarios no autenticados no pueden acceder a la lección."""
        self.client.force_authenticate(user=None)
        response = self.client.get(self.url)
        
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)


class VocabularyListViewTest(APITestCase):
    def setUp(self):
        """Configura el entorno de prueba."""
        self.user = User.objects.create_user(username='testuser', password='Str0ngP@ssw0rd!', level='A1')
        self.client.force_authenticate(user=self.user)
        self.url = reverse('vocabulary')
        
        # Crear vocabulario de ejemplo
        self.vocab_item = VocabularyItem.objects.create(
            word='hello',
            translation='hola',
            level='A1',
            example_sentence='Hello, how are you?',
            pronunciation_guide='həˈləʊ'
        )

    def test_get_vocabulary_list_authenticated(self):
        """Asegura que los usuarios autenticados pueden obtener la lista de vocabulario."""
        response = self.client.get(self.url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['word'], 'hello')

    def test_get_vocabulary_list_unauthenticated(self):
        """Asegura que los usuarios no autenticados no pueden acceder a la lista de vocabulario."""
        self.client.force_authenticate(user=None)
        response = self.client.get(self.url)
        
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)


class LessonProgressViewTest(APITestCase):
    def setUp(self):
        """Configura el entorno de prueba."""
        self.user = User.objects.create_user(username='testuser', password='Str0ngP@ssw0rd!', level='A1')
        self.client.force_authenticate(user=self.user)
        self.url = reverse('lesson-progress')
        
        # Crear una lección de ejemplo
        self.lesson = Lesson.objects.create(
            title='Saludos básicos',
            content='Aprende a saludar y presentarte en el idioma objetivo.',
            level='A1',
            lesson_type='vocabulary',
            target_language='en',
            native_language='es'
        )

    def test_post_lesson_progress_authenticated(self):
        """Asegura que los usuarios autenticados pueden registrar progreso en una lección."""
        data = {
            'lesson_id': self.lesson.id,
            'completed': True,
            'score': 85.0
        }
        response = self.client.post(self.url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['progress']['lesson_id'], self.lesson.id)
        self.assertEqual(response.data['progress']['completed'], True)
        self.assertEqual(response.data['progress']['score'], 85.0)

    def test_get_lesson_progress_authenticated(self):
        """Asegura que los usuarios autenticados pueden obtener su progreso en lecciones."""
        # Registrar progreso primero
        UserLessonProgress.objects.create(
            user=self.user,
            lesson=self.lesson,
            completed=True,
            score=85.0
        )
        
        response = self.client.get(self.url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['lesson']['title'], 'Saludos básicos')


class ShadowingExerciseViewTest(APITestCase):
    def setUp(self):
        """Configura el entorno de prueba."""
        self.user = User.objects.create_user(username='testuser', password='Str0ngP@ssw0rd!', level='A1')
        self.client.force_authenticate(user=self.user)
        self.url = reverse('shadowing-exercise')
        
        # Crear una lección y un ejercicio de shadowing de ejemplo
        self.lesson = Lesson.objects.create(
            title='Saludos básicos',
            content='Aprende a saludar y presentarte en el idioma objetivo.',
            level='A1',
            lesson_type='vocabulary',
            target_language='en',
            native_language='es'
        )
        
        self.exercise = Exercise.objects.create(
            lesson=self.lesson,
            question='Repite la frase: Hello, how are you?',
            exercise_type='shadowing',
            target_language='en',
            native_language='es'
        )

    def test_get_shadowing_exercise_authenticated(self):
        """Asegura que los usuarios autenticados pueden obtener un ejercicio de shadowing."""
        response = self.client.get(self.url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('lesson', response.data)
        self.assertIn('exercise', response.data)
        self.assertEqual(response.data['exercise']['question'], 'Repite la frase: Hello, how are you?')

    def test_get_shadowing_exercise_unauthenticated(self):
        """Asegura que los usuarios no autenticados no pueden acceder al ejercicio de shadowing."""
        self.client.force_authenticate(user=None)
        response = self.client.get(self.url)
        
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)


class SpacedRepetitionViewTest(APITestCase):
    def setUp(self):
        """Configura el entorno de prueba."""
        self.user = User.objects.create_user(username='testuser', password='Str0ngP@ssw0rd!', level='A1')
        self.client.force_authenticate(user=self.user)
        self.url = reverse('spaced-repetition')
        
        # Crear vocabulario de ejemplo
        self.vocab_item = VocabularyItem.objects.create(
            word='hello',
            translation='hola',
            level='A1',
            example_sentence='Hello, how are you?',
            pronunciation_guide='həˈləʊ'
        )

    def test_get_spaced_repetition_vocabulary_authenticated(self):
        """Asegura que los usuarios autenticados pueden obtener vocabulario para repetición espaciada."""
        response = self.client.get(self.url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['word'], 'hello')

    def test_post_spaced_repetition_update(self):
        """Asegura que los usuarios pueden actualizar el estado de repetición espaciada."""
        data = {
            'vocab_id': self.vocab_item.id,
            'quality': 4  # Calidad buena
        }
        response = self.client.post(self.url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('next_review', response.data)
        self.assertIn('interval', response.data)

    def test_get_spaced_repetition_vocabulary_unauthenticated(self):
        """Asegura que los usuarios no autenticados no pueden acceder al vocabulario de repetición espaciada."""
        self.client.force_authenticate(user=None)
        response = self.client.get(self.url)
        
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)