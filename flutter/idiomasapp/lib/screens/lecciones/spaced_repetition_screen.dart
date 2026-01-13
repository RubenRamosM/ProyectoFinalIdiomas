import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/api.dart';

class VocabularyItem {
  final int id;
  final String word;
  final String translation;
  final String exampleSentence;
  final String pronunciationGuide;
  final String level;

  VocabularyItem({
    required this.id,
    required this.word,
    required this.translation,
    required this.exampleSentence,
    required this.pronunciationGuide,
    required this.level,
  });

  factory VocabularyItem.fromJson(Map<String, dynamic> json) {
    return VocabularyItem(
      id: json['id'] as int,
      word: json['word'] as String,
      translation: json['translation'] as String,
      exampleSentence: json['example_sentence'] as String,
      pronunciationGuide: json['pronunciation_guide'] as String,
      level: json['level'] as String,
    );
  }
}

class SpacedRepetitionScreen extends StatefulWidget {
  const SpacedRepetitionScreen({super.key});

  @override
  State<SpacedRepetitionScreen> createState() => _SpacedRepetitionScreenState();
}

class _SpacedRepetitionScreenState extends State<SpacedRepetitionScreen> {
  List<VocabularyItem> _vocabularyItems = [];
  int _currentIndex = 0;
  bool _showTranslation = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSpacedRepetitionVocabulary();
  }

  Future<void> _loadSpacedRepetitionVocabulary() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await Api.getToken();
      final response = await http.get(
        Uri.parse('${Api.baseUrl}lessons/spaced-repetition/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final vocabularyList =
            data.map((json) => VocabularyItem.fromJson(json)).toList();

        setState(() {
          _vocabularyItems = vocabularyList;
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al cargar el vocabulario')),
          );
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

  Future<void> _updateSpacedRepetition(int quality) async {
    if (_vocabularyItems.isEmpty || _currentIndex >= _vocabularyItems.length)
      return;

    final vocabId = _vocabularyItems[_currentIndex].id;

    try {
      final token = await Api.getToken();
      final response = await http.post(
        Uri.parse('${Api.baseUrl}lessons/spaced-repetition/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'vocab_id': vocabId, 'quality': quality}),
      );

      if (response.statusCode == 200) {
        // Si hay más vocabulario, pasar al siguiente
        if (_currentIndex < _vocabularyItems.length - 1) {
          setState(() {
            _currentIndex++;
            _showTranslation = false;
          });
        } else {
          // Recargar la lista de vocabulario si se completó la sesión
          _currentIndex = 0;
          _showTranslation = false;
          await _loadSpacedRepetitionVocabulary();
        }
      } else {
        final data = json.decode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['error'] ?? 'Error al actualizar el estado'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Repetición Espaciada')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_vocabularyItems.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Repetición Espaciada')),
        body: const Center(
          child: Text('No hay vocabulario disponible para repasar'),
        ),
      );
    }

    if (_currentIndex >= _vocabularyItems.length) {
      return Scaffold(
        appBar: AppBar(title: const Text('Repetición Espaciada')),
        body: const Center(
          child: Text('¡Has completado la sesión de vocabulario!'),
        ),
      );
    }

    final currentVocab = _vocabularyItems[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Repetición Espaciada'),
        actions: [
          Text(
            '${_currentIndex + 1}/${_vocabularyItems.length}',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tarjeta del vocabulario
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Palabra en el idioma objetivo
                    Text(
                      currentVocab.word,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Guía de pronunciación
                    if (currentVocab.pronunciationGuide.isNotEmpty) ...[
                      Text(
                        '/${currentVocab.pronunciationGuide}/',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Nivel del vocabulario
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Nivel: ${currentVocab.level}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Botón para mostrar la traducción
                    if (!_showTranslation)
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _showTranslation = true;
                          });
                        },
                        child: const Text('Mostrar Traducción'),
                      ),

                    // Mostrar traducción y ejemplo
                    if (_showTranslation) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Traducción
                            Text(
                              currentVocab.translation,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            // Ejemplo
                            Text(
                              'Ejemplo:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              currentVocab.exampleSentence,
                              style: const TextStyle(fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Controles de calidad (solo si se mostró la traducción)
            if (_showTranslation) ...[
              const Text(
                '¿Qué tan bien recordaste esta palabra?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  _buildQualityButton(1, 'Olvidé por completo'),
                  _buildQualityButton(2, 'Difícil'),
                  _buildQualityButton(3, 'Bien'),
                  _buildQualityButton(4, 'Fácil'),
                  _buildQualityButton(5, 'Perfecto'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQualityButton(int value, String label) {
    Color color;
    switch (value) {
      case 1:
        color = Colors.red;
        break;
      case 2:
        color = Colors.orange;
        break;
      case 3:
        color = Colors.yellow;
        break;
      case 4:
        color = Colors.lightGreen;
        break;
      case 5:
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }

    return Expanded(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
        ),
        onPressed: () => _updateSpacedRepetition(value),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Text(
                value.toString(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
