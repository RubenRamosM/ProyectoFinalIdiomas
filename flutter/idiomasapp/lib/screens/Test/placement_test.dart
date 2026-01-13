import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../services/api.dart';
import '../../../services/user_service.dart';

enum QType { choice, speak }

class Q {
  final int? id;
  final QType type;
  final String text;
  final List<String>? options; // choice
  final int?
  correctIndex; // choice (puede venir null si backend oculta is_correct)
  final List<String>? expected; // speak (frases válidas en target)

  Q.choice({
    this.id,
    required this.text,
    required List<String> options,
    int? correctIndex,
  }) : type = QType.choice,
       options = options,
       correctIndex = correctIndex,
       expected = null;

  Q.speak({this.id, required this.text, required List<String> expected})
    : type = QType.speak,
      expected = expected,
      options = null,
      correctIndex = null;
}

class PlacementTestScreen extends StatefulWidget {
  /// Idioma objetivo (ISO corto): 'en', 'es', 'pt', 'fr', etc.
  final String targetLang;

  /// (Opcional) forzar idioma nativo
  final String? nativeLang;

  const PlacementTestScreen({
    super.key,
    required this.targetLang,
    this.nativeLang,
  });

  @override
  State<PlacementTestScreen> createState() => _PlacementTestScreenState();
}

class _PlacementTestScreenState extends State<PlacementTestScreen> {
  List<Q> _questions = [];
  int _index = 0;

  int? _selected; // choice state
  final List<Map<String, dynamic>?> _userAnswers = [];

  late stt.SpeechToText _stt;
  bool _sttAvailable = false;
  bool _listening = false;
  String _heard = '';

  bool _busy = false;

  bool get _canGradeChoiceLocally {
    final q = _questions[_index];
    return q.type == QType.choice && q.correctIndex != null;
  }

  @override
  void initState() {
    super.initState();
    _initSTT();
    _loadQuestions();
  }

  Future<void> _initSTT() async {
    _stt = stt.SpeechToText();
    _sttAvailable = await _stt.initialize(onStatus: (_) {}, onError: (_) {});
    if (mounted) setState(() {});
  }

  String _localeForTarget(String lang) {
    switch (lang.toLowerCase()) {
      case 'es':
        return 'es_ES';
      case 'pt':
      case 'pt-br':
        return 'pt_BR';
      case 'fr':
        return 'fr_FR';
      case 'en':
      default:
        return 'en_US';
    }
  }

  Future<void> _loadQuestions() async {
    setState(() => _busy = true);
    try {
      // 1) native / target
      String target = widget.targetLang;
      String? native =
          widget.nativeLang ??
          await _safeGetNativeFromUser() ??
          _guessDeviceLang();
      // normalizaciones
      target = target.toLowerCase();
      native = (native ?? 'es').toLowerCase();
      if (target.startsWith('pt')) target = 'pt';
      if (native.startsWith('pt')) native = 'pt';

      // 2) petición (DEBUG print!)
      final url = 'test/placement/?native=$native&target=$target';
      debugPrint('Placement URL => $url');
      final resp = await Api.dio.get(url);

      if (resp.statusCode == 200 && resp.data is List) {
        final arr = resp.data as List;
        final List<Q> loaded = [];
        for (final it in arr) {
          final m = (it as Map).cast<String, dynamic>();
          final qtype = (m['qtype'] as String? ?? 'choice').toLowerCase();
          final qtext = (m['question'] ?? '').toString();

          if (qtype == 'choice') {
            final opts =
                (m['options'] as List<dynamic>? ?? [])
                    .map<Map<String, dynamic>>(
                      (o) => (o as Map).cast<String, dynamic>(),
                    )
                    .toList();
            final options =
                opts.map((o) => (o['text'] ?? '').toString()).toList();
            int? correctIndex;
            for (int i = 0; i < opts.length; i++) {
              final v = opts[i]['is_correct'];
              if (v is bool && v) {
                correctIndex = i;
                break;
              }
            }
            loaded.add(
              Q.choice(
                id: m['id'] as int?,
                text: qtext,
                options: options,
                correctIndex: correctIndex,
              ),
            );
          } else {
            final expected =
                (m['options'] as List<dynamic>? ?? [])
                    .map((o) => ((o as Map)['text'] ?? '').toString())
                    .where((s) => s.trim().isNotEmpty)
                    .toList();
            loaded.add(
              Q.speak(
                id: m['id'] as int?,
                text: qtext,
                expected: expected.isNotEmpty ? expected : [''],
              ),
            );
          }
        }

        if (loaded.isEmpty) {
          _snack('No hay preguntas disponibles.');
        } else {
          _questions = loaded;
          _userAnswers
            ..clear()
            ..addAll(
              List<Map<String, dynamic>?>.filled(_questions.length, null),
            );
          if (mounted) setState(() {});
        }
      } else {
        _snack('Error al cargar preguntas: ${resp.statusCode}');
      }
    } catch (e) {
      _snack('Error de red: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _safeGetNativeFromUser() async {
    try {
      final me = await UserService.me();
      final n = (me['native_language'] ?? '').toString();
      return n.isEmpty ? null : n;
    } catch (_) {
      return null;
    }
  }

  String _guessDeviceLang() {
    final code =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode
            .toLowerCase();
    switch (code) {
      case 'es':
      case 'en':
      case 'pt':
      case 'fr':
        return code;
      default:
        return 'es';
    }
  }

  // ---- Voz ----
  Future<void> _toggleListen() async {
    if (!_sttAvailable) {
      _snack('Reconocimiento de voz no disponible.');
      return;
    }
    if (_listening) {
      await _stt.stop();
      setState(() => _listening = false);
      return;
    }
    setState(() {
      _heard = '';
      _listening = true;
    });
    await _stt.listen(
      localeId: _localeForTarget(widget.targetLang),
      onResult: (res) => setState(() => _heard = res.recognizedWords),
      listenFor: const Duration(seconds: 6),
      pauseFor: const Duration(seconds: 2),
      partialResults: true,
    );
  }

  bool _validateSpeak(Q q) {
    final said = _heard.trim().toLowerCase();
    if (said.isEmpty) return false;
    final expected = q.expected!.map((e) => e.toLowerCase().trim());
    return expected.contains(said);
  }

  // ---- Feedback ----
  Future<void> _showFeedback({
    required bool correct,
    String? correctText,
  }) async {
    final anim = Lottie.asset(
      correct ? 'assets/anim_correct.json' : 'assets/anim_wrong.json',
      repeat: false,
      height: 140,
    );
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => AlertDialog(
            title: Text(correct ? '¡Correcto!' : 'Revisión'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                anim,
                if (!correct && correctText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Ejemplo de respuesta: $correctText',
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Continuar'),
              ),
            ],
          ),
    );
  }

  // ---- Flujo ----
  Future<void> _next() async {
    final q = _questions[_index];

    if (q.type == QType.choice) {
      if (_selected == null) return;

      if (_canGradeChoiceLocally) {
        final isOk = _selected == q.correctIndex;
        await _showFeedback(
          correct: isOk,
          correctText: isOk ? null : q.options![q.correctIndex!],
        );
      }
      _userAnswers[_index] = {'question_id': q.id, 'selected_index': _selected};
      setState(() => _selected = null);
    } else {
      if (_listening) {
        await _stt.stop();
        setState(() => _listening = false);
      }
      final ok = _validateSpeak(q);
      await _showFeedback(
        correct: ok,
        correctText:
            q.expected!.isNotEmpty ? '“${q.expected!.join('” / “')}”' : null,
      );
      _userAnswers[_index] = {'question_id': q.id, 'spoken_text': _heard};
    }

    if (!mounted) return;
    if (_index < _questions.length - 1) {
      setState(() => _index++);
    } else {
      await _finish();
    }
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    try {
      final payload = {
        'answers': _userAnswers.where((e) => e != null).toList(),
      };
      final resp = await Api.dio.post('test/placement/submit/', data: payload);

      String level = 'A1';
      if (resp.statusCode == 200 && resp.data is Map) {
        final lvl = (resp.data as Map)['level'] as String?;
        if (lvl != null) {
          level = lvl;
          await Api.storage.write(key: 'placement_level', value: lvl);
          try {
            await UserService.updateMe(level: lvl);
          } catch (_) {}
        }
      }

      if (!mounted) return;
      await showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: const Text('Resultado del test'),
              content: Text('Tu nivel estimado es: $level'),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack('No se pudo finalizar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final loading = _busy && _questions.isEmpty;
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Test de nivel')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Test de nivel')),
        body: const Center(
          child: Text(
            'No hay preguntas disponibles.\nIntenta más tarde.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final q = _questions[_index];
    final progress = (_index + 1) / _questions.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Test de nivel')),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(value: progress),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Pregunta ${_index + 1} de ${_questions.length}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                q.text,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child:
                    q.type == QType.choice
                        ? _ChoiceWidget(
                          options: q.options ?? const [],
                          groupValue: _selected,
                          onChange: (v) => setState(() => _selected = v),
                        )
                        : _SpeakWidget(
                          heard: _heard,
                          listening: _listening,
                          sttAvailable: _sttAvailable,
                          onToggleListen: _toggleListen,
                        ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: FilledButton(
                onPressed:
                    _busy
                        ? null
                        : (q.type == QType.choice
                            ? (_selected == null ? null : _next)
                            : _next),
                child:
                    _busy
                        ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Text(
                          _index < _questions.length - 1
                              ? 'Siguiente'
                              : 'Finalizar',
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceWidget extends StatelessWidget {
  final List<String> options;
  final int? groupValue;
  final ValueChanged<int?> onChange;
  const _ChoiceWidget({
    required this.options,
    required this.groupValue,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const Center(child: Text('Sin opciones'));
    return ListView.separated(
      itemCount: options.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder:
          (_, i) => RadioListTile<int>(
            value: i,
            groupValue: groupValue,
            onChanged: onChange,
            title: Text(options[i]),
          ),
    );
  }
}

class _SpeakWidget extends StatelessWidget {
  final String heard;
  final bool listening;
  final bool sttAvailable;
  final VoidCallback onToggleListen;

  const _SpeakWidget({
    required this.heard,
    required this.listening,
    required this.sttAvailable,
    required this.onToggleListen,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(listening ? Icons.mic : Icons.mic_none, size: 64),
        const SizedBox(height: 8),
        Text(
          sttAvailable
              ? (listening ? 'Escuchando...' : 'Pulsa el micrófono y habla')
              : 'Voz no disponible en este dispositivo',
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: sttAvailable ? onToggleListen : null,
          child: Text(listening ? 'Detener' : 'Empezar a hablar'),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Reconocido: ${heard.isEmpty ? '—' : heard}'),
        ),
      ],
    );
  }
}
