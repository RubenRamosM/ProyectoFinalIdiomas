// lib/controllers/lesson_exercises_controller.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config.dart';
import '../services/api.dart';

/// =======================
/// Modelos
/// =======================

class LessonPayload {
  final String? level;
  final List<Exercise> exercises;
  LessonPayload({required this.level, required this.exercises});
}

class Exercise {
  final int id;
  final String question;
  final String
  exerciseType; // multiple_choice | translation | fill_blank | pronunciation | shadowing | audio_listening
  final List<Option> options;
  final String? audioUrl;
  final String? expectedAudioText;
  final List<Map<String, String>>? matchingPairs; // Para ejercicios matching
  int? selectedOptionId;

  Exercise({
    required this.id,
    required this.question,
    required this.exerciseType,
    required this.options,
    this.audioUrl,
    this.expectedAudioText,
    this.matchingPairs,
    this.selectedOptionId,
  });

  bool get isTextAnswer =>
      exerciseType == 'translation' ||
      exerciseType == 'fill_blank' ||
      exerciseType == 'audio_listening';

  factory Exercise.fromJson(Map<String, dynamic> j) {
    final loc = j['localization'] as Map<String, dynamic>?;

    final rawOptions =
        (loc != null
                ? (loc['options'] ?? loc['exercise_options'] ?? loc['choices'])
                : (j['options'] ?? j['exercise_options'] ?? j['choices']))
            as List?;
    final opts =
        rawOptions
            ?.map((e) => Option.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final question =
        (loc != null ? (loc['question'] ?? j['question']) : j['question'])
            ?.toString() ??
        '';
    final audioUrl =
        (loc != null ? loc['audio_url'] : j['audio_url']) as String?;
    final expectedAudioText =
        (loc != null ? loc['expected_audio_text'] : j['expected_audio_text'])
            as String?;

    // If the server provided matching_pairs (for matching exercises) and no
    // normal options were returned, flatten matching_pairs into a list of
    // display options so the UI can present the two sides. We generate
    // synthetic negative ids to avoid colliding with real option ids.
    List<Option> finalOpts = opts;
    List<Map<String, String>>? matchingPairsData;

    // Process matching_pairs if available and options are empty
    if (loc != null) {
      final mp = loc['matching_pairs'] as List?;
      final exerciseType = (j['exercise_type'] ?? 'multiple_choice').toString();

      // Para ejercicios matching, siempre intentar procesar matching_pairs si está disponible
      if (mp != null &&
          mp.isNotEmpty &&
          (opts.isEmpty || exerciseType == 'matching')) {
        // Guardar los pares originales
        matchingPairsData =
            mp
                .map((item) {
                  if (item is Map) {
                    final source =
                        (item['left'] ??
                                item['a'] ??
                                item['source'] ??
                                item['native'] ??
                                '')
                            .toString();
                    final target =
                        (item['right'] ??
                                item['b'] ??
                                item['target'] ??
                                item['translated'] ??
                                '')
                            .toString();
                    return {'source': source, 'target': target};
                  }
                  return <String, String>{};
                })
                .where((m) => m.isNotEmpty)
                .toList();

        final List<Option> mpOpts = [];
        int _sid = -1;
        final seen = <String>{};
        for (final item in mp) {
          try {
            if (item is Map) {
              // Support several possible key names used by different seeders/serializers
              // Common shapes: {"left":"...","right":"..."} or {"target": "en_text", "native": "es_text"}
              final left =
                  (item['left'] ??
                          item['a'] ??
                          item['source'] ??
                          item['native'] ??
                          '')
                      .toString();
              final right =
                  (item['right'] ??
                          item['b'] ??
                          item['target'] ??
                          item['translated'] ??
                          '')
                      .toString();
              if (left.isNotEmpty && !seen.contains(left)) {
                mpOpts.add(Option(id: _sid, text: left));
                seen.add(left);
                _sid--;
              }
              if (right.isNotEmpty && !seen.contains(right)) {
                mpOpts.add(Option(id: _sid, text: right));
                seen.add(right);
                _sid--;
              }
            }
          } catch (_) {}
        }
        // Solo usar matching_pairs si generamos opciones válidas
        if (mpOpts.isNotEmpty) {
          finalOpts = mpOpts;
        }
      }
    }

    return Exercise(
      id: j['id'] as int,
      question: question,
      exerciseType: (j['exercise_type'] ?? 'multiple_choice').toString(),
      options: finalOpts,
      audioUrl: audioUrl,
      expectedAudioText: expectedAudioText,
      matchingPairs: matchingPairsData,
    );
  }
}

class Option {
  final int id;
  final String text;
  Option({required this.id, required this.text});

  factory Option.fromJson(Map<String, dynamic> j) =>
      Option(id: j['id'] as int, text: (j['text'] ?? '').toString());
}

class SubmissionState {
  final bool loading;
  final bool done;
  final bool? isCorrect;
  final String? correctAnswer;
  final String? userAnswer;
  final String? score;
  final String? transcription;
  final String? feedback;
  final Map<String, bool>? validationResults; // Para matching
  final String? errorMessage;

  const SubmissionState._({
    required this.loading,
    required this.done,
    this.isCorrect,
    this.correctAnswer,
    this.userAnswer,
    this.score,
    this.transcription,
    this.feedback,
    this.validationResults,
    this.errorMessage,
  });
  factory SubmissionState.idle() =>
      const SubmissionState._(loading: false, done: false);
  factory SubmissionState.loading() =>
      const SubmissionState._(loading: true, done: false);

  factory SubmissionState.done({
    required bool isCorrect,
    String? correctAnswer,
    String? userAnswer,
    String? score,
    String? transcription,
    String? feedback,
    Map<String, bool>? validationResults,
  }) => SubmissionState._(
    loading: false,
    done: true,
    isCorrect: isCorrect,
    correctAnswer: correctAnswer,
    userAnswer: userAnswer,
    score: score,
    transcription: transcription,
    feedback: feedback,
    validationResults: validationResults,
  );

  factory SubmissionState.error(String msg) =>
      SubmissionState._(loading: false, done: false, errorMessage: msg);
}

/// =======================
/// Controller / Lógica
/// =======================

class LessonExercisesController extends ChangeNotifier {
  LessonExercisesController({
    required this.lessonId,
    required this.lessonTitle,
  });

  final int lessonId;
  final String lessonTitle;

  LessonPayload? _payload;

  // índice actual (una pregunta a la vez)
  int _currentIndex = 0;

  // Estados por ejercicio
  final Map<int, SubmissionState> _submissionStates = {};

  // Estadísticas
  int _totalExercises = 0;
  int _correctExercises = 0;
  int _incorrectExercises = 0;

  // Respuestas de texto (para no usar TextEditingController aquí)
  final Map<int, String> _textAnswers = {};

  // Respuestas de matching: exerciseId -> Map<source, target>
  final Map<int, Map<String, String>> _matchingAnswers = {};

  // Sugerencias similares (IA) cuando hay fallos
  final List<Exercise> _similarSuggestions = [];
  List<Exercise> get similarSuggestions =>
      List.unmodifiable(_similarSuggestions);

  // ---------- Getters p/ UI ----------
  LessonPayload? get payload => _payload;
  List<Exercise> get exercises => _payload?.exercises ?? [];
  int get currentIndex => _currentIndex;
  int get totalExercises => _totalExercises;
  int get correctExercises => _correctExercises;
  int get incorrectExercises => _incorrectExercises;

  Exercise get currentExercise => exercises[_currentIndex];
  SubmissionState stateOf(int exerciseId) =>
      _submissionStates[exerciseId] ?? SubmissionState.idle();

  bool canGoNext(Exercise ex) {
    final s = stateOf(ex.id);
    return s.done == true;
  }

  double get progress =>
      (exercises.isEmpty) ? 0.0 : (_currentIndex + 1) / exercises.length;

  // ---------- Mutadores de navegación ----------
  void goPrev() {
    if (_currentIndex > 0) {
      _currentIndex--;
      notifyListeners();
    }
  }

  void goNext() {
    if (_currentIndex < exercises.length - 1) {
      _currentIndex++;
      notifyListeners();
    }
  }

  void setSelectedOption(int exerciseId, int optionId) {
    final ex = exercises.firstWhere(
      (e) => e.id == exerciseId,
      orElse: () => currentExercise,
    );
    ex.selectedOptionId = optionId;
    notifyListeners();
  }

  void setTextAnswer(int exerciseId, String value) {
    _textAnswers[exerciseId] = value;
  }

  String getTextAnswer(int exerciseId) => _textAnswers[exerciseId] ?? '';

  void setMatchingAnswers(int exerciseId, Map<String, String> matches) {
    _matchingAnswers[exerciseId] = Map.from(matches);
    notifyListeners();
  }

  Map<String, String> getMatchingAnswers(int exerciseId) {
    return _matchingAnswers[exerciseId] ?? {};
  }

  /// Devuelve solo la frase objetivo para TTS (no el enunciado).
  /// Prioriza expectedAudioText; si no hay, intenta extraer lo que esté entre
  /// “…”, "…" o '…' en la pregunta. Si no hay, devuelve '' (no reproducir).
  String getSpeakablePrompt(Exercise ex) {
    final t = (ex.expectedAudioText ?? '').trim();
    if (t.isNotEmpty) return t;

    final q = (ex.question).trim();

    final rxSmart = RegExp('“([^”]+)”');
    final m1 = rxSmart.firstMatch(q);
    if (m1 != null && m1.groupCount >= 1) {
      final g = (m1.group(1) ?? '').trim();
      if (g.isNotEmpty) return g;
    }

    final rxDouble = RegExp(r'"([^"]+)"');
    final m2 = rxDouble.firstMatch(q);
    if (m2 != null && m2.groupCount >= 1) {
      final g = (m2.group(1) ?? '').trim();
      if (g.isNotEmpty) return g;
    }

    final rxSingle = RegExp(r"'([^']+)'");
    final m3 = rxSingle.firstMatch(q);
    if (m3 != null && m3.groupCount >= 1) {
      final g = (m3.group(1) ?? '').trim();
      if (g.isNotEmpty) return g;
    }

    return '';
  }

  // ---------- Carga inicial ----------
  Future<void> loadLesson() async {
    final token = await Api.getToken();
    final url = Uri.parse('${kApiBase}lessons/$lessonId/');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Error al cargar ejercicios: ${response.statusCode}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final items =
        (data['exercises'] as List?)
            ?.map((e) => Exercise.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    _payload = LessonPayload(level: data['level'] as String?, exercises: items);

    // Inicializar estados
    _submissionStates.clear();
    for (final ex in items) {
      _submissionStates[ex.id] = SubmissionState.idle();
    }

    _currentIndex = 0;
    _totalExercises = items.length;
    _correctExercises = 0;
    _incorrectExercises = 0;

    // limpiar sugerencias previas
    _similarSuggestions.clear();

    notifyListeners();
  }

  // ---------- Helpers de estado ----------
  void _markSubmission(
    Exercise ex, {
    required bool isCorrect,
    String? correctAnswer,
    String? userAnswer,
    String? score,
    String? transcription,
    String? feedback,
    Map<String, bool>? validationResults,
  }) {
    // Reversión si ya estaba respondido
    final prev = _submissionStates[ex.id];
    if (prev != null && prev.done) {
      if (prev.isCorrect == true) {
        _correctExercises = (_correctExercises - 1).clamp(0, 1 << 30);
      } else {
        _incorrectExercises = (_incorrectExercises - 1).clamp(0, 1 << 30);
      }
    }

    _submissionStates[ex.id] = SubmissionState.done(
      isCorrect: isCorrect,
      correctAnswer: correctAnswer,
      userAnswer: userAnswer,
      score: score,
      transcription: transcription,
      feedback: feedback,
      validationResults: validationResults,
    );

    if (isCorrect) {
      _correctExercises++;
    } else {
      _incorrectExercises++;
    }

    // Notificar cambios inmediatamente
    notifyListeners();
  }

  /// Marca el ejercicio de voz como omitido (incorrecto) y lo deja como "done"
  /// para permitir avanzar inmediatamente.
  void skipExercise(Exercise ex) {
    _markSubmission(ex, isCorrect: false, userAnswer: 'omitido', score: null);
    notifyListeners();
  }

  // ---------- IA: Notificar intento y cargar sugerencias ----------
  Future<void> _notifyIARecordAttempt({
    required Exercise ex,
    required bool isCorrect,
    String? score,
    String? topic,
    String? skill,
  }) async {
    try {
      final token = await Api.getToken();
      final url = Uri.parse(
        '${kApiBase}ia/record_attempt/',
      ); // ajusta si tu router difiere
      final body = {
        'exercise_id': ex.id,
        'is_correct': isCorrect,
        if (score != null) 'score': double.tryParse(score) ?? score,
        if (topic != null) 'topic': topic,
        if (skill != null) 'skill': skill,
      };
      final resp = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );
      if (resp.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
            'IA record_attempt fallo: ${resp.statusCode} ${resp.body}',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('IA record_attempt error: $e');
      }
    }
  }

  Future<void> _loadSimilarDue() async {
    _similarSuggestions.clear();
    try {
      final token = await Api.getToken();
      final url = Uri.parse('${kApiBase}ia/srs_due/?limit=5');
      final resp = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (resp.statusCode != 200) {
        if (kDebugMode) debugPrint('IA srs_due fallo: ${resp.statusCode}');
        return;
      }
      final list = (json.decode(resp.body) as List?) ?? [];
      for (final item in list) {
        final m = item as Map<String, dynamic>;
        _similarSuggestions.add(
          Exercise(
            id: m['exercise_id'] as int,
            question: (m['question'] ?? '').toString(),
            exerciseType: 'multiple_choice', // default seguro
            options: const [],
          ),
        );
      }
      // Si hay sugerencias, las integramos reemplazando las preguntas restantes
      // a partir de la actual, sin exceder 20 preguntas en total.
      if (_similarSuggestions.isNotEmpty && _payload != null) {
        final current = _payload!.exercises;
        // keep head: ejercicios ya recorridos hasta la actual (inclusive)
        final int headCount = (_currentIndex + 1).clamp(0, current.length);
        final head = current.sublist(0, headCount);

        const int maxTotal = 20;
        int available = maxTotal - head.length;
        if (available < 0) available = 0;

        // build unique suggestion tail
        final existingIds = head.map((e) => e.id).toSet();
        final List<Exercise> tail = [];
        for (final s in _similarSuggestions) {
          if (!existingIds.contains(s.id)) {
            tail.add(s);
            existingIds.add(s.id);
            if (tail.length >= available) break;
          }
        }

        // if not enough suggestions, fill with remaining original exercises
        if (tail.length < available) {
          for (
            int i = headCount;
            i < current.length && tail.length < available;
            i++
          ) {
            final e = current[i];
            if (!existingIds.contains(e.id)) {
              tail.add(e);
              existingIds.add(e.id);
            }
          }
        }

        final newList = <Exercise>[...head, ...tail];

        // update payload and submission states
        _payload = LessonPayload(level: _payload!.level, exercises: newList);

        final Map<int, SubmissionState> newStates = {};
        for (final ex in newList) {
          newStates[ex.id] = _submissionStates[ex.id] ?? SubmissionState.idle();
        }
        _submissionStates
          ..clear()
          ..addEntries(newStates.entries);

        _totalExercises = newList.length;
        if (_currentIndex >= _totalExercises) {
          _currentIndex = (_totalExercises - 1).clamp(0, _totalExercises);
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('IA srs_due error: $e');
    } finally {
      notifyListeners();
    }
  }

  // ---------- Envíos ----------
  Future<void> submitExercise(Exercise ex) async {
    // Pronunciación/shadowing se evalúa con audio, no por acá
    if (ex.exerciseType == 'pronunciation' || ex.exerciseType == 'shadowing') {
      return;
    }

    final token = await Api.getToken();
    final url = Uri.parse('${kApiBase}lessons/exercises/submit/');

    final Map<String, dynamic> body = {'exercise_id': ex.id};

    if (ex.exerciseType == 'multiple_choice') {
      if (ex.selectedOptionId == null) {
        throw Exception('Seleccione una opción antes de verificar.');
      }
      body['option_id'] = ex.selectedOptionId;
    } else if (ex.exerciseType == 'matching') {
      final matches = getMatchingAnswers(ex.id);
      final expectedPairs = ex.matchingPairs?.length ?? 0;

      if (matches.isEmpty) {
        throw Exception(
          'Seleccione al menos un emparejamiento antes de verificar.',
        );
      }

      if (matches.length < expectedPairs) {
        throw Exception(
          'Complete todos los emparejamientos (${matches.length}/$expectedPairs completados).',
        );
      }

      body['matches'] = matches;
    } else if (ex.isTextAnswer) {
      final ans = getTextAnswer(ex.id).trim();
      if (ans.isEmpty) {
        throw Exception('Escriba su respuesta antes de verificar.');
      }
      body['answer'] = ans;
    }

    _submissionStates[ex.id] = SubmissionState.loading();
    notifyListeners();

    try {
      final resp = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      if (resp.statusCode != 200) {
        throw Exception('Error ${resp.statusCode}');
      }

      final res = json.decode(resp.body) as Map<String, dynamic>;
      final isCorrect = (res['is_correct'] as bool?) ?? false;
      final correctAnswer = res['correct_answer'] as String?;
      final userAnswer = res['user_answer'] as String?;
      final score = res['score']?.toString();

      // Extract validation_results para matching
      Map<String, bool>? validationResults;
      if (res['validation_results'] != null &&
          res['validation_results'] is Map) {
        validationResults = Map<String, bool>.from(
          (res['validation_results'] as Map).map(
            (key, value) => MapEntry(key.toString(), value as bool),
          ),
        );
      }

      // Extract or generate feedback
      String? feedback = res['feedback'] as String?;
      if (feedback == null || feedback.isEmpty) {
        if (isCorrect) {
          feedback = '¡Correcto! Tu respuesta es la adecuada.';
        } else if (correctAnswer != null) {
          feedback = 'La respuesta correcta es: $correctAnswer';
        }
      }

      _markSubmission(
        ex,
        isCorrect: isCorrect,
        correctAnswer: correctAnswer,
        userAnswer: userAnswer,
        score: score,
        feedback: feedback,
        validationResults: validationResults,
      );

      // -------- IA: avisar intento y, si falló, cargar sugerencias --------
      // Wrapped in try-catch to prevent AI failures from blocking question progression
      try {
        await _notifyIARecordAttempt(
          ex: ex,
          isCorrect: isCorrect,
          score: score,
          topic: null, // si tu Exercise tiene topic/skill, pásalos aquí
          skill: null,
        );
        if (!isCorrect) {
          await _loadSimilarDue();
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('IA notification failed (non-critical): $e');
        }
      }

      notifyListeners();
    } catch (e) {
      _submissionStates[ex.id] = SubmissionState.error(
        'No se pudo verificar: $e',
      );
      notifyListeners();
    }
  }

  /// Sube el audio grabado para evaluación (Whisper real).
  /// Retorna (score, feedback, transcription).
  Future<(int, String, String?)> uploadPronunciation({
    required Exercise ex,
    required String filePath,
    String? promptText,
    bool useSimulation = false,
  }) async {
    if (!File(filePath).existsSync()) {
      throw Exception('No hay audio grabado.');
    }

    final token = await Api.getToken();
    final endpoint =
        useSimulation
            ? 'lessons/pronunciation/simulate/'
            : 'lessons/pronunciation/feedback/';
    final uri = Uri.parse('${kApiBase}$endpoint');

    final req =
        http.MultipartRequest('POST', uri)
          ..headers['Authorization'] = 'Bearer $token'
          ..fields['expected_text'] =
              (promptText ?? ex.expectedAudioText ?? ex.question)
          ..fields['exercise_id'] = ex.id.toString()
          ..files.add(
            await http.MultipartFile.fromPath(
              'file',
              filePath,
              contentType: MediaType('audio', 'aac'),
            ),
          );

    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode != 200) {
      // Do not silently fall back to simulation — surface server error to caller
      throw Exception('Error: ${resp.statusCode} ${resp.body}');
    }

    final data = json.decode(resp.body) as Map<String, dynamic>;
    final score = (data['score'] as num?)?.toInt() ?? 0;
    var feedback = (data['feedback'] as String?) ?? 'Sin feedback';
    final transcription =
        (data['transcription'] as String?) ?? data['text'] as String?;

    // regla: correcto si score >= 70
    final isCorrect = score >= 70;
    _markSubmission(
      ex,
      isCorrect: isCorrect,
      userAnswer: 'audio',
      score: '$score',
      transcription: transcription,
    );

    // IA: notificar intento de pronunciación y sugerencias si falla
    // Wrapped in try-catch to prevent AI failures from blocking question progression
    try {
      await _notifyIARecordAttempt(
        ex: ex,
        isCorrect: isCorrect,
        score: '$score',
        topic: null,
        skill: 'speaking',
      );
      if (!isCorrect) {
        await _loadSimilarDue();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('IA notification failed (non-critical): $e');
      }
    }

    notifyListeners();
    return (score, feedback, transcription);
  }

  // ---------- Progreso ----------
  Future<void> saveLessonProgress() async {
    final token = await Api.getToken();

    // 1. Guardar progreso de la lección
    final url = Uri.parse('${kApiBase}lessons/progress/');

    final body = {
      'lesson_id': lessonId,
      'total_exercises': _totalExercises,
      'correct_exercises': _correctExercises,
      'incorrect_exercises': _incorrectExercises,
    };

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Error al guardar progreso: ${response.statusCode}');
    }

    // 2. Actualizar estadísticas diarias del usuario
    try {
      final statsUrl = Uri.parse('${kApiBase}users/progress/');
      final statsBody = {
        'lessons_completed': 1, // 1 lección completada
        'exercises_completed':
            _totalExercises, // Total de ejercicios de esta lección
        'points_earned':
            _correctExercises * 10, // 10 puntos por ejercicio correcto
        'time_spent': 0, // Puedes calcular el tiempo si lo trackeas
      };

      await http.post(
        statsUrl,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(statsBody),
      );
    } catch (e) {
      // No lanzar error si falla el guardado de estadísticas, solo logear
      debugPrint('Error al actualizar estadísticas: $e');
    }
  }
}
