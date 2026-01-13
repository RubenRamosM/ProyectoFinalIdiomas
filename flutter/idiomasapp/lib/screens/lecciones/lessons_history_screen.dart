import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/api.dart';

class LessonProgress {
  final int id;
  final String lessonTitle;
  final String lessonLevel;
  final bool completed;
  final double score;
  final DateTime completedAt;

  LessonProgress({
    required this.id,
    required this.lessonTitle,
    required this.lessonLevel,
    required this.completed,
    required this.score,
    required this.completedAt,
  });

  factory LessonProgress.fromJson(Map<String, dynamic> json) {
    // Defensive parsing: backend may return nested structures or nulls
    int id = 0;
    try {
      id =
          (json['id'] is int)
              ? json['id'] as int
              : int.tryParse((json['id'] ?? '').toString()) ?? 0;
    } catch (_) {
      id = 0;
    }

    final lessonObj =
        (json['lesson'] is Map)
            ? Map<String, dynamic>.from(json['lesson'] as Map)
            : <String, dynamic>{};

    String lessonTitle = 'Lección';
    try {
      lessonTitle =
          (lessonObj['title'] ??
                  lessonObj['localization']?['title'] ??
                  lessonObj['localization']?['content'] ??
                  '')
              .toString();
      if (lessonTitle.trim().isEmpty) lessonTitle = 'Lección';
    } catch (_) {
      lessonTitle = 'Lección';
    }

    String lessonLevel = (lessonObj['level'] ?? '').toString();
    if (lessonLevel.isEmpty) lessonLevel = 'N/A';

    final completed =
        (json['completed'] is bool)
            ? json['completed'] as bool
            : (json['completed'] == 1 ||
                (json['completed']?.toString().toLowerCase() == 'true'));

    final score =
        (json['score'] is num)
            ? (json['score'] as num).toDouble()
            : double.tryParse((json['score'] ?? '').toString()) ?? 0.0;

    DateTime completedAt;
    try {
      final s = json['completed_at'];
      if (s == null) {
        completedAt = DateTime.fromMillisecondsSinceEpoch(0);
      } else if (s is String && s.isNotEmpty) {
        completedAt =
            DateTime.tryParse(s) ?? DateTime.fromMillisecondsSinceEpoch(0);
      } else {
        completedAt = DateTime.fromMillisecondsSinceEpoch(0);
      }
    } catch (_) {
      completedAt = DateTime.fromMillisecondsSinceEpoch(0);
    }

    return LessonProgress(
      id: id,
      lessonTitle: lessonTitle,
      lessonLevel: lessonLevel,
      completed: completed,
      score: score,
      completedAt: completedAt,
    );
  }
}

class LessonsHistoryScreen extends StatefulWidget {
  const LessonsHistoryScreen({super.key});

  @override
  State<LessonsHistoryScreen> createState() => _LessonsHistoryScreenState();
}

class _LessonsHistoryScreenState extends State<LessonsHistoryScreen> {
  List<LessonProgress> _lessonsHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLessonsHistory();
  }

  Future<void> _loadLessonsHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await Api.getToken();
      final response = await http.get(
        Uri.parse('${Api.baseUrl}lessons/lesson-progress/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final history =
            data.map((json) => LessonProgress.fromJson(json)).toList();

        // Ordenar por fecha (más reciente primero)
        history.sort((a, b) => b.completedAt.compareTo(a.completedAt));

        setState(() {
          _lessonsHistory = history;
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al cargar el historial')),
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

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getScoreText(double score) {
    if (score >= 80) return 'Excelente';
    if (score >= 60) return 'Bien';
    return 'Necesita práctica';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de Lecciones')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _lessonsHistory.isEmpty
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.school_outlined, size: 80, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No has completado ninguna lección aún',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Comienza tu primera lección desde la pantalla principal',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _loadLessonsHistory,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _lessonsHistory.length,
                  itemBuilder: (context, index) {
                    final lesson = _lessonsHistory[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getScoreColor(lesson.score),
                          child: Text(
                            '${lesson.score.round()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        title: Text(
                          lesson.lessonTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('Nivel: ${lesson.lessonLevel}'),
                            Text(_getScoreText(lesson.score)),
                            Text(
                              'Completado: ${_formatDate(lesson.completedAt)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        trailing:
                            lesson.completed
                                ? Icon(
                                  Icons.check_circle,
                                  color: _getScoreColor(lesson.score),
                                )
                                : const Icon(Icons.pending, color: Colors.grey),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
              ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Hoy';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
