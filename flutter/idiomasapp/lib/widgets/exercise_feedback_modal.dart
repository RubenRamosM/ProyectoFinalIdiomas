// lib/widgets/exercise_feedback_modal.dart
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Modal que muestra feedback detallado cuando el usuario responde incorrectamente
/// Incluye: respuesta correcta, explicación y opción de escuchar la pronunciación
class ExerciseFeedbackModal extends StatefulWidget {
  final String correctAnswer;
  final String? explanation;
  final String? userAnswer;
  final bool isCorrect;
  final String? targetLanguageCode; // Para TTS (ej: "en-US", "es-ES")
  final VoidCallback? onClose; // Callback cuando se cierra el modal

  const ExerciseFeedbackModal({
    Key? key,
    required this.correctAnswer,
    this.explanation,
    this.userAnswer,
    required this.isCorrect,
    this.targetLanguageCode,
    this.onClose,
  }) : super(key: key);

  @override
  State<ExerciseFeedbackModal> createState() => _ExerciseFeedbackModalState();

  /// Muestra el modal como BottomSheet
  static Future<void> show({
    required BuildContext context,
    required String correctAnswer,
    String? explanation,
    String? userAnswer,
    required bool isCorrect,
    String? targetLanguageCode,
    VoidCallback? onClose,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (ctx) => ExerciseFeedbackModal(
            correctAnswer: correctAnswer,
            explanation: explanation,
            userAnswer: userAnswer,
            isCorrect: isCorrect,
            targetLanguageCode: targetLanguageCode,
            onClose: onClose,
          ),
    );
  }
}

class _ExerciseFeedbackModalState extends State<ExerciseFeedbackModal> {
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _configureTts();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _configureTts() async {
    // Configurar idioma según el código proporcionado
    final langCode = widget.targetLanguageCode ?? 'en-US';
    await _tts.setLanguage(langCode);
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.85);

    // Callback para actualizar estado cuando termine de hablar
    _tts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _isSpeaking = false);
      }
    });
  }

  Future<void> _speakCorrectAnswer() async {
    if (_isSpeaking) {
      await _tts.stop();
      setState(() => _isSpeaking = false);
      return;
    }

    setState(() => _isSpeaking = true);
    try {
      await _tts.speak(widget.correctAnswer);
    } catch (e) {
      if (mounted) {
        setState(() => _isSpeaking = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al reproducir: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCorrect = widget.isCorrect;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con icono y estado
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        isCorrect
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCorrect ? Icons.check_circle : Icons.info_outline,
                    color: isCorrect ? Colors.green : Colors.orange,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    isCorrect ? '¡Correcto!' : 'Respuesta Incorrecta',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isCorrect ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Tu respuesta (si es incorrecta y hay userAnswer)
            if (!isCorrect && widget.userAnswer != null) ...[
              Text(
                'Tu respuesta:',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.close, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.userAnswer!,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.red[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Respuesta correcta
            Text(
              'Respuesta correcta:',
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.green.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.correctAnswer,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.green[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Botón de pronunciación
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _speakCorrectAnswer,
                    icon: Icon(
                      _isSpeaking ? Icons.stop : Icons.volume_up,
                      size: 20,
                    ),
                    label: Text(
                      _isSpeaking
                          ? 'Detener pronunciación'
                          : 'Escuchar pronunciación',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green[700],
                      side: BorderSide(color: Colors.green.withOpacity(0.4)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Explicación
            if (widget.explanation != null &&
                widget.explanation!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: Colors.blue[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Explicación:',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: Colors.blue[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.explanation!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[800],
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Botón de continuar
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Continuar'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: isCorrect ? Colors.green : Colors.orange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
