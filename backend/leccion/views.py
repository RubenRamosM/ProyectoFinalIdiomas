# leccion/views.py
from django.db.models import Prefetch, Q
from django.utils import timezone

from rest_framework import generics, status
from rest_framework.generics import RetrieveAPIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.parsers import MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView

from difflib import SequenceMatcher
import string

# Whisper model cache (load a small model for speed). If whisper isn't installed
# or loading fails, WHISPER_MODEL will be None and we fallback to simulation.
WHISPER_MODEL = None
WHISPER_LOAD_ERROR = None
try:
    import whisper  # type: ignore
    try:
        # use tiny model for fast on-device inference; adjust if you prefer accuracy
        WHISPER_MODEL = whisper.load_model("tiny")
    except Exception as _e:
        WHISPER_MODEL = None
        WHISPER_LOAD_ERROR = str(_e)
except ImportError:
    whisper = None
    WHISPER_MODEL = None
    WHISPER_LOAD_ERROR = 'whisper not installed'
import datetime
import string

from core.models import Language
from .models import (
    Lesson, LessonLocalization,
    Exercise, ExerciseLocalization, ExerciseOption,
    UserLessonProgress
)
from .serializers import (
    LessonSerializer, ExerciseSerializer, UserLessonProgressSerializer
)
# si tienes un servicio para “siguiente lección”, puedes seguir usándolo;
# en este ejemplo resolveremos la lógica directo en las vistas.
# from .services import next_lesson_for_user


# ---------------------------------
# Helpers: par de idiomas preferido
# ---------------------------------
def get_lang_pair(request, default_native='es', default_target='en'):
    """
    Obtiene (native_code, target_code) con esta precedencia:
    1) query params (?native=es&target=fr)
    2) atributos del usuario (user.native_language.code / user.target_language.code) si existen
    3) defaults
    """
    native = request.query_params.get('native')
    target = request.query_params.get('target')

    user = getattr(request, 'user', None)
    # si tu User guarda FKs a Language, podrías hacer:
    # getattr(user, 'native_language', None) etc. Ajusta a tu modelo real.
    if not native:
        nl = getattr(user, 'native_language', None)
        if isinstance(nl, Language):
            native = nl.code
        else:
            native = getattr(user, 'native_language', None) or None
    if not target:
        tl = getattr(user, 'target_language', None)
        if isinstance(tl, Language):
            target = tl.code
        else:
            target = getattr(user, 'target_language', None) or None

    return (native or default_native, target or default_target)


# -----------------------------
# LECCIONES
# -----------------------------
class LessonDetailView(RetrieveAPIView):
    """
    Devuelve la lección solicitada con sus ejercicios localizados.
    Soporta (opcional) ?level=A1 para validar que la lección pertenezca a ese nivel.
    Usa ?native=es&target=en para elegir la localización.
    """
    permission_classes = [IsAuthenticated]
    serializer_class = LessonSerializer

    queryset = (Lesson.objects.all()
                .prefetch_related(
                    'localizations',
                    'exercises__localizations',
                    'exercises__localizations__options'
                ))

    def retrieve(self, request, *args, **kwargs):
        native_code, target_code = get_lang_pair(request)
        instance = self.get_object()

        # (Opcional) validar nivel desde query param
        requested_level = request.query_params.get('level')
        if requested_level and instance.level != requested_level:
            return Response(
                {'detail': 'La lección no pertenece al nivel solicitado.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Serializar pasando request + par de idiomas en el contexto
        data = LessonSerializer(
            instance,
            context={'request': request, 'native': native_code, 'target': target_code}
        ).data
        return Response(data)


class AllLessonsView(generics.ListAPIView):
    """
    Lista de lecciones. Filtros:
      - ?ordering=sequence (default) o cualquier campo permitido en Lesson
      - ?level=A1
      - ?is_active=true|false
      - ?native=es&target=en (solo lecciones que tengan localización para ese par)
    """
    permission_classes = [IsAuthenticated]
    serializer_class = LessonSerializer

    def get_queryset(self):
        ordering = self.request.query_params.get('ordering', 'sequence')
        level = self.request.query_params.get('level')
        is_active = self.request.query_params.get('is_active')

        native_code, target_code = get_lang_pair(self.request)

        qs = Lesson.objects.all()
        if level:
            qs = qs.filter(level=level)
        if is_active in ('true', 'false'):
            qs = qs.filter(is_active=(is_active == 'true'))

        # Filtra solo las que tengan localización para el par solicitado
        qs = qs.filter(
            localizations__native_language__code=native_code,
            localizations__target_language__code=target_code
        ).distinct()

        return (qs.order_by(ordering)
                  .prefetch_related(
                      'localizations',
                      'exercises__localizations',
                      'exercises__localizations__options'
                  ))

    def list(self, request, *args, **kwargs):
        native_code, target_code = get_lang_pair(request)
        qs = self.get_queryset()
        ser = LessonSerializer(qs, many=True, context={'request': request, 'native': native_code, 'target': target_code})
        return Response(ser.data)


class ExercisesByLevelLessonView(generics.ListAPIView):
    """
    GET /levels/<level>/lessons/<lesson_id>/exercises/?native=es&target=en
    Devuelve los ejercicios de la lección y SOLO su localización para el par nativo→objetivo.
    """
    permission_classes = [IsAuthenticated]
    serializer_class = ExerciseSerializer

    def get_queryset(self):
        level = self.kwargs['level']
        lesson_id = self.kwargs['lesson_id']
        native_code, target_code = get_lang_pair(self.request)

        return (Exercise.objects
                .filter(lesson_id=lesson_id, lesson__level=level)
                .prefetch_related(
                    Prefetch(
                        'localizations',
                        queryset=ExerciseLocalization.objects.filter(
                            native_language__code=native_code,
                            target_language__code=target_code
                        ).prefetch_related('options')
                    )
                )
                .order_by('sequence', 'id'))

    def list(self, request, *args, **kwargs):
        native_code, target_code = get_lang_pair(request)
        queryset = self.get_queryset()
        data = ExerciseSerializer(queryset, many=True, context={'request': request, 'native': native_code, 'target': target_code}).data
        return Response(data)


# -----------------------------
# SIGUIENTE LECCIÓN / ADAPTATIVO
# -----------------------------
class AdaptiveLessonView(APIView):
    """
    Devuelve la siguiente lección sugerida (pendiente) según el nivel del usuario
    y el par nativo→objetivo disponible.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        user_level = getattr(user, 'level', None) or 'A1'
        native_code, target_code = get_lang_pair(request)

        # Lecciones activas del nivel con localización para el par
        lessons = (Lesson.objects
                   .filter(is_active=True, level=user_level,
                           localizations__native_language__code=native_code,
                           localizations__target_language__code=target_code)
                   .prefetch_related('localizations', 'exercises__localizations', 'exercises__localizations__options')
                   .order_by('sequence', 'difficulty', '-priority', 'created_at')
                   .distinct())

        # Lecciones ya completadas por el usuario (independiente de par)
        completed_ids = set(UserLessonProgress.objects.filter(user=user, completed=True).values_list('lesson_id', flat=True))

        # Primera no completada
        lesson = next((l for l in lessons if l.id not in completed_ids), None)
        if not lesson:
            return Response({'message': 'No hay lecciones pendientes para tu nivel actual.'})

        ser = LessonSerializer(lesson, context={'request': request, 'native': native_code, 'target': target_code})
        return Response(ser.data)


class NextAvailableLessonView(APIView):
    """
    Devuelve la siguiente lección disponible para el usuario basado en su progreso,
    considerando el par nativo→objetivo.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        user_level = getattr(user, 'level', None) or 'A1'
        native_code, target_code = get_lang_pair(request)

        lessons = (Lesson.objects
                   .filter(is_active=True, level=user_level,
                           localizations__native_language__code=native_code,
                           localizations__target_language__code=target_code)
                   .order_by('sequence', 'difficulty')
                   .prefetch_related('localizations', 'exercises__localizations', 'exercises__localizations__options')
                   .distinct())

        completed_lessons = set(
            UserLessonProgress.objects.filter(user=user, completed=True).values_list('lesson_id', flat=True)
        )

        for lesson in lessons:
            if lesson.id not in completed_lessons:
                return Response({
                    'lesson': LessonSerializer(lesson, context={'request': request, 'native': native_code, 'target': target_code}).data,
                    'is_available': True,
                    'message': 'Siguiente lección disponible'
                })

        return Response({
            'lesson': None,
            'is_available': False,
            'message': '¡Felicidades! Has completado todas las lecciones de este nivel para este par de idiomas.'
        })


# -----------------------------
# PROGRESO DE LECCIONES
# -----------------------------
class LessonProgressView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        """
        Registra/actualiza progreso de una lección con estadísticas.
        Espera:
          lesson_id, total_exercises, correct_exercises, incorrect_exercises,
          completed (opcional), score (opcional)
        Usa ?native=es&target=en (o atributos del usuario) para guardar el par.
        """
        user = request.user
        native_code, target_code = get_lang_pair(request)
        try:
            native_lang = Language.objects.get(code=native_code)
            target_lang = Language.objects.get(code=target_code)
        except Language.DoesNotExist:
            return Response({'error': 'Par de idiomas inválido'}, status=status.HTTP_400_BAD_REQUEST)

        lesson_id = request.data.get('lesson_id')
        total_exercises = request.data.get('total_exercises', 0)
        correct_exercises = request.data.get('correct_exercises', 0)
        incorrect_exercises = request.data.get('incorrect_exercises', 0)

        if not lesson_id:
            return Response({'error': 'ID de lección es requerido'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            lesson = Lesson.objects.get(id=lesson_id)
        except Lesson.DoesNotExist:
            return Response({'error': 'Lección no encontrada'}, status=status.HTTP_404_NOT_FOUND)

        # Conversión de tipos robusta
        try:
            if isinstance(lesson_id, str):
                lesson_id = int(lesson_id)
            total_exercises = int(total_exercises) if total_exercises not in [None, '', 'null'] else 0
            correct_exercises = int(correct_exercises) if correct_exercises not in [None, '', 'null'] else 0
            incorrect_exercises = int(incorrect_exercises) if incorrect_exercises not in [None, '', 'null'] else 0
        except (ValueError, TypeError) as e:
            return Response({'error': f'Error en tipos de datos: {str(e)}'}, status=status.HTTP_400_BAD_REQUEST)

        if total_exercises < correct_exercises + incorrect_exercises:
            return Response({'error': 'Los ejercicios correctos e incorrectos no pueden sumar más que el total'},
                            status=status.HTTP_400_BAD_REQUEST)
        if total_exercises < 0 or correct_exercises < 0 or incorrect_exercises < 0:
            return Response({'error': 'Los números de ejercicios deben ser positivos'},
                            status=status.HTTP_400_BAD_REQUEST)

        # Regla de aprobación
        is_passed = correct_exercises >= 11
        completed = request.data.get('completed', is_passed)
        score = request.data.get('score', (correct_exercises / total_exercises * 100) if total_exercises > 0 else 0)

        progress, created = UserLessonProgress.objects.get_or_create(
            user=user,
            lesson=lesson,
            native_language=native_lang,
            target_language=target_lang,
            defaults={
                'total_exercises': total_exercises,
                'correct_exercises': correct_exercises,
                'incorrect_exercises': incorrect_exercises,
                'completed': completed,
                'score': score,
                'started_at': timezone.now(),
                'last_attempt_at': timezone.now(),
                'completed_at': timezone.now() if completed else None
            }
        )

        if not created:
            progress.total_exercises = total_exercises
            progress.correct_exercises = correct_exercises
            progress.incorrect_exercises = incorrect_exercises
            progress.completed = completed
            progress.score = score
            progress.last_attempt_at = timezone.now()
            if completed and not progress.completed_at:
                progress.completed_at = timezone.now()
            progress.save()

        return Response({
            'message': 'Progreso actualizado exitosamente',
            'progress': UserLessonProgressSerializer(progress, context={'request': request, 'native': native_code, 'target': target_code}).data,
            'is_passed': is_passed,
            'next_lesson_unlocked': is_passed
        })

    def get(self, request):
        """
        Lista el progreso del usuario autenticado, opcionalmente filtrado por par.
        """
        user = request.user
        native_code, target_code = get_lang_pair(request)
        qs = (UserLessonProgress.objects
              .filter(user=user)
              .select_related('lesson', 'native_language', 'target_language'))

        # Filtrar por par si se envía explícitamente
        if 'native' in request.query_params or 'target' in request.query_params:
            qs = qs.filter(native_language__code=native_code, target_language__code=target_code)

        ser = UserLessonProgressSerializer(qs, many=True, context={'request': request, 'native': native_code, 'target': target_code})
        return Response(ser.data)


# -----------------------------
# EJERCICIOS ESPECIALES
# -----------------------------
class ShadowingExerciseView(APIView):
    """
    Devuelve el primer ejercicio de shadowing disponible para el nivel del usuario
    y el par nativo→objetivo solicitado.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        user_level = getattr(user, 'level', None) or 'A1'
        native_code, target_code = get_lang_pair(request)

        # Elegimos una lección del nivel con localización disponible
        lesson = (Lesson.objects
                  .filter(level=user_level,
                          localizations__native_language__code=native_code,
                          localizations__target_language__code=target_code)
                  .order_by('sequence')
                  .first())
        if not lesson:
            return Response({'message': 'No hay lecciones para este nivel y par de idiomas.'})

        # Primer ejercicio tipo shadowing con localización para el par
        ex = (Exercise.objects
              .filter(lesson=lesson, exercise_type='shadowing')
              .prefetch_related(
                  Prefetch(
                      'localizations',
                      queryset=ExerciseLocalization.objects.filter(
                          native_language__code=native_code,
                          target_language__code=target_code
                      ).prefetch_related('options')
                  )
              )
              .order_by('sequence')
              .first())

        if not ex:
            return Response({
                'message': 'No hay ejercicios de shadowing para tu nivel y par.',
                'suggestion': 'Completa otras lecciones para desbloquear.'
            })

        return Response({
            'lesson': LessonSerializer(lesson, context={'request': request, 'native': native_code, 'target': target_code}).data,
            'exercise': ExerciseSerializer(ex, context={'request': request, 'native': native_code, 'target': target_code}).data
        })


# -----------------------------
# ENVÍO / CORRECCIÓN DE EJERCICIOS
# -----------------------------
class ExerciseSubmissionView(APIView):
    """
    Corrige un ejercicio según su tipo, usando la localización (native→target):
    - multiple_choice: requiere option_id (se valida que pertenezca a esa localización)
    - translation / fill_blank: compara con opciones correctas de esa localización
    - pronunciation / shadowing: usa score>=70 o presencia de respuesta
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        native_code, target_code = get_lang_pair(request)

        exercise_id = request.data.get('exercise_id')
        user_answer = (request.data.get('answer') or '').strip()
        score = request.data.get('score')

        if not exercise_id:
            return Response({'error': 'exercise_id es requerido'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            ex = Exercise.objects.get(id=exercise_id)
        except Exercise.DoesNotExist:
            return Response({'error': 'Ejercicio no encontrado'}, status=status.HTTP_404_NOT_FOUND)

        # Obtén la localización específica para el par
        ex_loc = (ExerciseLocalization.objects
                  .filter(exercise=ex,
                          native_language__code=native_code,
                          target_language__code=target_code)
                  .first())
        if not ex_loc:
            return Response({'error': 'No existe localización para este ejercicio y par de idiomas.'},
                            status=status.HTTP_400_BAD_REQUEST)

        is_correct = False
        correct_answer = ""
        feedback = None

        if ex.exercise_type in ['translation', 'fill_blank', 'word_formation']:
            correct_options = ex_loc.options.filter(is_correct=True)
            for opt in correct_options:
                ans = opt.text.strip()
                correct_answer = ans
                if user_answer.lower() == ans.lower():
                    is_correct = True
                    break
                # similitud básica por tokens
                cset, uset = set(ans.lower().split()), set(user_answer.lower().split())
                if cset and len(cset.intersection(uset)) / len(cset) >= 0.8:
                    is_correct = True
                    break

        elif ex.exercise_type == 'multiple_choice':
            option_id = request.data.get('option_id')
            if not option_id:
                return Response({'error': 'option_id requerido para opción múltiple'},
                                status=status.HTTP_400_BAD_REQUEST)
            try:
                sel = ExerciseOption.objects.get(id=option_id, exercise_localization=ex_loc)
                is_correct = sel.is_correct
                user_answer = sel.text
                
                # Obtener la respuesta correcta y feedback si es incorrecta
                if not is_correct:
                    correct_opt = ex_loc.options.filter(is_correct=True).first()
                    if correct_opt:
                        correct_answer = correct_opt.text
                        # Usar el feedback de la opción seleccionada si existe, sino el de la correcta
                        feedback = sel.feedback or correct_opt.feedback or None
                else:
                    feedback = sel.feedback or None
            except ExerciseOption.DoesNotExist:
                return Response({'error': 'Opción no encontrada para esta localización'}, status=status.HTTP_404_NOT_FOUND)

        elif ex.exercise_type in ['pronunciation', 'shadowing', 'speaking']:
            if score is not None:
                try:
                    is_correct = float(score) >= 70.0
                except ValueError:
                    is_correct = False
            else:
                is_correct = len(user_answer) > 0

        elif ex.exercise_type == 'audio_listening':
            expected_text = (ex_loc.expected_audio_text or '').strip()
            if expected_text and user_answer:
                is_correct = user_answer.lower().strip() == expected_text.lower()
            else:
                is_correct = len(user_answer) > 0

        elif ex.exercise_type == 'matching':
            # El frontend envía 'matches': {source1: target1, source2: target2, ...}
            matches = request.data.get('matches')
            if not matches or not isinstance(matches, dict):
                return Response({'error': 'Se requiere el campo "matches" con los emparejamientos'},
                                status=status.HTTP_400_BAD_REQUEST)
            
            # Obtener los pares correctos de matching_pairs
            correct_pairs = ex_loc.matching_pairs or []
            if not correct_pairs:
                return Response({'error': 'Este ejercicio no tiene pares definidos'},
                                status=status.HTTP_400_BAD_REQUEST)
            
            # Crear un mapa de source -> target correcto
            correct_map = {}
            for pair in correct_pairs:
                source = pair.get('left') or pair.get('source') or pair.get('native') or pair.get('a')
                target = pair.get('right') or pair.get('target') or pair.get('translated') or pair.get('b')
                if source and target:
                    correct_map[str(source)] = str(target)
            
            # Validar cada par
            correct_count = 0
            total_pairs = len(correct_map)
            validation_results = {}
            
            for source, user_target in matches.items():
                correct_target = correct_map.get(source)
                if correct_target and str(user_target).strip().lower() == str(correct_target).strip().lower():
                    correct_count += 1
                    validation_results[source] = True
                else:
                    validation_results[source] = False
            
            is_correct = correct_count == total_pairs
            user_answer = f"{correct_count}/{total_pairs} correctos"
            correct_answer = f"{total_pairs} pares correctos"
            
            # Agregar resultados de validación a la respuesta
            response_data = {
                'is_correct': is_correct,
                'user_answer': user_answer,
                'correct_answer': correct_answer,
                'validation_results': validation_results,
                'score': int((correct_count / total_pairs) * 100) if total_pairs > 0 else 0
            }
            
            return Response(response_data, status=status.HTTP_200_OK)

        elif ex.exercise_type == 'ordering':
            correct_order = ex_loc.correct_order or []
            if correct_order and user_answer:
                user_order = user_answer.split(',') if ',' in user_answer else [user_answer]
                is_correct = user_order == correct_order

        elif ex.exercise_type == 'drag_drop':
            is_correct = bool(user_answer)

        elif ex.exercise_type == 'true_false':
            is_correct = user_answer.lower() in ['true', 'verdadero', 't']

        else:
            return Response({'error': f'Tipo {ex.exercise_type} no soportado'},
                            status=status.HTTP_400_BAD_REQUEST)

        # Preparar respuesta
        response_data = {
            'is_correct': is_correct,
            'user_answer': user_answer,
            'score': score
        }
        
        # Agregar correct_answer y feedback si es incorrecto
        if not is_correct and correct_answer:
            response_data['correct_answer'] = correct_answer
        
        # Agregar feedback si existe (para cualquier tipo de ejercicio)
        if feedback:
            response_data['feedback'] = feedback
        
        return Response(response_data)


# -----------------------------
# PRONUNCIACIÓN (Whisper real y simulación)
# -----------------------------
class PronunciationFeedbackView(APIView):
    """
    Whisper real (local) — requiere ffmpeg y paquete whisper instalado.
    Recibe archivo 'file' (multipart) y expected_text (opcional).
    """
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser]

    def post(self, request, format=None):
        if 'file' not in request.data:
            return Response({'error': 'No se proporcionó ningún archivo'}, status=status.HTTP_400_BAD_REQUEST)

        audio_file = request.data['file']
        expected_text = (request.data.get('expected_text') or '').strip().lower()

        # Guardar temporalmente el archivo
        import tempfile, os
        with tempfile.NamedTemporaryFile(delete=False, suffix='.aac') as tmp:
            for chunk in audio_file.chunks():
                tmp.write(chunk)
            tmp_path = tmp.name

        # Require a real Whisper model — do not simulate on the server side.
        # If the model isn't loaded, return a clear error so the client can
        # surface it (the user requested no simulation fallbacks).
        if WHISPER_MODEL is None:
            try:
                return Response({
                    'error': 'Whisper model not available on server. Enable whisper and ffmpeg for real transcription.',
                    'whisper_load_error': WHISPER_LOAD_ERROR,
                }, status=status.HTTP_503_SERVICE_UNAVAILABLE)
            finally:
                try:
                    if os.path.exists(tmp_path):
                        os.unlink(tmp_path)
                except Exception:
                    pass

        # Si tenemos modelo, procesar con Whisper (rápido si usamos 'tiny')
        try:
            try:
                result = WHISPER_MODEL.transcribe(tmp_path, language='en', fp16=False)
            except FileNotFoundError as e:
                # Common on Windows when ffmpeg executable is missing from PATH
                return Response({
                    'error': 'Whisper transcription failed: ffmpeg not found on server. Please install ffmpeg and ensure it is available in PATH.',
                    'whisper_error': str(e),
                }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
            except Exception as e:
                # If transcription fails for other reasons, return an error — do not silently simulate.
                return Response({
                    'error': f'Whisper transcription failed: {str(e)}',
                    'whisper_error': str(e),
                }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

            transcribed_text = (result.get('text') or '').strip().lower()
            sim = self._similarity(transcribed_text, expected_text) if expected_text else 0.0
            score = int(sim * 100)
            is_correct = score >= 70
            feedback = (
                "¡Excelente! Pronunciación muy clara." if score >= 90 else
                "¡Muy bien! Se entiende, aún puedes pulir detalles." if score >= 75 else
                "Buen intento. Repite más despacio y articula mejor." if score >= 60 else
                "Necesitas practicar más. Concéntrate en las vocales y acentos."
            )
            return Response({
                'score': score,
                'feedback': feedback,
                'transcription': transcribed_text,
                'expected': expected_text,
                'similarity': round(sim, 2),
                'is_correct': is_correct,
                'simulated': False,
            })
        finally:
            try:
                if os.path.exists(tmp_path):
                    os.unlink(tmp_path)
            except Exception:
                pass

    def _similarity(self, a, b):
        tr = str.maketrans('', '', string.punctuation)
        a = a.translate(tr).strip().lower()
        b = b.translate(tr).strip().lower()
        return SequenceMatcher(None, a, b).ratio()


class PronunciationSubmissionView(APIView):
    """
    Simulación por tamaño del archivo (sin Whisper).
    Body: file (multipart), expected_text (opcional), exercise_id (opcional).
    """
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser]

    def post(self, request, format=None):
        if 'file' not in request.data:
            return Response({'error': 'No se proporcionó ningún archivo'}, status=status.HTTP_400_BAD_REQUEST)

        expected_text = (request.data.get('expected_text') or '').strip().lower()
        audio = request.data['file']
        size = len(audio.read())
        audio.seek(0)

        if size < 1024:
            score, feedback, transcription = 40, "Audio muy corto.", "Transcripción incompleta"
        elif size < 5120:
            score, feedback, transcription = 60, "Puedes mejorar la claridad.", "Transcripción parcial"
        elif size < 20480:
            score, feedback, transcription = 75, "Buena pronunciación.", "Transcripción obtenida"
        else:
            score, feedback, transcription = 85, "¡Excelente pronunciación!", "Transcripción completa"

        if expected_text:
            simple = f"Simulación: {expected_text[:50]}{'...' if len(expected_text) > 50 else ''}"
            if size > 5120:
                score = min(95, score + 10)
                feedback = f"¡Muy buena pronunciación! Texto reconocido: '{simple}'"
                transcription = simple

        return Response({
            'score': score,
            'feedback': feedback,
            'transcription': transcription,
            'is_correct': score >= 70.0
        })
