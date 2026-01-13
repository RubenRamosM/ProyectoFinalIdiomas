import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api.dart';
import '../services/user_service.dart';
import 'Test/placement_test.dart';
import 'profile_screen.dart';
import 'live_translator_screen.dart';
import 'stats_screen.dart';
import 'lecciones/lesson_history_screen.dart';
import 'lecciones/lessons_history_screen.dart';
import 'support/help_support_screen.dart';
import 'lessons_by_level_screen.dart';
import 'tutor/tutor_chat_screen.dart';
import 'achievements_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Estado
  String _targetLang = 'en';
  int _streak = 1;
  int _tabIndex = 0;

  // Storage
  final FlutterSecureStorage _storage = Api.storage;

  @override
  void initState() {
    super.initState();
    _initFromStorage();
  }

  Future<void> _initFromStorage() async {
    String lang = 'en';

    // 1) Intenta leer del backend
    try {
      final me = await UserService.me();
      final tl = me["target_language"];
      if (tl is String && tl.isNotEmpty) {
        lang = tl;
        await _storage.write(key: 'target_language', value: tl);
      }
    } catch (_) {
      // 2) Fallback a storage local si backend no respondió
      lang = await _storage.read(key: 'target_language') ?? 'en';
    }

    // ---- Racha ----
    final lastOpen = await _storage.read(key: 'streak_last_open');
    final countStr = await _storage.read(key: 'streak_count');
    int count = int.tryParse(countStr ?? '0') ?? 0;

    final today = DateTime.now();
    final todayKey = _dayKey(today);

    if (lastOpen == null) {
      count = 1;
      await _storage.write(key: 'streak_last_open', value: todayKey);
      await _storage.write(key: 'streak_count', value: '$count');
    } else {
      if (lastOpen != todayKey) {
        final last = _parseDayKey(lastOpen);
        final diff = today.difference(last).inDays;
        if (diff == 1) {
          count = (count <= 0 ? 1 : count + 1);
        } else if (diff > 1) {
          count = 1;
        }
        await _storage.write(key: 'streak_last_open', value: todayKey);
        await _storage.write(key: 'streak_count', value: '$count');
      }
    }

    if (!mounted) return;
    setState(() {
      _targetLang = lang;
      _streak = count == 0 ? 1 : count;
    });

    // Mostrar el modal de placement siempre mientras el usuario
    // no haya hecho el test (es decir, mientras no exista
    // la clave `placement_level` en el storage).
    final placementLevel = await _storage.read(key: 'placement_level');
    if ((placementLevel == null || placementLevel.isEmpty) && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _promptPlacement());
    }
  }

  String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime _parseDayKey(String s) {
    final p = s.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  String _langName(String code) {
    switch (code) {
      case 'en':
        return 'Inglés';
      case 'pt':
        return 'Portugués';
      case 'fr':
        return 'Francés';
      case 'it':
        return 'Italiano';
      case 'de':
        return 'Alemán';
      default:
        return 'Idioma';
    }
  }

  String _flagForLang(String code) {
    switch (code) {
      case 'en':
        return '🇺🇸';
      case 'pt':
        return '🇧🇷';
      case 'fr':
        return '🇫🇷';
      case 'it':
        return '🇮🇹';
      case 'de':
        return '🇩🇪';
      default:
        return '🏳️';
    }
  }

  void _promptPlacement() async {
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.school,
                    color: Color(0xFF8B5CF6),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Test de nivel'),
              ],
            ),
            content: const Text(
              '¿Querés hacer un test rápido (5 preguntas) para estimar tu nivel?',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text('Luego', style: TextStyle(fontSize: 15)),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Empezar', style: TextStyle(fontSize: 15)),
              ),
            ],
          ),
    );

    await _storage.write(key: 'show_placement', value: '0');

    if (res == true && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlacementTestScreen(targetLang: _targetLang),
        ),
      );
      if (mounted) _initFromStorage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final langName = _langName(_targetLang);
    final flag = _flagForLang(_targetLang);

    // Gradiente vibrante y moderno
    final gradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF667eea), // Púrpura suave
        Color(0xFF764ba2), // Púrpura medio
        Color(0xFFf093fb), // Rosa suave
      ],
    );

    return Container(
      decoration: BoxDecoration(gradient: gradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _GlassAppBar(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(flag, style: const TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Aprendiendo',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black.withOpacity(0.5),
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            langName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      fit: FlexFit.loose,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _StreakPill(streak: _streak),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.02, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: IndexedStack(
              key: ValueKey(_tabIndex),
              index: _tabIndex,
              children: const [_HomeTab(), _ProfileTab(), _ChallengesTab()],
            ),
          ),
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _GlassShell(
            pad: const EdgeInsets.all(4),
            child: NavigationBar(
              height: 72,
              backgroundColor: Colors.transparent,
              elevation: 0,
              indicatorColor: const Color(0xFF8B5CF6).withOpacity(0.15),
              indicatorShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              selectedIndex: _tabIndex,
              onDestinationSelected: (i) => setState(() => _tabIndex = i),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined, size: 26),
                  selectedIcon: Icon(Icons.home_rounded, size: 26),
                  label: 'Inicio',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline, size: 26),
                  selectedIcon: Icon(Icons.person, size: 26),
                  label: 'Perfil',
                ),
                NavigationDestination(
                  icon: Icon(Icons.emoji_events_outlined, size: 26),
                  selectedIcon: Icon(Icons.emoji_events, size: 26),
                  label: 'Retos',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ======= Tabs =======

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      _FeatureCard(
        icon: Icons.library_books_rounded,
        title: 'Todas mis lecciones',
        subtitle: 'Ve todas las lecciones y tu progreso',
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
        onTap:
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LessonsByLevelScreen(),
              ),
            ),
      ),
      _FeatureCard(
        icon: Icons.translate_rounded,
        title: 'Traductor en línea',
        subtitle: 'Traduce texto en tiempo real o por voz (beta)',
        gradient: const LinearGradient(
          colors: [Color(0xFF30cfd0), Color(0xFF330867)],
        ),
        onTap:
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LiveTranslatorScreen(),
              ),
            ),
      ),
      _FeatureCard(
        icon: Icons.psychology_rounded,
        title: 'Tutor Inteligente',
        subtitle: 'Consulta con IA disponible 24/7 🤖',
        gradient: const LinearGradient(
          colors: [Color(0xFFf093fb), Color(0xFF4facfe)],
        ),
        onTap:
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TutorChatScreen()),
            ),
      ),
    ];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: cards.length,
      itemBuilder: (_, i) => cards[i],
      separatorBuilder: (_, __) => const SizedBox(height: 14),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      _ListTileCard(
        leadingIcon: Icons.person_rounded,
        title: 'Mi perfil',
        subtitle: 'Configuración y datos personales',
        color: const Color(0xFF8B5CF6),
        onTap:
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
      ),
      _ListTileCard(
        leadingIcon: Icons.history_edu_rounded,
        title: 'Historial de lecciones',
        subtitle: 'Revisa tus lecciones completadas',
        color: const Color(0xFF3B82F6),
        onTap:
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LessonsHistoryScreen(),
              ),
            ),
      ),
      _ListTileCard(
        leadingIcon: Icons.leaderboard_rounded,
        title: 'Estadísticas y progreso',
        subtitle: 'Visualiza tu desempeño y logros',
        color: const Color(0xFF10B981),
        onTap:
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const StatsScreen()),
            ),
      ),
      _ListTileCard(
        leadingIcon: Icons.history_rounded,
        title: 'Historial de lecciones (detalle)',
        subtitle: 'Revisa tus lecciones completadas',
        color: const Color(0xFFF59E0B),
        onTap:
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LessonHistoryScreen(),
              ),
            ),
      ),
      _ListTileCard(
        leadingIcon: Icons.emoji_events_rounded,
        title: 'Logros y medallas',
        subtitle: 'Mira tus recompensas',
        color: const Color(0xFFEF4444),
        onTap:
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AchievementsScreen(),
              ),
            ),
      ),
      _ListTileCard(
        leadingIcon: Icons.help_outline_rounded,
        title: 'Ayuda y Soporte',
        subtitle: 'FAQs, contacto y tickets de soporte',
        color: const Color(0xFF06B6D4),
        onTap:
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const HelpSupportScreen(),
              ),
            ),
      ),
      _ListTileCard(
        leadingIcon: Icons.settings_rounded,
        title: 'Ajustes',
        subtitle: 'Preferencias y configuración',
        color: const Color(0xFF6B7280),
        onTap: () {},
      ),
    ];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: items.length,
      itemBuilder: (_, i) => items[i],
      separatorBuilder: (_, __) => const SizedBox(height: 12),
    );
  }
}

class _ChallengesTab extends StatelessWidget {
  const _ChallengesTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      child: Column(
        children: [
          _GlassShell(
            child: Container(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFA500).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.emoji_events,
                      size: 56,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Desafíos y logros',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Completa retos semanales, gana medallas y mantén tu racha.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.black.withOpacity(0.6),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {},
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.sports_score, size: 22),
                      label: const Text(
                        'Ver retos disponibles',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ======= Componentes reutilizables =======

class _GlassAppBar extends StatelessWidget {
  const _GlassAppBar({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _GlassShell(
      radius: 24,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: child,
      ),
    );
  }
}

class _GlassShell extends StatelessWidget {
  const _GlassShell({required this.child, this.radius = 24, this.pad});

  final Widget child;
  final double radius;
  final EdgeInsets? pad;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        padding: pad,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              blurRadius: 30,
              spreadRadius: -8,
              offset: const Offset(0, 15),
              color: Colors.black.withOpacity(0.15),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _StreakPill extends StatelessWidget {
  const _StreakPill({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF6B6B).withOpacity(0.2),
            const Color(0xFFFFE66D).withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF6B6B).withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B6B).withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 6),
          Text(
            '$streak',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFFFF6B6B),
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            'días',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: const Color(0xFFFF6B6B).withOpacity(0.8),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _GlassShell(
      radius: 20,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: Colors.white.withOpacity(0.1),
          highlightColor: Colors.white.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: gradient.colors.first.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black.withOpacity(0.55),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ListTileCard extends StatelessWidget {
  const _ListTileCard({
    required this.leadingIcon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData leadingIcon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _GlassShell(
      radius: 18,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          splashColor: color.withOpacity(0.1),
          highlightColor: color.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withOpacity(0.2), width: 1),
                  ),
                  child: Icon(leadingIcon, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black.withOpacity(0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
