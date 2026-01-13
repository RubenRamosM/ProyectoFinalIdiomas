import 'package:flutter/material.dart';

class Achievement {
  final int id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final bool isUnlocked;
  final DateTime? unlockedDate;

  Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.isUnlocked,
    this.unlockedDate,
  });
}

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  // Logros simulados - en el futuro se conectará con el backend
  final List<Achievement> _achievements = [
    Achievement(
      id: 1,
      name: 'Primera Lección',
      description: 'Completa tu primera lección',
      icon: Icons.school,
      color: Colors.blue,
      isUnlocked: true,
      unlockedDate: DateTime.now().subtract(const Duration(days: 5)),
    ),
    Achievement(
      id: 2,
      name: 'Racha de 3 días',
      description: 'Mantén una racha de 3 días consecutivos',
      icon: Icons.local_fire_department,
      color: Colors.orange,
      isUnlocked: true,
      unlockedDate: DateTime.now().subtract(const Duration(days: 2)),
    ),
    Achievement(
      id: 3,
      name: 'Pronunciación perfecta',
      description: 'Obtén 100 puntos en un ejercicio de pronunciación',
      icon: Icons.mic,
      color: Colors.purple,
      isUnlocked: false,
    ),
    Achievement(
      id: 4,
      name: 'Racha de 7 días',
      description: 'Mantén una racha de 7 días consecutivos',
      icon: Icons.whatshot,
      color: Colors.red,
      isUnlocked: false,
    ),
    Achievement(
      id: 5,
      name: '10 Lecciones',
      description: 'Completa 10 lecciones',
      icon: Icons.book,
      color: Colors.green,
      isUnlocked: false,
    ),
    Achievement(
      id: 6,
      name: 'Maestro del Matching',
      description: 'Completa 20 ejercicios de emparejamiento sin errores',
      icon: Icons.compare_arrows,
      color: Colors.teal,
      isUnlocked: false,
    ),
    Achievement(
      id: 7,
      name: 'Políglota',
      description: 'Aprende 3 idiomas diferentes',
      icon: Icons.language,
      color: Colors.indigo,
      isUnlocked: false,
    ),
    Achievement(
      id: 8,
      name: 'Vocabulario Rico',
      description: 'Aprende 100 palabras nuevas',
      icon: Icons.format_size,
      color: Colors.amber,
      isUnlocked: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final unlockedCount = _achievements.where((a) => a.isUnlocked).length;
    final totalCount = _achievements.length;
    final progress = unlockedCount / totalCount;

    return Scaffold(
      appBar: AppBar(title: const Text('Logros y Medallas'), elevation: 0),
      body: Column(
        children: [
          // Header con progreso
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withOpacity(0.7),
                ],
              ),
            ),
            child: Column(
              children: [
                const Icon(Icons.emoji_events, size: 64, color: Colors.white),
                const SizedBox(height: 12),
                Text(
                  '$unlockedCount de $totalCount logros',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(progress * 100).toInt()}% completado',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Lista de logros
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _achievements.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final achievement = _achievements[index];
                return _AchievementCard(achievement: achievement);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final Achievement achievement;

  const _AchievementCard({required this.achievement});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: achievement.isUnlocked ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color:
              achievement.isUnlocked
                  ? achievement.color.withOpacity(0.5)
                  : Colors.grey.withOpacity(0.2),
          width: 2,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icono
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    achievement.isUnlocked
                        ? achievement.color.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.1),
              ),
              child: Icon(
                achievement.icon,
                size: 32,
                color: achievement.isUnlocked ? achievement.color : Colors.grey,
              ),
            ),
            const SizedBox(width: 16),

            // Información
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          achievement.name,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color:
                                achievement.isUnlocked
                                    ? Colors.black87
                                    : Colors.grey,
                          ),
                        ),
                      ),
                      if (achievement.isUnlocked)
                        Icon(
                          Icons.check_circle,
                          color: achievement.color,
                          size: 24,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    achievement.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color:
                          achievement.isUnlocked ? Colors.black54 : Colors.grey,
                    ),
                  ),
                  if (achievement.isUnlocked &&
                      achievement.unlockedDate != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Desbloqueado ${_formatDate(achievement.unlockedDate!)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: achievement.color,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) return 'hoy';
    if (difference == 1) return 'ayer';
    if (difference < 7) return 'hace $difference días';
    if (difference < 30) return 'hace ${(difference / 7).floor()} semanas';
    return 'hace ${(difference / 30).floor()} meses';
  }
}
