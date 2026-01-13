import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api.dart';
import 'lesson_exercises_screen.dart';

class LessonsByLevelScreen extends StatefulWidget {
  const LessonsByLevelScreen({super.key});

  @override
  State<LessonsByLevelScreen> createState() => _LessonsByLevelScreenState();
}

class _LessonsByLevelScreenState extends State<LessonsByLevelScreen> {
  late Future<List<_Lesson>> _future;
  String _query = '';
  String _typeFilter =
      'all'; // vocabulary | grammar | conversation | pronunciation | shadowing | all
  final _searchCtrl = TextEditingController();
  final _expansionState = <String, bool>{}; // nivel -> abierto/cerrado

  @override
  void initState() {
    super.initState();
    _future = _fetchLessons();
  }

  Future<List<_Lesson>> _fetchLessons() async {
    final token = await Api.getToken();
    final response = await http.get(
      Uri.parse('${Api.baseUrl}lessons/all-lessons/?ordering=sequence'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;
      final items =
          data.map((e) => _Lesson.fromJson(e as Map<String, dynamic>)).toList();
      for (final lvl in items.map((e) => e.level).toSet()) {
        _expansionState.putIfAbsent(lvl, () => true);
      }
      return items;
    } else {
      throw Exception('Error al cargar las lecciones: ${response.statusCode}');
    }
  }

  Future<void> _refresh() async {
    setState(() => _future = _fetchLessons());
    await _future;
  }

  List<_Lesson> _applyFilters(List<_Lesson> all) {
    Iterable<_Lesson> filtered = all;

    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      filtered = filtered.where(
        (l) =>
            l.title.toLowerCase().contains(q) ||
            l.content.toLowerCase().contains(q),
      );
    }
    if (_typeFilter != 'all') {
      filtered = filtered.where((l) => l.lessonType == _typeFilter);
    }
    return filtered.toList()..sort((a, b) {
      // Agrupa naturalmente por nivel y respeta sequence/difficulty
      final c = a.level.compareTo(b.level);
      if (c != 0) return c;
      final s = a.sequence.compareTo(b.sequence);
      if (s != 0) return s;
      return a.difficulty.compareTo(b.difficulty);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Todas las lecciones')),
      body: SafeArea(
        child: Column(
          children: [
            // Barra de búsqueda + filtros
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: 'Buscar lección…',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _TypeFilterChip(
                    value: _typeFilter,
                    onChanged: (v) => setState(() => _typeFilter = v),
                  ),
                ],
              ),
            ),

            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: FutureBuilder<List<_Lesson>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const _SkeletonList();
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            'No se pudieron cargar las lecciones.\n${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    final all = snapshot.data ?? [];
                    final items = _applyFilters(all);
                    if (items.isEmpty) {
                      return const Center(child: Text('Sin resultados'));
                    }

                    // Agrupa por nivel
                    final byLevel = <String, List<_Lesson>>{};
                    for (final l in items) {
                      byLevel.putIfAbsent(l.level, () => []).add(l);
                    }
                    final levels = byLevel.keys.toList()..sort();

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: levels.length,
                      itemBuilder: (_, i) {
                        final lvl = levels[i];
                        final list = byLevel[lvl]!;
                        final open = _expansionState[lvl] ?? true;

                        return _LevelSection(
                          level: lvl,
                          open: open,
                          onToggle:
                              () => setState(() {
                                _expansionState[lvl] = !(open);
                              }),
                          children:
                              list.map((l) => _LessonTile(lesson: l)).toList(),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _refresh(),
        icon: const Icon(Icons.refresh),
        label: const Text('Actualizar'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

// ---------- UI widgets ----------

class _TypeFilterChip extends StatelessWidget {
  const _TypeFilterChip({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final types = const <String, String>{
      'all': 'Todos',
      'vocabulary': 'Vocabulario',
      'grammar': 'Gramática',
      'conversation': 'Conversación',
      'pronunciation': 'Pronunciación',
      'shadowing': 'Shadowing',
    };

    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onChanged,
      itemBuilder:
          (ctx) =>
              types.entries
                  .map(
                    (e) => PopupMenuItem<String>(
                      value: e.key,
                      child: Text(e.value),
                    ),
                  )
                  .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.4),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.filter_list),
            const SizedBox(width: 6),
            Text(types[value] ?? 'Filtro'),
            const Icon(Icons.keyboard_arrow_down_rounded),
          ],
        ),
      ),
    );
  }
}

class _LevelSection extends StatelessWidget {
  const _LevelSection({
    required this.level,
    required this.open,
    required this.onToggle,
    required this.children,
  });

  final String level;
  final bool open;
  final VoidCallback onToggle;
  final List<Widget> children;

  String get _label {
    switch (level) {
      case 'A1':
        return 'A1 · Principiante';
      case 'A2':
        return 'A2 · Básico';
      case 'B1':
        return 'B1 · Intermedio';
      case 'B2':
        return 'B2 · Intermedio alto';
      case 'C1':
        return 'C1 · Avanzado';
      case 'C2':
        return 'C2 · Experto';
      default:
        return level;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withOpacity(0.4),
          ),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.layers),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _label,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Icon(
                      open
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                    ),
                  ],
                ),
              ),
            ),
            if (open) const Divider(height: 1),
            if (open)
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: children.length,
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => children[i],
              ),
          ],
        ),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.lesson});
  final _Lesson lesson;

  IconData _iconForType(String t) {
    switch (t) {
      case 'vocabulary':
        return Icons.menu_book_rounded;
      case 'grammar':
        return Icons.rule_rounded;
      case 'conversation':
        return Icons.forum_rounded;
      case 'pronunciation':
        return Icons.record_voice_over_rounded;
      case 'shadowing':
        return Icons.hearing_rounded;
      default:
        return Icons.menu_book_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final done = lesson.completed ?? false;
    final isPassed = lesson.isPassed ?? false;
    final isAvailable = lesson.isAvailable ?? true;
    final correctExercises = lesson.correctExercises ?? 0;
    final totalExercises = lesson.totalExercises ?? 0;

    return Material(
      color: isAvailable ? cs.surface : cs.surface.withOpacity(0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap:
            isAvailable
                ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => LessonExercisesScreen(
                            lessonId: lesson.id,
                            lessonTitle: lesson.title,
                          ),
                    ),
                  );
                }
                : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color:
                      isAvailable
                          ? cs.primary.withOpacity(0.12)
                          : cs.outline.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isAvailable ? _iconForType(lesson.lessonType) : Icons.lock,
                  color: isAvailable ? cs.primary : cs.outline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${lesson.level} · ${_prettyType(lesson.lessonType)}"
                      " · Dif. ${lesson.difficulty} · Seq ${lesson.sequence}",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isAvailable ? null : cs.outline,
                      ),
                    ),
                    if (totalExercises > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        "Progreso: $correctExercises/$totalExercises ejercicios",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isPassed ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!isAvailable)
                const Icon(Icons.lock, color: Colors.grey)
              else if (isPassed)
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 6),
                    Text(
                      'Aprobada',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              else if (done)
                Row(
                  children: [
                    const Icon(Icons.pending, color: Colors.orange),
                    const SizedBox(width: 6),
                    Text(
                      'En progreso',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              else
                const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  String _prettyType(String t) {
    switch (t) {
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
        return t;
    }
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemBuilder:
          (_, __) => Container(
            height: 72,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: 8,
    );
  }
}

// ---------- DTO ----------

class _Lesson {
  final int id;
  final String title;
  final String content;
  final String level;
  final String lessonType;
  final String targetLanguage;
  final int sequence;
  final int difficulty;
  final bool? completed;
  final double? score;
  final bool? isPassed;
  final bool? isAvailable;
  final int? correctExercises;
  final int? totalExercises;

  _Lesson({
    required this.id,
    required this.title,
    required this.content,
    required this.level,
    required this.lessonType,
    required this.targetLanguage,
    required this.sequence,
    required this.difficulty,
    this.completed,
    this.score,
    this.isPassed,
    this.isAvailable,
    this.correctExercises,
    this.totalExercises,
  });

  factory _Lesson.fromJson(Map<String, dynamic> j) {
    final progress = j['progress'] as Map<String, dynamic>?;
    // Backend devuelve la localización en `localization` (ej: { title, content, target_language })
    final loc = j['localization'] as Map<String, dynamic>?;
    // Normalizaciones robustas para evitar TypeErrors cuando el backend
    // puede enviar valores como int o string.
    String _asString(dynamic v) => v == null ? '' : v.toString();

    final id =
        j['id'] is int ? j['id'] as int : int.tryParse(_asString(j['id'])) ?? 0;
    final title = _asString(j['title'] ?? loc?['title']);
    final content = _asString(j['content'] ?? loc?['content']);
    final level = _asString(j['level']);
    final lessonType = _asString(j['lesson_type']);
    final targetLanguage = _asString(
      j['target_language'] ?? loc?['target_language'],
    );

    int _asInt(dynamic v, {int fallback = 0}) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? fallback;
    }

    double? _asDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    bool? _asBool(dynamic v) {
      if (v == null) return null;
      if (v is bool) return v;
      final s = v.toString().toLowerCase();
      if (s == 'true' || s == '1') return true;
      if (s == 'false' || s == '0') return false;
      return null;
    }

    final seq = _asInt(j['sequence'], fallback: 0);
    final diff = _asInt(j['difficulty'], fallback: 1);
    final completedVal = _asBool(progress?['completed']);
    final scoreVal = _asDouble(progress?['score']);
    final isPassedVal = _asBool(progress?['is_passed']);
    final correctExercises =
        progress == null
            ? null
            : _asInt(progress['correct_exercises'], fallback: 0);
    final totalExercises =
        progress == null
            ? null
            : _asInt(progress['total_exercises'], fallback: 0);

    return _Lesson(
      id: id,
      title: title,
      content: content,
      level: level,
      lessonType: lessonType,
      targetLanguage: targetLanguage,
      sequence: seq,
      difficulty: diff,
      completed: completedVal,
      score: scoreVal,
      isPassed: isPassedVal,
      isAvailable:
          j['is_available'] is bool
              ? j['is_available'] as bool
              : (j['is_available'] == null
                  ? true
                  : (j['is_available'].toString().toLowerCase() == 'true')),
      correctExercises: correctExercises,
      totalExercises: totalExercises,
    );
  }
}
