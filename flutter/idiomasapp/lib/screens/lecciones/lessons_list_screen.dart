import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/api.dart';
import 'adaptive_lesson_screen.dart';

class LessonsListScreen extends StatefulWidget {
  const LessonsListScreen({super.key});

  @override
  State<LessonsListScreen> createState() => _LessonsListScreenState();
}

class _LessonsListScreenState extends State<LessonsListScreen> {
  List<Map<String, dynamic>> _lessons = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllLessons();
  }

  Future<void> _loadAllLessons() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await Api.getToken();
      final response = await http.get(
        Uri.parse('${Api.baseUrl}lessons/all-lessons/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final lessons =
            data.map((lesson) => lesson as Map<String, dynamic>).toList();
        setState(() {
          _lessons = lessons;
          _isLoading = false;
        });
        // Si hay lecciones, navegar automáticamente a la primera
        if (lessons.isNotEmpty && mounted) {
          Future.microtask(() => _startLesson(lessons.first));
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al cargar las lecciones')),
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

  void _startLesson(Map<String, dynamic> lesson) async {
    // Navegar a la pantalla de lección, pasando el ID de la lección
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdaptiveLessonScreen(lessonId: lesson['id']),
      ),
    );

    // Recargar las lecciones después de salir de la pantalla de lección
    _loadAllLessons();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis Lecciones')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _lessons.isEmpty
              ? const Center(
                child: Text(
                  'No hay lecciones disponibles para tu nivel',
                  style: TextStyle(fontSize: 16),
                ),
              )
              : RefreshIndicator(
                onRefresh: _loadAllLessons,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _lessons.length,
                  itemBuilder: (context, index) {
                    final lesson = _lessons[index];
                    final progress =
                        lesson['progress'] as Map<String, dynamic>?;
                    final isCompleted = progress?['completed'] ?? false;
                    final score = progress?['score'];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 3,
                      child: InkWell(
                        onTap: () => _startLesson(lesson),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
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
                                  if (isCompleted)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.check_circle,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${score?.round() ?? 0}%',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                lesson['content'] ?? '',
                                style: const TextStyle(fontSize: 14),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    Icons.school,
                                    size: 16,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Nivel: ${lesson['level']}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(
                                    Icons.book,
                                    size: 16,
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    lesson['lesson_type'] ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.secondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _startLesson(lesson),
                                      icon: Icon(
                                        isCompleted
                                            ? Icons.replay
                                            : Icons.play_arrow,
                                      ),
                                      label: Text(
                                        isCompleted
                                            ? 'Repetir Lección'
                                            : 'Comenzar Lección',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
    );
  }
}
