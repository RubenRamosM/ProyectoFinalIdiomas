import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../services/api.dart';

class ShadowingExerciseScreen extends StatefulWidget {
  final String? expectedText;

  const ShadowingExerciseScreen({super.key, this.expectedText});

  @override
  State<ShadowingExerciseScreen> createState() =>
      _ShadowingExerciseScreenState();
}

class _ShadowingExerciseScreenState extends State<ShadowingExerciseScreen> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isRecording = false;
  bool _isSpeaking = false;
  String? _audioPath;
  String? _sentenceToRepeat;
  String? _lessonTitle;
  bool _isLoading = false;
  bool _isCorrect = false;

  double _speechRate = 0.4; // controllable speed
  @override
  void initState() {
    super.initState();
    _initRecorder();
    _initTts();
    // Usar el texto pasado desde AdaptiveLessonScreen
    _sentenceToRepeat = widget.expectedText;
  }

  void _initRecorder() async {
    await _recorder.openRecorder();
  }

  void _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(_speechRate);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      setState(() {
        _isSpeaking = true;
      });
    });

    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
      });
    });

    _flutterTts.setErrorHandler((msg) {
      setState(() {
        _isSpeaking = false;
      });
    });
  }

  Future<void> _speak() async {
    if (_sentenceToRepeat != null && _sentenceToRepeat!.isNotEmpty) {
      await _flutterTts.setSpeechRate(_speechRate);
      await _flutterTts.speak(_sentenceToRepeat!);
    }
  }

  Future<void> _stop() async {
    await _flutterTts.stop();
    setState(() {
      _isSpeaking = false;
    });
  }

  Future<void> _startRecording() async {
    // Solicitar permiso de micrófono
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permiso de micrófono denegado')),
        );
      }
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final fileName = 'shadowing_${DateTime.now().millisecondsSinceEpoch}.aac';
    _audioPath = '${tempDir.path}/$fileName';

    await _recorder.startRecorder(toFile: _audioPath);
    setState(() {
      _isRecording = true;
    });
  }

  Future<void> _stopRecording() async {
    await _recorder.stopRecorder();
    setState(() {
      _isRecording = false;
    });

    if (_audioPath != null) {
      await _sendAudioForPronunciationFeedback();
    }
  }

  Future<void> _sendAudioForPronunciationFeedback() async {
    if (_audioPath == null) return;

    final file = await http.MultipartFile.fromPath('file', _audioPath!);

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${Api.baseUrl}lessons/pronunciation-feedback/'),
    );

    // Agregar encabezado de autorización
    final token = await Api.getToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.files.add(file);

    // Agregar el texto esperado si está disponible
    if (_sentenceToRepeat != null && _sentenceToRepeat!.isNotEmpty) {
      request.fields['expected_text'] = _sentenceToRepeat!;
    }

    try {
      final response = await request.send();
      final responseString = await response.stream.bytesToString();
      final data = json.decode(responseString);

      if (response.statusCode == 200) {
        // Capturar el resultado de correcto/incorrecto
        setState(() {
          _isCorrect = data['is_correct'] ?? false;
        });

        // Mostrar feedback de pronunciación
        if (mounted) {
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Resultado'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Puntuación: ${data['score']}%'),
                      const SizedBox(height: 10),
                      Text('Comentarios: ${data['feedback']}'),
                      const SizedBox(height: 10),
                      Text('Transcripción: ${data['transcription']}'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Intentar de nuevo'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(
                          context,
                        ).pop(_isCorrect); // Retornar el resultado real
                      },
                      child: const Text('Continuar'),
                    ),
                  ],
                ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['error'] ?? 'Error al procesar el audio'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
      }
    }
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ejercicio de Shadowing')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_lessonTitle ?? 'Ejercicio de Shadowing')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Mostrar instrucciones
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.hearing, size: 48, color: Colors.blue),
                  const SizedBox(height: 16),
                  const Text(
                    'Escucha y repite la frase',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Este ejercicio te ayudará a mejorar tu pronunciación y fluidez',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Mostrar la frase a repetir
            if (_sentenceToRepeat != null) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Repite esta frase:',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _sentenceToRepeat!,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Botón para escuchar + selector de velocidad
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isSpeaking ? _stop : _speak,
                    icon: Icon(_isSpeaking ? Icons.stop : Icons.volume_up),
                    label: Text(
                      _isSpeaking ? 'Detener Audio' : 'Escuchar Frase',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Speed selector
                  PopupMenuButton<double>(
                    tooltip: 'Velocidad de reproducción',
                    icon: const Icon(Icons.speed, color: Colors.blue),
                    onSelected: (value) async {
                      setState(() {
                        _speechRate = value;
                      });
                      await _flutterTts.setSpeechRate(_speechRate);
                    },
                    itemBuilder:
                        (context) => [
                          PopupMenuItem(
                            value: 0.25,
                            child: Text('Muy lento (0.25x)'),
                          ),
                          PopupMenuItem(
                            value: 0.4,
                            child: Text('Lento (0.4x)'),
                          ),
                          PopupMenuItem(
                            value: 0.6,
                            child: Text('Normal lento (0.6x)'),
                          ),
                          PopupMenuItem(
                            value: 1.0,
                            child: Text('Normal (1.0x)'),
                          ),
                        ],
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],

            // Botón de grabación
            FloatingActionButton.extended(
              onPressed: _isRecording ? _stopRecording : _startRecording,
              backgroundColor:
                  _isRecording
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
              label: Text(
                _isRecording ? 'Detener' : 'Grabar',
                style: const TextStyle(color: Colors.white),
              ),
              icon: Icon(
                _isRecording ? Icons.stop : Icons.mic,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isRecording
                  ? 'Grabando... Repite la frase en voz alta'
                  : 'Presiona para comenzar a grabar',
              style: TextStyle(
                color:
                    _isRecording
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 40),

            // Instrucciones adicionales
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Instrucciones:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text('1. Lee la frase en voz alta con claridad'),
                  Text('2. Mantén una distancia adecuada del micrófono'),
                  Text(
                    '3. Habla con naturalidad como si estuvieras conversando',
                  ),
                  Text('4. Escucha la retroalimentación para mejorar'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
