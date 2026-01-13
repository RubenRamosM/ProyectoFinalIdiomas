import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/api.dart';

class LessonHistoryScreen extends StatefulWidget {
  const LessonHistoryScreen({super.key});

  @override
  State<LessonHistoryScreen> createState() => _LessonHistoryScreenState();
}

class _LessonHistoryScreenState extends State<LessonHistoryScreen> {
  List<dynamic> _lessonProgress = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLessonProgress();
  }

  Future<void> _loadLessonProgress() async {
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
        final data = json.decode(response.body);
        setState(() {
          _lessonProgress = data;
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al cargar el historial de lecciones'),
            ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de Lecciones')),
      body: RefreshIndicator(
        onRefresh: _loadLessonProgress,
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _lessonProgress.isEmpty
                ? const Center(
                  child: Text('No has completado ninguna lección aún.'),
                )
                : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _lessonProgress.length,
                  itemBuilder: (context, index) {
                    final progress = _lessonProgress[index];
                    final lesson = progress['lesson'];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    lesson['title'] ?? 'Lección sin título',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (progress['score'] != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          progress['completed']
                                              ? Colors.green.withOpacity(0.2)
                                              : Colors.grey.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${progress['score'].round()}%',
                                      style: TextStyle(
                                        color:
                                            progress['completed']
                                                ? Colors.green
                                                : Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Nivel: ${lesson['level'] ?? 'N/A'}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tipo: ${_getLessonTypeLabel(lesson['lesson_type'] ?? '')}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  progress['completed']
                                      ? Icons.check_circle
                                      : Icons.hourglass_empty,
                                  color:
                                      progress['completed']
                                          ? Colors.green
                                          : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  progress['completed']
                                      ? 'Completada'
                                      : 'Pendiente',
                                  style: TextStyle(
                                    color:
                                        progress['completed']
                                            ? Colors.green
                                            : Colors.grey,
                                  ),
                                ),
                                if (progress['completed_at'] != null) ...[
                                  const SizedBox(width: 16),
                                  Icon(
                                    Icons.access_time,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatDate(progress['completed_at']),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      ),
    );
  }

  String _getLessonTypeLabel(String type) {
    switch (type) {
      case 'vocabulary':
        return 'Vocabulario';
      case 'grammar':
        return 'Gramática';
      case 'conversation':
        return 'Conversación';
      case 'pronunciation':
        return 'Pronunciación';
      case 'shadowing':
        return 'Shadowing';
      default:
        return type;
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}
