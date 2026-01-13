import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/ws_translator.dart';
import '../services/api.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class LiveTranslatorScreen extends StatefulWidget {
  const LiveTranslatorScreen({super.key});

  @override
  State<LiveTranslatorScreen> createState() => _LiveTranslatorScreenState();
}

class _LiveTranslatorScreenState extends State<LiveTranslatorScreen> {
  late WsTranslator _ws;
  StreamSubscription<Map<String, dynamic>>? _sub;
  final List<String> _logs = [];
  final TextEditingController _textCtrl = TextEditingController();
  String _source = 'auto';
  String _target = 'en';
  bool _connected = false;
  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;
  // audio amplitude data for a simple VU meter
  final List<double> _amplitudes = [];
  StreamSubscription? _recorderSubscription;
  late FlutterTts _tts;
  // speech rate for TTS (1.0 = normal). Lower = slower, Higher = faster.
  double _speechRate = 0.9;

  @override
  void initState() {
    super.initState();

    String wsUrl = Api.baseUrl; // ej: http://192.168.1.5:8000/api
    // http(s) -> ws(s)
    if (wsUrl.startsWith('https://')) {
      wsUrl = wsUrl.replaceFirst('https://', 'wss://');
    } else if (wsUrl.startsWith('http://')) {
      wsUrl = wsUrl.replaceFirst('http://', 'ws://');
    }

    // quita trailing slash
    if (wsUrl.endsWith('/')) wsUrl = wsUrl.substring(0, wsUrl.length - 1);

    // si termina en /api, quítalo para no duplicar
    if (wsUrl.endsWith('/api')) {
      wsUrl = wsUrl.substring(0, wsUrl.length - 4); // quita "/api"
    }

    // ahora agrega la ruta correcta del socket
    wsUrl = '$wsUrl/api/ws/translator/';

    // (opcional) imprime para verificar
    debugPrint('WS URL => $wsUrl');
    print('WS URL => $wsUrl');

    _ws = WsTranslator(wsUrl);

    // Inicializar recorder (no bloqueante)
    _initRecorder();
    // Inicializar TTS
    _tts = FlutterTts();
    // use variable so it's easy to change programmatically or via UI
    try {
      _tts.setSpeechRate(_speechRate);
    } catch (_) {}
  }

  Future<void> _initRecorder() async {
    _recorder = FlutterSoundRecorder();
    try {
      await _recorder!.openRecorder();
      // solicitar permiso de microfono
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        // permiso denegado; dejar recorder cerrado
        await _recorder!.closeRecorder();
        _recorder = null;
      }
    } catch (_) {
      try {
        await _recorder?.closeRecorder();
      } catch (_) {}
      _recorder = null;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ws.close();
    _tts.stop();
    try {
      _tts.stop();
    } catch (_) {}
    try {
      _recorder?.closeRecorder();
    } catch (_) {}
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _speakText(String text, String langCode) async {
    if (text.isEmpty) return;
    // Map simple language codes to locales for flutter_tts
    String locale = 'en-US';
    switch (langCode) {
      case 'es':
        locale = 'es-ES';
        break;
      case 'pt':
        // Preferir pt-BR
        locale = 'pt-BR';
        break;
      case 'fr':
        locale = 'fr-FR';
        break;
      case 'de':
        locale = 'de-DE';
        break;
      case 'it':
        locale = 'it-IT';
        break;
      default:
        locale = 'en-US';
    }
    try {
      await _tts.setLanguage(locale);
    } catch (_) {}
    // apply selected speech rate before speaking
    try {
      await _tts.setSpeechRate(_speechRate);
    } catch (_) {}
    try {
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> _startRecording() async {
    if (_recorder == null) {
      setState(() => _logs.insert(0, 'Error: grabadora no inicializada'));
      return;
    }
    if (_isRecording) return;

    try {
      final tmpDir = await getTemporaryDirectory();
      // Use .m4a extension for AAC/MP4 format (better Windows compatibility)
      final path =
          '${tmpDir.path}/trans_${DateTime.now().millisecondsSinceEpoch}.m4a';

      // make progress updates smoother
      await _recorder!.setSubscriptionDuration(
        const Duration(milliseconds: 100),
      );

      // subscribe to progress BEFORE starting recorder
      _recorderSubscription = _recorder!.onProgress?.listen((event) {
        double amp = 0.0;
        try {
          final dyn = event as dynamic;
          final db = (dyn.decibels != null) ? (dyn.decibels as double) : null;
          if (db != null && db.isFinite) {
            amp = ((db + 60) / 60).clamp(0.0, 1.0);
          } else {
            amp = 0.15 + (math.Random().nextDouble() * 0.1);
          }
        } catch (_) {
          amp = 0.0;
        }
        if (!mounted) return;
        setState(() {
          _amplitudes.add(amp);
          if (_amplitudes.length > 64) _amplitudes.removeAt(0);
        });
      });

      // start recorder with AAC/MP4 codec (better cross-platform support)
      await _recorder!.startRecorder(
        toFile: path,
        codec: Codec.aacMP4,
        bitRate: 64000,
        sampleRate: 44100,
        numChannels: 1,
      );

      // Wait for the recorder to fully initialize
      await Future.delayed(const Duration(milliseconds: 300));

      setState(() => _isRecording = true);
      setState(() => _logs.insert(0, 'grabación iniciada: $path'));
    } catch (e) {
      setState(() => _logs.insert(0, 'record start error: $e'));
      try {
        await _recorderSubscription?.cancel();
      } catch (_) {}
      _recorderSubscription = null;
    }
  }

  Future<void> _stopRecordingAndSend() async {
    if (_recorder == null) return;
    if (!_isRecording) return;

    String? recordedPath;
    try {
      recordedPath = await _recorder!.stopRecorder();
      setState(() => _logs.insert(0, 'grabación detenida: $recordedPath'));
    } catch (e) {
      setState(() => _logs.insert(0, 'stop recorder error: $e'));
    }

    try {
      // cancel subscription and keep collected amplitudes for a moment
      await _recorderSubscription?.cancel();
    } catch (_) {}
    _recorderSubscription = null;
    setState(() => _isRecording = false);

    if (recordedPath == null || recordedPath.isEmpty) {
      setState(() => _logs.insert(0, 'no path returned from recorder'));
      return;
    }

    try {
      // Leer bytes y convertir a base64
      final f = File(recordedPath);
      if (!await f.exists()) {
        setState(() => _logs.insert(0, 'record file not found: $recordedPath'));
        return;
      }

      // Add small delay to ensure file is fully written
      await Future.delayed(const Duration(milliseconds: 200));

      final bytes = await f.readAsBytes();
      setState(() => _logs.insert(0, 'archivo leído: ${bytes.length} bytes'));

      // Check if file has some audio content (very permissive)
      if (bytes.length < 100) {
        setState(
          () => _logs.insert(
            0,
            'ERROR: Archivo vacío (${bytes.length}b). Verifica permisos de micrófono.',
          ),
        );
        return;
      }

      final b64 = base64Encode(bytes);

      // Enviar audio al servidor con formato AAC/MP4 correcto
      final dataUri = 'data:audio/mp4;base64,$b64';
      _ws.sendAudioBase64(dataUri);
      setState(
        () => _logs.insert(
          0,
          'audio sent (${(bytes.length / 1024).toStringAsFixed(1)} KB)',
        ),
      );
    } catch (e) {
      setState(() => _logs.insert(0, 'send audio error: $e'));
    }
  }

  // Captura imagen con la cámara y extrae texto con ML Kit
  Future<void> _captureAndRecognize() async {
    // solicitar permiso de cámara
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() => _logs.insert(0, 'permiso de cámara denegado'));
      return;
    }

    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 80,
      );
      if (picked == null) return;

      setState(() => _logs.insert(0, 'imagen capturada: ${picked.path}'));

      final inputImage = InputImage.fromFilePath(picked.path);
      final textRecognizer = TextRecognizer();
      final RecognizedText recognized = await textRecognizer.processImage(
        inputImage,
      );
      await textRecognizer.close();

      final extracted = recognized.text.trim();
      if (extracted.isEmpty) {
        setState(
          () => _logs.insert(0, 'OCR: no se encontró texto en la imagen'),
        );
        // mostrar alerta simple
        if (mounted) {
          showDialog(
            context: context,
            builder:
                (_) => AlertDialog(
                  title: const Text('OCR'),
                  content: const Text('No se detectó texto en la imagen.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
          );
        }
        return;
      }

      // enviar el texto al backend para traducir (marcado como OCR)
      _ws.sendOcrText(extracted);
      setState(
        () => _logs.insert(
          0,
          'OCR extraído y enviado (${extracted.length} chars)',
        ),
      );
    } catch (e) {
      setState(() => _logs.insert(0, 'error OCR: $e'));
    }
  }

  Future<void> _connect() async {
    try {
      await _ws.connect();
      _sub = _ws.onMessage.listen((m) {
        final t = m['type'] ?? 'msg';

        // Actualiza logs rápidamente
        setState(() {
          if (t == 'ready') {
            _logs.insert(0, '{type: ready, auth: ${m['auth']}}');
          } else if (t == 'ack') {
            _logs.insert(0, 'ack');
          } else if (t == 'partial') {
            _logs.insert(0, 'partial: ${m['text']}');
          } else if (t == 'done') {
            _logs.insert(0, 'done: ${m['text']}');
          } else if (t == 'error') {
            _logs.insert(0, 'error: ${m['detail']}');
          } else if (t == 'closed') {
            _logs.insert(0, 'closed: code=${m['code']} reason=${m['reason']}');
          } else {
            _logs.insert(0, m.toString());
          }
        });

        // Acciones fuera de setState: enviar config y mostrar modal en final
        if (t == 'ready') {
          // Enviar config apenas el servidor avisa que está listo
          _ws.sendConfig(source: _source, target: _target);
        } else if (t == 'done') {
          final translated = (m['text'] ?? '').toString();
          final transcription = (m['transcription'] ?? '').toString();
          final display =
              translated.isNotEmpty
                  ? translated
                  : (transcription.isNotEmpty
                      ? 'Transcripción: $transcription'
                      : '');
          // Mostrar modal con la traducción final o transcripción como fallback
          if (mounted) {
            showDialog(
              context: context,
              builder:
                  (ctx) => AlertDialog(
                    title: const Text('Traducción'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          display.isNotEmpty ? display : '— (sin resultado)',
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              tooltip: 'Escuchar',
                              icon: const Icon(Icons.volume_up),
                              onPressed:
                                  display.isNotEmpty
                                      ? () async {
                                        // Si el texto es "Transcripción: ...", hablar solo la parte tras ': '
                                        String toSpeak = display;
                                        if (toSpeak.startsWith(
                                          'Transcripción: ',
                                        )) {
                                          toSpeak = toSpeak.substring(14);
                                        }
                                        await _speakText(toSpeak, _target);
                                      }
                                      : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cerrar'),
                      ),
                    ],
                  ),
            );
          }
        }
      });
      setState(() => _connected = true);
    } catch (e) {
      setState(() => _logs.insert(0, 'connect error: $e'));
    }
  }

  Future<void> _disconnect() async {
    await _sub?.cancel();
    await _ws.close();
    setState(() => _connected = false);
  }

  void _sendText() {
    final t = _textCtrl.text.trim();
    if (t.isEmpty) return;
    _ws.sendText(t);
    setState(() {
      _logs.insert(0, 'sent: $t');
      _textCtrl.clear();
    });
  }

  void _sendConfigIfConnected() {
    if (_connected) {
      _ws.sendConfig(source: _source, target: _target);
      setState(() => _logs.insert(0, 'config sent: $_source -> $_target'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Traductor en línea')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _source,
                    items: const [
                      DropdownMenuItem(value: 'auto', child: Text('Detectar')),
                      DropdownMenuItem(value: 'en', child: Text('Inglés')),
                      DropdownMenuItem(value: 'es', child: Text('Español')),
                      DropdownMenuItem(value: 'fr', child: Text('Francés')),
                      DropdownMenuItem(value: 'pt', child: Text('Portugués')),
                      DropdownMenuItem(value: 'de', child: Text('Alemán')),
                      DropdownMenuItem(value: 'it', child: Text('Italiano')),
                    ],
                    onChanged: (v) {
                      setState(() => _source = v ?? 'auto');
                      _sendConfigIfConnected();
                    },
                    decoration: const InputDecoration(labelText: 'Origen'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _target,
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('Inglés')),
                      DropdownMenuItem(value: 'es', child: Text('Español')),
                      DropdownMenuItem(value: 'fr', child: Text('Francés')),
                      DropdownMenuItem(value: 'pt', child: Text('Portugués')),
                      DropdownMenuItem(value: 'de', child: Text('Alemán')),
                      DropdownMenuItem(value: 'it', child: Text('Italiano')),
                    ],
                    onChanged: (v) {
                      setState(() => _target = v ?? 'en');
                      _sendConfigIfConnected();
                    },
                    decoration: const InputDecoration(labelText: 'Destino'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _connected ? null : _connect,
                    icon: const Icon(Icons.power_settings_new),
                    label: const Text('Conectar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _connected ? _disconnect : null,
                    icon: const Icon(Icons.link_off),
                    label: const Text('Desconectar'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            // Text send area
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Enviar texto para traducir',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendText(),
                  ),
                ),
                const SizedBox(width: 8),
                // botón para abrir la cámara y hacer OCR
                IconButton(
                  tooltip: 'Capturar y traducir (OCR)',
                  icon: const Icon(Icons.camera_alt),
                  onPressed: _captureAndRecognize,
                ),
                ElevatedButton(
                  onPressed: _sendText,
                  child: const Text('Enviar'),
                ),
              ],
            ),

            const SizedBox(height: 12),
            // Grabación de audio (con VU meter)
            Card(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.mic,
                      color: _isRecording ? Colors.red : null,
                    ),
                    title: const Text('Grabación en vivo'),
                    subtitle: Text(
                      _isRecording
                          ? 'Grabando... (habla claro y presiona Detener)'
                          : 'Presiona Grabar, habla, y luego presiona Detener para traducir.',
                    ),
                    trailing: ElevatedButton.icon(
                      onPressed:
                          _recorder == null
                              ? null
                              : () async {
                                if (!_isRecording) {
                                  await _startRecording();
                                } else {
                                  await _stopRecordingAndSend();
                                }
                              },
                      icon: Icon(
                        _isRecording ? Icons.stop : Icons.fiber_manual_record,
                      ),
                      label: Text(_isRecording ? 'Detener' : 'Grabar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isRecording ? Colors.red : null,
                      ),
                    ),
                  ),
                  // Simple VU meter: a horizontal bar that shows the latest amplitude
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: SizedBox(
                      height: 18,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value:
                              _amplitudes.isNotEmpty ? _amplitudes.last : 0.0,
                          minHeight: 18,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _isRecording ? Colors.redAccent : Colors.blueAccent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Slider para ajustar la velocidad del TTS (más lento -> valor menor)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                children: [
                  const Text('Velocidad audio', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Slider(
                      value: _speechRate,
                      min: 0.4,
                      max: 1.4,
                      divisions: 10,
                      label: '${_speechRate.toStringAsFixed(2)}x',
                      onChanged: (v) {
                        setState(() => _speechRate = v);
                        try {
                          _tts.setSpeechRate(v);
                        } catch (_) {}
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Expanded(
              child:
                  _logs.isEmpty
                      ? const Center(child: Text('Sin mensajes yet'))
                      : ListView.builder(
                        reverse: true,
                        itemCount: _logs.length,
                        itemBuilder:
                            (_, i) => Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6.0,
                              ),
                              child: Text(_logs[i]),
                            ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
