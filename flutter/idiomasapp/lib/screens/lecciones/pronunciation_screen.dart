import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../services/api.dart';

class PronunciationScreen extends StatefulWidget {
  final String? expectedText;

  const PronunciationScreen({super.key, this.expectedText});

  @override
  State<PronunciationScreen> createState() => _PronunciationScreenState();
}

class _PronunciationScreenState extends State<PronunciationScreen> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterTts _tts = FlutterTts();

  bool _isRecording = false;
  bool _isSpeaking = false;
  bool _isUploading = false;

  String? _audioPath;
  double? _score;
  String? _feedback;
  String? _transcription;
  bool _isCorrect = false;

  // Visual de grabación
  final List<double> _amps = [];
  StreamSubscription? _recSub;
  int _recordSecs = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initRecorder();
    _initTTS();
  }

  @override
  void dispose() {
    _recSub?.cancel();
    _timer?.cancel();
    _recorder.closeRecorder();
    _tts.stop();
    super.dispose();
  }

  Future<void> _initRecorder() async {
    await _recorder.openRecorder();
    // actualización fluida para la onda
    await _recorder.setSubscriptionDuration(const Duration(milliseconds: 60));
  }

  Future<void> _initTTS() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.8); // un poco más lento que normal
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setStartHandler(() => setState(() => _isSpeaking = true));
    _tts.setCompletionHandler(() => setState(() => _isSpeaking = false));
    _tts.setErrorHandler((_) => setState(() => _isSpeaking = false));
  }

  Future<void> _speak() async {
    final txt = (widget.expectedText ?? '').trim();
    if (txt.isEmpty) return;
    await _tts.stop();
    await _tts.speak(txt);
  }

  Future<void> _stopSpeak() async {
    await _tts.stop();
    setState(() => _isSpeaking = false);
  }

  Future<void> _startRecording() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permiso de micrófono denegado')),
      );
      return;
    }

    final dir = await getTemporaryDirectory();
    _audioPath =
        '${dir.path}/pron_${DateTime.now().millisecondsSinceEpoch}.m4a';

    // Resetea visual + estado
    _amps.clear();
    _recordSecs = 0;
    _timer?.cancel();
    _recSub?.cancel();

    // Suscripción a progreso para ondas
    _recSub = _recorder.onProgress?.listen((e) {
      double amp = 0.0;
      try {
        final dyn = e as dynamic;
        final db = dyn.decibels as double?;
        if (db != null && db.isFinite) {
          // mapear [-60..0] a [0..1]
          amp = ((db + 60) / 60).clamp(0.0, 1.0);
        } else {
          amp = 0.15 + (math.Random().nextDouble() * 0.1);
        }
      } catch (_) {
        amp = 0.0;
      }
      if (!mounted) return;
      setState(() {
        _amps.add(amp);
        if (_amps.length > 64) _amps.removeAt(0);
      });
    });

    // Timer visible
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _recordSecs++);
    });

    // Iniciar grabación como .m4a (AAC/MP4) — portable
    await _recorder.startRecorder(
      toFile: _audioPath!,
      codec: Codec.aacMP4, // .m4a
      sampleRate: 44100,
      bitRate: 64000,
      numChannels: 1,
    );

    setState(() {
      _isRecording = true;
      _score = null;
      _feedback = null;
      _transcription = null;
    });
  }

  Future<void> _stopRecording() async {
    try {
      await _recorder.stopRecorder();
    } finally {
      _recSub?.cancel();
      _recSub = null;
      _timer?.cancel();
      setState(() => _isRecording = false);
    }

    if (_audioPath != null) {
      await _sendAudioForFeedback();
    }
  }

  Future<void> _sendAudioForFeedback() async {
    final p = _audioPath;
    if (p == null) return;

    final f = File(p);
    if (!await f.exists()) return;

    setState(() => _isUploading = true);
    try {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('${Api.baseUrl}lessons/pronunciation-feedback/'),
      );

      // Auth
      final token = await Api.getToken();
      if (token != null) {
        req.headers['Authorization'] = 'Bearer $token';
      }

      // Archivo (audio/mp4 para .m4a)
      req.files.add(
        await http.MultipartFile.fromPath(
          'file',
          p,
          filename: 'pronunciation.m4a',
          contentType: MediaType('audio', 'mp4'),
        ),
      );

      // Texto esperado
      final exp = (widget.expectedText ?? '').trim();
      if (exp.isNotEmpty) req.fields['expected_text'] = exp;

      final resp = await req.send();
      final body = await resp.stream.bytesToString();

      Map<String, dynamic> data = {};
      try {
        data = json.decode(body) as Map<String, dynamic>;
      } catch (_) {
        // Si no es JSON, lo muestro tal cual abajo
      }

      if (resp.statusCode == 200) {
        setState(() {
          _score = (data['score'] as num?)?.toDouble();
          _feedback = data['feedback'] as String?;
          _transcription = data['transcription'] as String?;
          _isCorrect = (data['is_correct'] as bool?) ?? false;
        });

        await _showResultSheet(
          score: _score?.round() ?? 0,
          feedback: _feedback ?? 'OK',
          transcription: _transcription ?? '',
        );
      } else {
        final serverMsg = data['error']?.toString().trim();
        final detail = data['whisper_error']?.toString().trim();

        final pretty = [
          if (serverMsg != null && serverMsg.isNotEmpty) serverMsg,
          if (detail != null && detail.isNotEmpty) 'Detalle: $detail',
          if (serverMsg == null && body.isNotEmpty) body,
          if ((serverMsg == null || serverMsg.isEmpty) && body.isEmpty)
            'Error $resp.statusCode al procesar el audio.',
        ].join('\n');

        await _showErrorSheet(pretty);
      }
    } catch (e) {
      await _showErrorSheet('Error de conexión: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _showResultSheet({
    required int score,
    required String feedback,
    required String transcription,
  }) async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.graphic_eq),
                  const SizedBox(width: 8),
                  Text(
                    'Resultado de pronunciación',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (score / 100).clamp(0.0, 1.0),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$score',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(feedback, style: Theme.of(ctx).textTheme.bodyMedium),
              const SizedBox(height: 12),
              Text('Transcripción:', style: Theme.of(ctx).textTheme.labelLarge),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  transcription.isEmpty ? '— (no se obtuvo)' : transcription,
                  style: Theme.of(
                    ctx,
                  ).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Intentar de nuevo'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pop(_isCorrect);
                    },
                    child: const Text('Continuar'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showErrorSheet(String msg) async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (ctx) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.settings_suggest),
                    SizedBox(width: 8),
                    Text('No se pudo procesar el audio'),
                  ],
                ),
                const SizedBox(height: 12),
                Text(msg, style: Theme.of(ctx).textTheme.bodyMedium),
                const SizedBox(height: 12),
                Text(
                  'Revisa que el servidor tenga FFmpeg en PATH y Whisper instalado.',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Intentar de nuevo'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(
                          context,
                        ).pop(true); // continuar de todos modos
                      },
                      child: const Text('Continuar de todos modos'),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  String _fmt(int totalSecs) {
    final m = (totalSecs ~/ 60).toString().padLeft(2, '0');
    final s = (totalSecs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final expected = widget.expectedText ?? 'Hello, world!';

    return Scaffold(
      appBar: AppBar(title: const Text('Práctica de Pronunciación')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                'Presiona el botón y di la frase:',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                expected,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Escuchar
              ElevatedButton.icon(
                onPressed: _isSpeaking ? _stopSpeak : _speak,
                icon: Icon(_isSpeaking ? Icons.stop : Icons.volume_up),
                label: Text(_isSpeaking ? 'Detener Audio' : 'Escuchar Frase'),
              ),

              const SizedBox(height: 28),

              // Barra de grabación tipo WhatsApp
              if (_isRecording)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.fiber_manual_record, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(
                        'Grabando • ${_fmt(_recordSecs)}',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 28,
                          child: CustomPaint(
                            painter: _MiniBarsPainter(
                              List.of(_amps),
                              color: Colors.redAccent,
                            ),
                            child: Container(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Detener',
                        icon: const Icon(Icons.stop, color: Colors.red),
                        onPressed: _stopRecording,
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              // Ondas generales (si quieres mantener visible siempre)
              SizedBox(
                height: 56,
                width: double.infinity,
                child: CustomPaint(
                  painter: _MiniBarsPainter(List.of(_amps)),
                  child: Container(),
                ),
              ),

              const SizedBox(height: 16),

              // Botón mic
              FloatingActionButton(
                onPressed: _isRecording ? _stopRecording : _startRecording,
                backgroundColor:
                    _isRecording
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                child: Icon(
                  _isRecording ? Icons.stop : Icons.mic,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                _isRecording
                    ? 'Grabando...'
                    : (_isUploading ? 'Enviando...' : 'Presiona para grabar'),
                style: TextStyle(
                  fontSize: 16,
                  color:
                      _isRecording
                          ? Theme.of(context).colorScheme.error
                          : (_isUploading
                              ? Theme.of(context).colorScheme.primary
                              : null),
                ),
              ),

              const SizedBox(height: 24),

              // Resumen rápido en pantalla
              const Text('Puntuación:', style: TextStyle(fontSize: 18)),
              Text(
                _score != null ? '${_score!.round()}%' : '-',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text('Feedback:', style: TextStyle(fontSize: 18)),
              Text(_feedback ?? '-', textAlign: TextAlign.center),
              if (_transcription != null && _transcription!.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Transcripción:', style: TextStyle(fontSize: 18)),
                Text(_transcription!, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/* ====== Mini barras (waveform compacto) ====== */
class _MiniBarsPainter extends CustomPainter {
  final List<double> amps;
  final Color color;
  _MiniBarsPainter(this.amps, {this.color = Colors.blueAccent});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withOpacity(0.9);
    if (amps.isEmpty) return;

    const int bands = 7;
    final spacing = 6.0;
    final barW = (size.width - (bands - 1) * spacing) / bands;
    final n = amps.length;

    for (int i = 0; i < bands; i++) {
      final start = ((i / bands) * n).floor();
      final end = (((i + 1) / bands) * n).floor();
      double avg = 0.0;
      if (end > start && n > 0) {
        final slice = amps.sublist(start, end);
        avg = slice.reduce((a, b) => a + b) / slice.length;
      } else if (n > 0) {
        avg = amps.last;
      }
      final shaped = avg * (0.6 + 0.4 * (1.0 - (i / bands)));
      final h = shaped.clamp(0.0, 1.0) * size.height;
      final x = i * (barW + spacing);
      final rect = Rect.fromLTWH(x, (size.height - h) / 2, barW, h);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniBarsPainter old) {
    if (old.amps.length != amps.length) return true;
    for (int i = 0; i < amps.length; i++) {
      if (old.amps[i] != amps[i]) return true;
    }
    return false;
  }
}
