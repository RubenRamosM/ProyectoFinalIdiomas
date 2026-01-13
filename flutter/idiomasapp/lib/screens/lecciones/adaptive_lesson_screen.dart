import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/api.dart';
import 'pronunciation_screen.dart';
import '../shadowing/shadowing_exercise_screen.dart';

class LessonModel {
  final int id;
  final String title;
  final String content;
  final String level;
  final String lessonType;
  final String targetLanguage;
  final List<ExerciseModel> exercises;

  LessonModel({
    required this.id,
    required this.title,
    required this.content,
    required this.level,
    required this.lessonType,
    required this.targetLanguage,
    required this.exercises,
  });

  factory LessonModel.fromJson(Map<String, dynamic> json) {
    return LessonModel(
      id: json['id'] as int,
      title: json['title'] as String,
      content: json['content'] as String,
      level: json['level'] as String,
      lessonType: json['lesson_type'] as String,
      targetLanguage: json['target_language'] as String,
      exercises:
          (json['exercises'] as List)
              .map((e) => ExerciseModel.fromJson(e))
              .toList(),
    );
  }
}

class ExerciseModel {
  final int id;
  final String question;
  final String exerciseType;
  final String targetLanguage;
  final String nativeLanguage;
  final List<OptionModel> options;

  ExerciseModel({
    required this.id,
    required this.question,
    required this.exerciseType,
    required this.targetLanguage,
    required this.nativeLanguage,
    required this.options,
  });

  factory ExerciseModel.fromJson(Map<String, dynamic> json) {
    return ExerciseModel(
      id: json['id'] as int,
      question: json['question'] as String,
      exerciseType: json['exercise_type'] as String,
      targetLanguage: json['target_language'] as String,
      nativeLanguage: json['native_language'] as String,
      options:
          (json['options'] as List)
              .map((e) => OptionModel.fromJson(e))
              .toList(),
    );
  }
}

class OptionModel {
  final int id;
  final String text;
  final bool isCorrect;

  OptionModel({required this.id, required this.text, required this.isCorrect});

  factory OptionModel.fromJson(Map<String, dynamic> json) {
    return OptionModel(
      id: json['id'] as int,
      text: json['text'] as String,
      isCorrect: json['is_correct'] as bool,
    );
  }
}

class AdaptiveLessonScreen extends StatefulWidget {
  final int?
  lessonId; // Opcional: si se proporciona, carga esta lección específica

  const AdaptiveLessonScreen({super.key, this.lessonId});

  @override
  State<AdaptiveLessonScreen> createState() => _AdaptiveLessonScreenState();
}

class _AdaptiveLessonScreenState extends State<AdaptiveLessonScreen> {
  LessonModel? _currentLesson;
  bool _isLoading = true;
  int _currentExerciseIndex = 0;
  Map<int, int?> _selectedOptions = {}; // For multiple_choice exercises
  Map<int, String> _translationAnswers = {}; // For translation exercises
  Map<int, bool> _translationCorrect = {}; // Track if translation is correct
  Map<int, bool> _pronunciationCompleted = {}; // For pronunciation exercises
  Map<int, bool> _pronunciationCorrect =
      {}; // Track if pronunciation is correct
  Map<int, bool> _shadowingCompleted = {}; // For shadowing exercises
  Map<int, bool> _shadowingCorrect = {}; // Track if shadowing is correct
  bool _showResult = false;
  double? _lessonScore;
  final TextEditingController _translationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAdaptiveLesson();
  }

  Future<void> _loadAdaptiveLesson() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await Api.getToken();

      // Si se proporciona un lessonId, cargar esa lección específica
      if (widget.lessonId != null) {
        final response = await http.get(
          Uri.parse('${Api.baseUrl}lessons/all-lessons/'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          final List<dynamic> allLessons = json.decode(response.body);

          // Buscar la lección con el ID especificado
          final lessonData = allLessons.firstWhere(
            (l) => l['id'] == widget.lessonId,
            orElse: () => null,
          );

          if (lessonData != null) {
            final lesson = LessonModel.fromJson(lessonData);
            setState(() {
              _currentLesson = lesson;
              _isLoading = false;
            });
          } else {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Lección no encontrada')),
              );
            }
          }
        } else {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error al cargar la lección')),
            );
          }
        }
      } else {
        // Cargar lección adaptativa normal
        final response = await http.get(
          Uri.parse('${Api.baseUrl}lessons/adaptive-lesson/'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data.containsKey('title')) {
            // Si hay una lección disponible
            final lesson = LessonModel.fromJson(data);
            setState(() {
              _currentLesson = lesson;
              _isLoading = false;
            });
          } else {
            // Si no hay lecciones disponibles
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    data['message'] ?? 'No hay lecciones disponibles',
                  ),
                ),
              );
            }
          }
        } else {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error al cargar la lección')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
      }
    }
  }

  void _selectOption(int optionId) {
    if (_showResult)
      return; // No permitir seleccionar opciones después de ver el resultado

    setState(() {
      _selectedOptions[_currentExerciseIndex] =
          _selectedOptions[_currentExerciseIndex] == optionId ? null : optionId;
    });
  }

  void _submitExercise() async {
    final currentExercise = _currentLesson!.exercises[_currentExerciseIndex];

    // Validar según el tipo de ejercicio
    if (currentExercise.exerciseType == 'multiple_choice') {
      if (_selectedOptions[_currentExerciseIndex] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor selecciona una opción')),
        );
        return;
      }
    } else if (currentExercise.exerciseType == 'translation') {
      if (_translationController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor escribe tu traducción')),
        );
        return;
      }

      // Guardar la respuesta
      _translationAnswers[_currentExerciseIndex] =
          _translationController.text.trim();

      // Validar la traducción contra el backend
      try {
        final token = await Api.getToken();
        final response = await http.post(
          Uri.parse('${Api.baseUrl}lessons/exercise-submit/'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'exercise_id': currentExercise.id,
            'answer': _translationAnswers[_currentExerciseIndex],
          }),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          _translationCorrect[_currentExerciseIndex] =
              data['is_correct'] == true;
        } else {
          // Si hay error, asumir incorrecta para mostrar retroalimentación
          _translationCorrect[_currentExerciseIndex] = false;
        }
      } catch (e) {
        // Si hay error de conexión, asumir incorrecta
        _translationCorrect[_currentExerciseIndex] = false;
      }
    } else if (currentExercise.exerciseType == 'pronunciation') {
      if (_pronunciationCompleted[_currentExerciseIndex] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor graba tu pronunciación')),
        );
        return;
      }
    } else if (currentExercise.exerciseType == 'shadowing') {
      if (_shadowingCompleted[_currentExerciseIndex] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor completa el ejercicio de shadowing'),
          ),
        );
        return;
      }
    }

    setState(() {
      _showResult = true;
    });

    // Mostrar mensaje de correcto o incorrecto
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        if (_currentExerciseIndex < _currentLesson!.exercises.length - 1) {
          // Pasar al siguiente ejercicio
          setState(() {
            _currentExerciseIndex++;
            _showResult = false;
            _translationController.clear();
          });
        } else {
          // Terminar la lección
          _completeLesson();
        }
      }
    });
  }

  @override
  void dispose() {
    _translationController.dispose();
    super.dispose();
  }

  void _completeLesson() async {
    if (_currentLesson != null) {
      final token = await Api.getToken();

      // Contar ejercicios correctos según su tipo
      int correctCount = 0;
      for (var entry in _currentLesson!.exercises.asMap().entries) {
        final index = entry.key;
        final exercise = entry.value;

        if (exercise.exerciseType == 'multiple_choice') {
          // Para multiple choice, verificar si la opción seleccionada es correcta
          final selectedOptionId = _selectedOptions[index];
          if (selectedOptionId != null) {
            final correctOption = exercise.options.firstWhere(
              (option) => option.isCorrect,
              orElse: () => OptionModel(id: -1, text: '', isCorrect: false),
            );
            if (correctOption.id == selectedOptionId) {
              correctCount++;
            }
          }
        } else if (exercise.exerciseType == 'translation') {
          // Para translation, enviar la respuesta al backend para validación
          if (_translationAnswers.containsKey(index) &&
              _translationAnswers[index]!.isNotEmpty) {
            try {
              final response = await http.post(
                Uri.parse('${Api.baseUrl}lessons/exercise-submit/'),
                headers: {
                  'Authorization': 'Bearer $token',
                  'Content-Type': 'application/json',
                },
                body: json.encode({
                  'exercise_id': exercise.id,
                  'answer': _translationAnswers[index],
                }),
              );

              if (response.statusCode == 200) {
                final data = json.decode(response.body);
                if (data['is_correct'] == true) {
                  correctCount++;
                }
              } else {
                // Si hay error, asumir que la respuesta está bien (conservador)
                correctCount++;
              }
            } catch (e) {
              // Si hay error de conexión, asumir que la respuesta está bien (conservador)
              correctCount++;
            }
          }
        } else if (exercise.exerciseType == 'pronunciation') {
          // Para pronunciation, usar el resultado que ya guardamos
          if (_pronunciationCompleted[index] == true) {
            // Usar el resultado guardado de la pronunciación
            if (_pronunciationCorrect[index] == true) {
              correctCount++;
            }
          }
        } else if (exercise.exerciseType == 'shadowing') {
          // Para shadowing, usar el resultado que ya guardamos
          if (_shadowingCompleted[index] == true) {
            // Usar el resultado guardado del shadowing
            if (_shadowingCorrect[index] == true) {
              correctCount++;
            }
          }
        }
      }

      final score =
          _currentLesson!.exercises.isEmpty
              ? 0.0
              : (correctCount / _currentLesson!.exercises.length) * 100.0;

      // Enviar progreso a backend
      try {
        await http.post(
          Uri.parse('${Api.baseUrl}lessons/lesson-progress/'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'lesson_id': _currentLesson!.id,
            'completed': true,
            'score': score,
          }),
        );

        // Actualizar estadísticas diarias del usuario
        try {
          final totalExercises = _currentLesson!.exercises.length;
          await http.post(
            Uri.parse('${Api.baseUrl}users/progress/'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'lessons_completed': 1,
              'exercises_completed': totalExercises,
              'points_earned':
                  correctCount * 10, // 10 puntos por ejercicio correcto
              'time_spent': 0,
            }),
          );
        } catch (e) {
          debugPrint('Error al actualizar estadísticas: $e');
        }

        if (mounted) {
          setState(() {
            _lessonScore = score;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al guardar progreso: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lección Adaptativa')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentLesson == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lección Adaptativa')),
        body: const Center(child: Text('No se pudo cargar la lección')),
      );
    }

    final currentExercise = _currentLesson!.exercises[_currentExerciseIndex];
    final selectedOptionId = _selectedOptions[_currentExerciseIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentLesson!.title),
        actions: [
          if (_lessonScore != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                'Puntaje: ${_lessonScore!.round()}%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mostrar información de la lección
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lección: ${_currentLesson!.title}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentLesson!.content,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nivel: ${_currentLesson!.level}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Mostrar el ejercicio actual
            Text(
              'Ejercicio ${_currentExerciseIndex + 1}/${_currentLesson!.exercises.length}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentExercise.question,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Renderizar según el tipo de ejercicio
                  if (currentExercise.exerciseType == 'multiple_choice') ...[
                    // Mostrar opciones para ejercicios de opción múltiple
                    ...currentExercise.options.asMap().entries.map((entry) {
                      final index = entry.key;
                      final option = entry.value;
                      final isSelected = selectedOptionId == option.id;
                      final isCorrect = option.isCorrect;
                      final showResult = _showResult;

                      Color containerColor = Colors.transparent;
                      if (showResult) {
                        if (isCorrect) {
                          containerColor = Colors.green.withOpacity(0.2);
                        } else if (isSelected && !isCorrect) {
                          containerColor = Colors.red.withOpacity(0.2);
                        }
                      } else if (isSelected) {
                        containerColor = Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.2);
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: containerColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: ListTile(
                          title: Text(option.text),
                          leading:
                              showResult
                                  ? Icon(
                                    isCorrect
                                        ? Icons.check_circle
                                        : (isSelected ? Icons.cancel : null),
                                    color:
                                        isCorrect
                                            ? Colors.green
                                            : (isSelected ? Colors.red : null),
                                  )
                                  : (isSelected
                                      ? const Icon(Icons.check_circle)
                                      : null),
                          tileColor: containerColor,
                          onTap: () => _selectOption(option.id),
                        ),
                      );
                    }).toList(),
                  ] else if (currentExercise.exerciseType == 'translation') ...[
                    // Campo de texto para ejercicios de traducción
                    TextField(
                      controller: _translationController,
                      decoration: InputDecoration(
                        hintText: 'Escribe tu traducción aquí',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      maxLines: 3,
                      enabled: !_showResult,
                    ),
                    if (_showResult && currentExercise.options.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Respuesta correcta:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currentExercise.options
                                  .firstWhere((opt) => opt.isCorrect)
                                  .text,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ] else if (currentExercise.exerciseType ==
                      'pronunciation') ...[
                    // UI para ejercicios de pronunciación
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            _pronunciationCompleted[_currentExerciseIndex] ==
                                    true
                                ? Icons.check_circle
                                : Icons.mic,
                            size: 80,
                            color:
                                _pronunciationCompleted[_currentExerciseIndex] ==
                                        true
                                    ? Colors.green
                                    : Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _pronunciationCompleted[_currentExerciseIndex] ==
                                    true
                                ? '¡Grabación completada!'
                                : 'Presiona el botón para grabar',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed:
                                _showResult
                                    ? null
                                    : () {
                                      // Extraer el texto que debe pronunciar
                                      String expectedText = '';
                                      final questionMatch = RegExp(
                                        r'"([^"]+)"',
                                      ).firstMatch(currentExercise.question);
                                      if (questionMatch != null) {
                                        expectedText =
                                            questionMatch.group(1) ?? '';
                                      }

                                      // Navegar a la pantalla de pronunciación
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => PronunciationScreen(
                                                expectedText: expectedText,
                                              ),
                                        ),
                                      ).then((result) {
                                        // result puede ser true (correcto) o false (incorrecto)
                                        if (result != null) {
                                          setState(() {
                                            _pronunciationCompleted[_currentExerciseIndex] =
                                                true;
                                            _pronunciationCorrect[_currentExerciseIndex] =
                                                result == true;
                                          });
                                        }
                                      });
                                    },
                            icon: const Icon(Icons.mic),
                            label: const Text('Grabar Pronunciación'),
                          ),
                        ],
                      ),
                    ),
                  ] else if (currentExercise.exerciseType == 'shadowing') ...[
                    // UI para ejercicios de shadowing
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            _shadowingCompleted[_currentExerciseIndex] == true
                                ? Icons.check_circle
                                : Icons.record_voice_over,
                            size: 80,
                            color:
                                _shadowingCompleted[_currentExerciseIndex] ==
                                        true
                                    ? Colors.green
                                    : Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _shadowingCompleted[_currentExerciseIndex] == true
                                ? '¡Ejercicio completado!'
                                : 'Presiona el botón para practicar',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed:
                                _showResult
                                    ? null
                                    : () {
                                      // Extraer el texto que debe repetir
                                      String expectedText = '';
                                      final questionMatch = RegExp(
                                        r'"([^"]+)"',
                                      ).firstMatch(currentExercise.question);
                                      if (questionMatch != null) {
                                        expectedText =
                                            questionMatch.group(1) ?? '';
                                      }

                                      // Navegar a la pantalla de shadowing
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
                                                  ShadowingExerciseScreen(
                                                    expectedText: expectedText,
                                                  ),
                                        ),
                                      ).then((result) {
                                        // result puede ser true (correcto) o false (incorrecto)
                                        if (result != null) {
                                          setState(() {
                                            _shadowingCompleted[_currentExerciseIndex] =
                                                true;
                                            _shadowingCorrect[_currentExerciseIndex] =
                                                result == true;
                                          });
                                        }
                                      });
                                    },
                            icon: const Icon(Icons.record_voice_over),
                            label: const Text('Iniciar Shadowing'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Botón de envío o mensaje de resultado
            if (_showResult) ...[
              // Determinar si es correcto según el tipo de ejercicio
              () {
                bool isCorrect = false;
                if (currentExercise.exerciseType == 'multiple_choice') {
                  isCorrect =
                      currentExercise.options
                          .firstWhere(
                            (option) => option.isCorrect,
                            orElse:
                                () => OptionModel(
                                  id: -1,
                                  text: '',
                                  isCorrect: false,
                                ),
                          )
                          .id ==
                      selectedOptionId;
                } else if (currentExercise.exerciseType == 'translation') {
                  isCorrect =
                      _translationCorrect[_currentExerciseIndex] ?? false;
                } else if (currentExercise.exerciseType == 'pronunciation') {
                  // Usar el resultado real de la pronunciación
                  isCorrect =
                      _pronunciationCorrect[_currentExerciseIndex] ?? false;
                } else if (currentExercise.exerciseType == 'shadowing') {
                  // Usar el resultado real del shadowing
                  isCorrect = _shadowingCorrect[_currentExerciseIndex] ?? false;
                } else {
                  // Para otros tipos, asumir correcto si está completado
                  isCorrect = true;
                }

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        isCorrect
                            ? Colors.green.withOpacity(0.2)
                            : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isCorrect ? '¡Correcto!' : 'Incorrecto',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isCorrect ? Colors.green : Colors.red,
                    ),
                  ),
                );
              }(),
            ] else ...[
              ElevatedButton(
                onPressed: _submitExercise,
                child: Text(
                  _currentExerciseIndex < _currentLesson!.exercises.length - 1
                      ? 'Siguiente'
                      : 'Finalizar Lección',
                ),
              ),
            ],

            if (_lessonScore != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      '¡Lección completada!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tu puntuación: ${_lessonScore!.round()}%',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
