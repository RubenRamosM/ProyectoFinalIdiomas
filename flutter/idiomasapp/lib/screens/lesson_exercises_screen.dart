// lib/screens/lesson_exercises_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:math' as math;

import '../controllers/lesson_exercises_controller.dart';
import '../widgets/exercise_feedback_modal.dart';
import '../widgets/matching_exercise_widget.dart';

class LessonExercisesScreen extends StatefulWidget {
  final int lessonId;
  final String lessonTitle;

  const LessonExercisesScreen({
    Key? key,
    required this.lessonId,
    required this.lessonTitle,
  }) : super(key: key);

  @override
  State<LessonExercisesScreen> createState() => _LessonExercisesScreenState();
}

class _LessonExercisesScreenState extends State<LessonExercisesScreen> {
  late final LessonExercisesController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = LessonExercisesController(
      lessonId: widget.lessonId,
      lessonTitle: widget.lessonTitle,
    )..addListener(_onChange);

    _init();
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onChange);
    _ctrl.dispose();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _init() async {
    try {
      await _ctrl.loadLesson();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar: $e')));
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _onSubmit() async {
    final ex = _ctrl.currentExercise;
    try {
      await _ctrl.submitExercise(ex);

      if (!mounted) return;

      // Show modal if answer is incorrect
      final state = _ctrl.stateOf(ex.id);
      if (state.done && state.isCorrect == false) {
        await ExerciseFeedbackModal.show(
          context: context,
          correctAnswer: state.correctAnswer ?? 'No disponible',
          explanation: state.feedback,
          userAnswer: state.userAnswer,
          isCorrect: false,
          targetLanguageCode: 'en-US',
        );
      }
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _onFinishOrNext() async {
    final isLast = _ctrl.currentIndex == _ctrl.exercises.length - 1;
    if (isLast) {
      try {
        await _ctrl.saveLessonProgress();
        final calculatedScore =
            _ctrl.totalExercises > 0
                ? (_ctrl.correctExercises / _ctrl.totalExercises * 100).round()
                : 0;

        // TIP: si en backend cambiaste a % mínimo para aprobar, refleja lo mismo aquí.
        final isPassed = _ctrl.correctExercises >= 11;

        String title, message;
        if (isPassed) {
          title = '¡Lección Aprobada!';
          message =
              '¡Felicidades! Obtuviste $calculatedScore% (${_ctrl.correctExercises}/${_ctrl.totalExercises}).\n\n¡Se ha desbloqueado la siguiente lección!';
        } else if (_ctrl.correctExercises >= 10) {
          title = '¡Estuviste Cerca!';
          message =
              'Obtuviste $calculatedScore% (${_ctrl.correctExercises}/${_ctrl.totalExercises}).\n\nVuelve a intentarlo para aprobar.';
        } else {
          title = 'Lección Completada';
          message =
              'Obtuviste $calculatedScore% (${_ctrl.correctExercises}/${_ctrl.totalExercises}).\n\nSigue practicando para mejorar.';
        }
        if (!mounted) return;
        _showResultDialog(title, message, isPassed);
      } catch (e) {
        _showSnack(e.toString().replaceFirst('Exception: ', ''));
      }
    } else {
      _ctrl.goNext();
    }
  }

  void _showResultDialog(String title, String message, bool isSuccess) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  isSuccess ? Icons.celebration : Icons.school,
                  color: isSuccess ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(title),
              ],
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(); // volver
                },
                child: const Text('Continuar'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exercises = _ctrl.exercises;
    final isLoading = _ctrl.payload == null;

    return Scaffold(
      appBar: AppBar(title: Text(widget.lessonTitle)),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : (exercises.isEmpty
                  ? const Center(
                    child: Text('No hay ejercicios para esta lección.'),
                  )
                  : Column(
                    children: [
                      // Progreso
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            LinearProgressIndicator(value: _ctrl.progress),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Correctas: ${_ctrl.correctExercises} | Incorrectas: ${_ctrl.incorrectExercises}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: Colors.grey[600]),
                                ),
                                Text(
                                  'Pregunta ${_ctrl.currentIndex + 1} de ${exercises.length}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),

                      // Pregunta actual
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Card(
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: _QuestionView(
                                ctrl: _ctrl,
                                exercise: _ctrl.currentExercise,
                                onSnack: _showSnack,
                                onSkipPron: () async {
                                  _ctrl.skipExercise(_ctrl.currentExercise);
                                  await _onFinishOrNext();
                                },
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Navegación inferior
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Primera fila: Anterior
                              if (_ctrl.currentIndex > 0)
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _ctrl.goPrev,
                                    icon: const Icon(Icons.chevron_left),
                                    label: const Text('Anterior'),
                                  ),
                                ),
                              if (_ctrl.currentIndex > 0)
                                const SizedBox(height: 8),

                              // Segunda fila: Verificar y Siguiente
                              Row(
                                children: [
                                  if (!(_ctrl.currentExercise.exerciseType ==
                                          'pronunciation' ||
                                      _ctrl.currentExercise.exerciseType ==
                                          'shadowing')) ...[
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () async => _onSubmit(),
                                        icon: const Icon(Icons.check),
                                        label: const Text('Verificar'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed:
                                          _ctrl.canGoNext(_ctrl.currentExercise)
                                              ? _onFinishOrNext
                                              : null,
                                      icon: Icon(
                                        _ctrl.currentIndex ==
                                                exercises.length - 1
                                            ? Icons.flag
                                            : Icons.chevron_right,
                                      ),
                                      label: Text(
                                        _ctrl.currentIndex ==
                                                exercises.length - 1
                                            ? 'Finalizar'
                                            : 'Siguiente',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final Color color;

  WaveformPainter(this.amplitudes, {this.color = Colors.blueAccent});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withOpacity(0.9);
    final bg = Paint()..color = Colors.transparent;
    canvas.drawRect(Offset.zero & size, bg);

    if (amplitudes.isEmpty) return;

    // multi-bar compact
    const int bands = 7;
    final spacing = 6.0;
    final barWidth = (size.width - (bands - 1) * spacing) / bands;

    final int bufLen = amplitudes.length;
    for (int i = 0; i < bands; i++) {
      final start = ((i / bands) * bufLen).floor();
      final end = (((i + 1) / bands) * bufLen).floor();
      double avg = 0.0;
      if (end > start && bufLen > 0) {
        final slice = amplitudes.sublist(start, end);
        avg = slice.reduce((a, b) => a + b) / slice.length;
      } else if (bufLen > 0) {
        avg = amplitudes.last;
      }

      final shaped = avg * (0.6 + 0.4 * (1.0 - (i / bands)));
      final h = shaped.clamp(0.0, 1.0) * size.height;

      final x = i * (barWidth + spacing);
      final rect = Rect.fromLTWH(x, (size.height - h) / 2, barWidth, h);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    if (oldDelegate.amplitudes.length != amplitudes.length) return true;
    for (var i = 0; i < amplitudes.length; i++) {
      if (oldDelegate.amplitudes[i] != amplitudes[i]) return true;
    }
    return false;
  }
}

/* =======================
 *  Widgets de vista
 * ======================= */

class _QuestionView extends StatelessWidget {
  final LessonExercisesController ctrl;
  final Exercise exercise;
  final void Function(String msg) onSnack;
  final Future<void> Function() onSkipPron;

  const _QuestionView({
    Key? key,
    required this.ctrl,
    required this.exercise,
    required this.onSnack,
    required this.onSkipPron,
  }) : super(key: key);

  Map<String, bool>? _parseValidationResults(SubmissionState state) {
    // El backend devuelve los resultados de validación para matching
    return state.validationResults;
  }

  @override
  Widget build(BuildContext context) {
    final isMCQ = exercise.exerciseType == 'multiple_choice';
    final isPron =
        exercise.exerciseType == 'pronunciation' ||
        exercise.exerciseType == 'shadowing';

    final subState = ctrl.stateOf(exercise.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado + tipo
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                exercise.question,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            _ExerciseTypeChip(type: exercise.exerciseType),
          ],
        ),
        const SizedBox(height: 12),

        if (isMCQ && exercise.options.isNotEmpty) ...[
          ...exercise.options.map(
            (opt) => RadioListTile<int>(
              value: opt.id,
              groupValue: exercise.selectedOptionId,
              onChanged: (v) => ctrl.setSelectedOption(exercise.id, v!),
              title: Text(opt.text),
              dense: true,
            ),
          ),
        ] else if (exercise.exerciseType == 'matching') ...[
          if (exercise.matchingPairs != null &&
              exercise.matchingPairs!.isNotEmpty)
            MatchingExerciseWidget(
              pairs:
                  exercise.matchingPairs!
                      .map(
                        (m) => MatchingPair(
                          source: m['source'] ?? '',
                          target: m['target'] ?? '',
                        ),
                      )
                      .toList(),
              onSubmit: (matches) {
                ctrl.setMatchingAnswers(exercise.id, matches);
              },
              isSubmitted: subState.done,
              validationResults:
                  subState.done ? _parseValidationResults(subState) : null,
            )
          else
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Ejercicio de emparejamiento (sin datos disponibles)',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ] else if (isPron) ...[
          PronunciationControls(
            promptText: ctrl.getSpeakablePrompt(exercise),
            audioHintUrl: exercise.audioUrl,
            exercise: exercise,
            onEvaluated: (score, feedback, transcription) {
              final t =
                  (transcription == null || transcription.isEmpty)
                      ? '—'
                      : transcription;
              onSnack('Puntaje: $score — $feedback\nTranscripción: $t');
            },
            upload:
                (filePath, promptText) => ctrl.uploadPronunciation(
                  ex: exercise,
                  filePath: filePath,
                  promptText: promptText,
                  useSimulation: false, // real eval (Whisper en tu backend)
                ),
            onSkip: onSkipPron,
          ),
        ] else if (exercise.isTextAnswer) ...[
          if (exercise.audioUrl != null) ...[
            Row(
              children: const [
                Icon(Icons.volume_up),
                SizedBox(width: 8),
                Text('Escucha el audio'),
              ],
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            key: ValueKey('answer_tf_${exercise.id}'),
            controller: TextEditingController(
                text: ctrl.getTextAnswer(exercise.id),
              )
              ..selection = TextSelection.collapsed(
                offset: ctrl.getTextAnswer(exercise.id).length,
              ),
            decoration: const InputDecoration(
              labelText: 'Tu respuesta',
              border: OutlineInputBorder(),
            ),
            minLines: 1,
            maxLines: 4,
            onChanged: (v) => ctrl.setTextAnswer(exercise.id, v),
          ),
        ],

        const SizedBox(height: 12),

        if (subState.done || subState.errorMessage != null)
          _FeedbackBadge(state: subState),

        // Sugerencias
        if (subState.done &&
            subState.isCorrect == false &&
            ctrl.similarSuggestions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            elevation: 1,
            color: Colors.blueGrey.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.lightbulb_outline),
                      SizedBox(width: 8),
                      Text('Recomendado para reforzar'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...ctrl.similarSuggestions
                      .take(3)
                      .map(
                        (sug) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            sug.question.isEmpty
                                ? 'Ejercicio #${sug.id}'
                                : sug.question,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.open_in_new),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Sugerido: Ejercicio ${sug.id}. (Navegación pendiente)',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  if (ctrl.similarSuggestions.length > 3)
                    Text(
                      '+ ${ctrl.similarSuggestions.length - 3} sugerencias más',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
        ],

        if (subState.done) ...[
          const SizedBox(height: 8),
          if (subState.correctAnswer != null)
            Text(
              'Respuesta correcta: ${subState.correctAnswer}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[800]),
            ),
          if (subState.userAnswer != null)
            Text(
              'Tu respuesta: ${subState.userAnswer}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (subState.transcription != null)
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Text(
                'Transcripción: ${subState.transcription}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          if (subState.score != null)
            Text(
              'Puntaje: ${subState.score}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ],
    );
  }
}

class _FeedbackBadge extends StatelessWidget {
  final SubmissionState state;
  const _FeedbackBadge({Key? key, required this.state}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (state.errorMessage != null) {
      return Chip(
        avatar: const Icon(Icons.error_outline, color: Colors.white),
        backgroundColor: Colors.redAccent,
        label: Text(
          state.errorMessage!,
          style: const TextStyle(color: Colors.white),
        ),
      );
    }
    if (state.done) {
      final ok = state.isCorrect == true;
      return Chip(
        avatar: Icon(
          ok ? Icons.check_circle : Icons.cancel,
          color: Colors.white,
        ),
        backgroundColor: ok ? Colors.green : Colors.orange,
        label: Text(
          ok ? 'Correcto' : 'Incorrecto',
          style: const TextStyle(color: Colors.white),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _ExerciseTypeChip extends StatelessWidget {
  final String type;
  const _ExerciseTypeChip({Key? key, required this.type}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String label;
    switch (type) {
      case 'multiple_choice':
        label = 'Opción múltiple';
        break;
      case 'translation':
        label = 'Traducción';
        break;
      case 'fill_blank':
        label = 'Completar';
        break;
      case 'pronunciation':
        label = 'Pronunciación';
        break;
      case 'shadowing':
        label = 'Shadowing';
        break;
      case 'audio_listening':
        label = 'Escucha y escribe';
        break;
      default:
        label = type;
    }
    return Chip(label: Text(label));
  }
}

/* =======================
 *  Widget: Pronunciation
 * ======================= */

class PronunciationControls extends StatefulWidget {
  final String promptText;
  final String? audioHintUrl;
  final Exercise exercise;
  final Future<(int score, String feedback, String? transcription)> Function(
    String filePath,
    String promptText,
  )
  upload;
  final void Function(int score, String feedback, String? transcription)
  onEvaluated;

  /// Callback para omitir la pregunta de voz
  final Future<void> Function() onSkip;

  const PronunciationControls({
    Key? key,
    required this.promptText,
    required this.exercise,
    required this.upload,
    required this.onEvaluated,
    required this.onSkip,
    this.audioHintUrl,
  }) : super(key: key);

  @override
  State<PronunciationControls> createState() => _PronunciationControlsState();
}

class _PronunciationControlsState extends State<PronunciationControls> {
  final FlutterTts _tts = FlutterTts();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  bool _isRecording = false;
  bool _isUploading = false;
  String? _filePath;
  final List<double> _amplitudes = [];
  StreamSubscription? _recorderSubscription;
  double _speechRate = 0.9;

  // Barra de grabación (tipo WhatsApp)
  int _recordSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('en-US');
    _tts.setPitch(1.0);
    _tts.setSpeechRate(_speechRate);
  }

  @override
  void dispose() {
    _tts.stop();
    _recorderSubscription?.cancel();
    _timer?.cancel();
    _recorder.closeRecorder();
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _speak() async {
    final phrase = widget.promptText.trim();
    if (phrase.isEmpty) return;
    await _tts.stop();
    await _tts.setSpeechRate(_speechRate);
    await _tts.speak(phrase);
  }

  Future<void> _startRecording() async {
    // permisos
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Se requiere acceso al micrófono.')),
      );
      return;
    }

    final dir = await getTemporaryDirectory();
    _filePath = '${dir.path}/pron_${DateTime.now().millisecondsSinceEpoch}.m4a';

    // abrir y configurar subscripción de progreso más fluida
    await _recorder.openRecorder();
    await _recorder.setSubscriptionDuration(const Duration(milliseconds: 60));

    // iniciar grabación
    await _recorder.startRecorder(
      toFile: _filePath!,
      codec: Codec.aacMP4,
      bitRate: 64000,
      sampleRate: 44100,
      numChannels: 1,
    );

    // escuchar decibeles y mapear a 0..1
    try {
      _recorderSubscription = _recorder.onProgress?.listen((event) {
        double amp = 0.0;
        try {
          final dyn = event as dynamic;
          final db = (dyn.decibels != null) ? (dyn.decibels as double) : null;
          if (db != null && db.isFinite) {
            // -60 dB (silencio) a 0 dB (fuerte) -> 0..1
            amp = ((db + 60) / 60).clamp(0.0, 1.0);
          } else {
            // fallback con jitter leve si no hay decibeles
            amp = 0.15 + (math.Random().nextDouble() * 0.1);
          }
        } catch (_) {
          amp = 0.0;
        }
        if (!mounted) return;
        setState(() {
          _amplitudes.add(amp);
          if (_amplitudes.length > 64) _amplitudes.removeAt(0);
        });
      });
    } catch (_) {}

    // timer visible
    _recordSeconds = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _recordSeconds++);
    });

    setState(() => _isRecording = true);
  }

  Future<void> _stopRecording() async {
    try {
      await _recorder.stopRecorder();
    } finally {
      _recorderSubscription?.cancel();
      _recorderSubscription = null;
      _timer?.cancel();
      setState(() => _isRecording = false);
    }
  }

  Future<void> _showTranscriptionSheet({
    required int score,
    required String feedback,
    required String? transcription,
  }) async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            top: 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.graphic_eq),
                  const SizedBox(width: 8),
                  Text(
                    'Resultado de pronunciación',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (score / 100).clamp(0.0, 1.0),
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$score',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                feedback,
                style: Theme.of(
                  ctx,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[800]),
              ),
              const SizedBox(height: 12),
              Text('Transcripción:', style: Theme.of(ctx).textTheme.labelLarge),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade50,
                ),
                child: Text(
                  (transcription == null || transcription.trim().isEmpty)
                      ? '— (no se obtuvo transcripción)'
                      : transcription,
                  style: Theme.of(
                    ctx,
                  ).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Entendido'),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _send() async {
    if (_filePath == null || !File(_filePath!).existsSync()) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No hay audio grabado.')));
      return;
    }

    setState(() => _isUploading = true);
    try {
      final (score, feedback, transcription) = await widget.upload(
        _filePath!,
        widget.promptText,
      );

      if (!mounted) return;
      // Notifica al padre (para estadística/toast)
      widget.onEvaluated(score, feedback, transcription);

      // Muestra modal con score + transcripción
      await _showTranscriptionSheet(
        score: score,
        feedback: feedback,
        transcription: transcription,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al evaluar: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isRecording || _isUploading;

    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Frase objetivo:',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.promptText.isEmpty ? '—' : widget.promptText,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 12),

        // Controles principales
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 520;
            final controls = [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.volume_up),
                  label: const Text('Escuchar frase'),
                  onPressed: _isUploading ? null : _speak,
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<double>(
                tooltip: 'Velocidad',
                onSelected: (v) async {
                  setState(() => _speechRate = v);
                  await _tts.setSpeechRate(_speechRate);
                },
                itemBuilder:
                    (_) => const [
                      PopupMenuItem(value: 0.6, child: Text('Lento')),
                      PopupMenuItem(value: 0.8, child: Text('Normal')),
                      PopupMenuItem(value: 1.0, child: Text('Rápido')),
                    ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.speed),
                      const SizedBox(width: 4),
                      Text(
                        _speechRate == 0.6
                            ? 'Lento'
                            : (_speechRate == 1.0 ? 'Rápido' : 'Normal'),
                      ),
                    ],
                  ),
                ),
              ),
            ];

            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: controls),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                    label: Text(_isRecording ? 'Detener' : 'Grabar'),
                    onPressed:
                        _isUploading
                            ? null
                            : () async {
                              if (_isRecording) {
                                await _stopRecording();
                              } else {
                                await _startRecording();
                              }
                            },
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: Row(children: controls)),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                    label: Text(_isRecording ? 'Detener' : 'Grabar'),
                    onPressed:
                        _isUploading
                            ? null
                            : () async {
                              if (_isRecording) {
                                await _stopRecording();
                              } else {
                                await _startRecording();
                              }
                            },
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 12),

        // Barra tipo WhatsApp mientras graba
        if (_isRecording)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.fiber_manual_record, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Grabando • ${_formatDuration(_recordSeconds)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.red[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 28,
                    child: CustomPaint(
                      painter: WaveformPainter(
                        List.of(_amplitudes),
                        color: Colors.redAccent,
                      ),
                      child: Container(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Detener',
                  icon: const Icon(Icons.stop),
                  color: Colors.red,
                  onPressed: _stopRecording,
                ),
              ],
            ),
          ),

        // Waveform general (mientras o no graba)
        const SizedBox(height: 12),
        SizedBox(
          height: 64,
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: CustomPaint(
              painter: WaveformPainter(List.of(_amplitudes)),
              child: Container(),
            ),
          ),
        ),

        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.upload),
            label: const Text('Enviar para evaluación'),
            onPressed: (_isRecording || _isUploading) ? null : _send,
          ),
        ),
        const SizedBox(height: 8),

        // Botón para omitir
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            icon: const Icon(Icons.skip_next),
            label: const Text('No puedo hablar en estos momentos'),
            onPressed:
                isBusy
                    ? null
                    : () async {
                      if (_isRecording) {
                        await _stopRecording();
                      }
                      await widget.onSkip();
                    },
          ),
        ),

        if (_isUploading)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}
