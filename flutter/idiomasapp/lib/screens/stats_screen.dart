import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/stats_models.dart';
import '../services/api.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  UserStats? _userStats;
  List<UserProgressRecord> _progressRecords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await Api.getToken();
      
      // Cargar estadísticas generales del usuario
      final statsResponse = await http.get(
        Uri.parse('${Api.baseUrl}users/stats/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (statsResponse.statusCode == 200) {
        final statsData = json.decode(statsResponse.body);
        final userStats = UserStats.fromJson(statsData);
        
        // Cargar historial de progreso
        final progressResponse = await http.get(
          Uri.parse('${Api.baseUrl}users/progress/'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        if (progressResponse.statusCode == 200) {
          final progressData = json.decode(progressResponse.body) as List;
          final progressList = progressData
              .map((json) => UserProgressRecord.fromJson(json))
              .toList();
          
          setState(() {
            _userStats = userStats;
            _progressRecords = progressList;
            _isLoading = false;
          });
        } else {
          setState(() {
            _userStats = userStats;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al cargar las estadísticas')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de conexión: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mis Estadísticas'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_userStats == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mis Estadísticas'),
        ),
        body: const Center(
          child: Text('No se pudieron cargar las estadísticas'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Estadísticas'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tarjeta de resumen general
              _buildSummaryCard(),
              const SizedBox(height: 16),
              
              // Estadísticas detalladas
              _buildDetailedStatsCard(),
              const SizedBox(height: 16),
              
              // Gráfico de progreso (simplificado)
              _buildProgressChart(),
              const SizedBox(height: 16),
              
              // Últimos registros de progreso
              _buildRecentProgress(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Resumen General',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.star,
                  value: _userStats!.points.toString(),
                  label: 'Puntos',
                  color: Colors.orange,
                ),
                _buildStatItem(
                  icon: Icons.local_fire_department,
                  value: _userStats!.streakCount.toString(),
                  label: 'Racha',
                  color: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.menu_book,
                  value: _userStats!.totalLessonsCompleted.toString(),
                  label: 'Lecciones',
                  color: Colors.blue,
                ),
                _buildStatItem(
                  icon: Icons.check_circle,
                  value: _userStats!.totalExercisesCompleted.toString(),
                  label: 'Ejercicios',
                  color: Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 36, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedStatsCard() {
    final learningStats = _userStats!.learningStats;
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Estadísticas de Aprendizaje',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (learningStats != null) ...[
              _buildDetailRow('Vocabulario aprendido', learningStats.vocabularyLearned.toString()),
              const Divider(height: 24),
              _buildDetailRow('Temas de gramática', learningStats.grammarTopicsCompleted.toString()),
              const Divider(height: 24),
              _buildDetailRow('Tiempo de escucha', '${learningStats.listeningTime} min'),
              const Divider(height: 24),
              _buildDetailRow('Práctica de habla', '${learningStats.speakingPractice} min'),
              const Divider(height: 24),
              _buildDetailRow('Precisión promedio', '${(learningStats.accuracyRate * 100).round()}%'),
            ] else ...[
              const Text('No hay estadísticas detalladas disponibles aún.'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressChart() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Progreso Reciente',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_progressRecords.isNotEmpty) ...[
              Container(
                height: 150,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _progressRecords.length,
                  itemBuilder: (context, index) {
                    final record = _progressRecords[index];
                    return Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 16),
                      child: Column(
                        children: [
                          Text(
                            _formatDate(record.date),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 80,
                            width: 40,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Center(
                              child: Text(
                                record.lessonsCompleted.toString(),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${record.pointsEarned} pts',
                            style: const TextStyle(
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              const Text('No hay datos de progreso reciente.'),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    // Convierte "YYYY-MM-DD" a "DD/MM"
    final parts = dateString.split('-');
    if (parts.length >= 2) {
      return '${parts[2]}/${parts[1]}';
    }
    return dateString;
  }

  Widget _buildRecentProgress() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Últimas Sesiones',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_progressRecords.isNotEmpty) ...[
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _progressRecords.length > 5 ? 5 : _progressRecords.length,
                itemBuilder: (context, index) {
                  final record = _progressRecords[index];
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.timeline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(_formatDate(record.date)),
                    subtitle: Text(
                      '${record.lessonsCompleted} lecciones • ${record.pointsEarned} pts • ${record.timeSpent} min',
                    ),
                    trailing: Text(
                      '+${record.pointsEarned}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  );
                },
              ),
            ] else ...[
              const Text('No hay sesiones registradas aún.'),
            ],
          ],
        ),
      ),
    );
  }
}