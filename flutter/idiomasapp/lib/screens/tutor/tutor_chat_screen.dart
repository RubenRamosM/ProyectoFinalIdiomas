import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/tutor_service.dart';

class TutorChatScreen extends StatefulWidget {
  final int? conversationId;

  const TutorChatScreen({super.key, this.conversationId});

  @override
  State<TutorChatScreen> createState() => _TutorChatScreenState();
}

class _TutorChatScreenState extends State<TutorChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<TutorMessage> _messages = [];
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  int? _currentConversationId;
  String _conversationTitle = 'Tutor Inteligente';
  bool _isLoading = false;
  bool _isSending = false;
  bool _isRecording = false;
  bool _isRecorderInitialized = false;
  bool _isPlayingAudio = false;
  int? _playingMessageId;
  double _playbackRate = 1.0;
  String? _error;
  String? _recordedAudioPath;

  @override
  void initState() {
    super.initState();
    _currentConversationId = widget.conversationId;
    _initRecorder();
    if (_currentConversationId != null) {
      _loadConversation();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _recorder.closeRecorder();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initRecorder() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      return;
    }

    try {
      await _recorder.openRecorder();
      setState(() {
        _isRecorderInitialized = true;
      });
    } catch (e) {
      debugPrint('Error inicializando grabadora: $e');
    }
  }

  Future<void> _loadConversation() async {
    if (_currentConversationId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final conversation = await TutorService.getConversation(
        _currentConversationId!,
      );
      if (!mounted) return;

      setState(() {
        _messages.clear();
        _messages.addAll(conversation.messages);
        _conversationTitle = conversation.title;
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
      _error = null;
    });

    // Limpiar campo inmediatamente
    _messageController.clear();

    // Agregar mensaje del usuario optimísticamente
    final tempUserMessage = TutorMessage(
      id: -1,
      role: 'user',
      content: text,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(tempUserMessage);
    });

    _scrollToBottom();

    try {
      final response = await TutorService.sendMessage(
        message: text,
        conversationId: _currentConversationId,
        audioLanguage: 'en',
      );

      if (!mounted) return;

      setState(() {
        // Remover mensaje temporal y agregar los reales
        _messages.removeWhere((m) => m.id == -1);
        _messages.add(response.userMessage);
        _messages.add(response.assistantMessage);
        _currentConversationId = response.conversationId;
        _conversationTitle = response.conversationTitle;
        _isSending = false;
      });

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // Remover mensaje temporal en caso de error
        _messages.removeWhere((m) => m.id == -1);
        _error = e.toString();
        _isSending = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _startRecording() async {
    if (!_isRecorderInitialized || _isRecording) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${tempDir.path}/audio_$timestamp.m4a';

      await _recorder.startRecorder(
        toFile: path,
        codec: Codec.aacMP4,
        bitRate: 64000,
        sampleRate: 44100,
        numChannels: 1,
      );

      setState(() {
        _isRecording = true;
        _recordedAudioPath = path;
      });
    } catch (e) {
      debugPrint('Error iniciando grabación: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error iniciando grabación: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _stopRecordingAndSend() async {
    if (!_isRecording) return;

    try {
      await _recorder.stopRecorder();
      setState(() {
        _isRecording = false;
      });

      if (_recordedAudioPath == null) return;

      // Leer archivo y convertir a base64
      final file = File(_recordedAudioPath!);
      final bytes = await file.readAsBytes();
      final audioB64 = base64Encode(bytes);

      // Enviar audio al backend
      await _sendAudioMessage(audioB64);

      // Limpiar archivo temporal
      try {
        await file.delete();
      } catch (_) {}

      setState(() {
        _recordedAudioPath = null;
      });
    } catch (e) {
      debugPrint('Error deteniendo grabación: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error procesando audio: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isRecording = false;
        _recordedAudioPath = null;
      });
    }
  }

  Future<void> _sendAudioMessage(String audioB64) async {
    if (_isSending) return;

    setState(() {
      _isSending = true;
      _error = null;
    });

    // Mensaje temporal
    final tempUserMessage = TutorMessage(
      id: -1,
      role: 'user',
      content: '🎤 Enviando audio...',
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(tempUserMessage);
    });

    _scrollToBottom();

    try {
      final response = await TutorService.sendMessage(
        audioB64: audioB64,
        conversationId: _currentConversationId,
        audioLanguage: 'en',
      );

      if (!mounted) return;

      setState(() {
        _messages.removeWhere((m) => m.id == -1);
        _messages.add(response.userMessage);
        _messages.add(response.assistantMessage);
        _currentConversationId = response.conversationId;
        _conversationTitle = response.conversationTitle;
        _isSending = false;
      });

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m.id == -1);
        _error = e.toString();
        _isSending = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _playAudio(String audioB64, int messageId) async {
    try {
      // Si ya está reproduciendo este mensaje, pausar
      if (_isPlayingAudio && _playingMessageId == messageId) {
        await _audioPlayer.stop();
        setState(() {
          _isPlayingAudio = false;
          _playingMessageId = null;
        });
        return;
      }

      // Detener cualquier reproducción anterior
      await _audioPlayer.stop();

      final bytes = base64Decode(audioB64);
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempFile = File('${tempDir.path}/temp_audio_$timestamp.mp3');
      await tempFile.writeAsBytes(bytes);

      setState(() {
        _isPlayingAudio = true;
        _playingMessageId = messageId;
      });

      // Configurar velocidad de reproducción
      await _audioPlayer.setPlaybackRate(_playbackRate);
      await _audioPlayer.play(DeviceFileSource(tempFile.path));

      // Listener para cuando termine
      _audioPlayer.onPlayerComplete.listen((_) async {
        setState(() {
          _isPlayingAudio = false;
          _playingMessageId = null;
        });
        try {
          await tempFile.delete();
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('Error reproduciendo audio: $e');
      setState(() {
        _isPlayingAudio = false;
        _playingMessageId = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reproduciendo audio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPlaybackSpeedMenu(String audioB64, int messageId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Velocidad de reproducción',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF667eea),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildSpeedOption(0.75, '🐢 Lento', audioB64, messageId),
              _buildSpeedOption(1.0, '▶️ Normal', audioB64, messageId),
              _buildSpeedOption(1.25, '⚡ Rápido', audioB64, messageId),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpeedOption(
    double speed,
    String label,
    String audioB64,
    int messageId,
  ) {
    final isSelected = _playbackRate == speed;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color:
              isSelected
                  ? const Color(0xFF667eea)
                  : const Color(0xFF667eea).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isSelected ? Icons.check : Icons.speed,
          color: isSelected ? Colors.white : const Color(0xFF667eea),
          size: 20,
        ),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? const Color(0xFF667eea) : Colors.black87,
        ),
      ),
      trailing:
          isSelected
              ? const Icon(Icons.volume_up, color: Color(0xFF667eea))
              : null,
      onTap: () {
        setState(() {
          _playbackRate = speed;
        });
        Navigator.pop(context);
        _playAudio(audioB64, messageId);
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showConversationMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.history, color: Color(0xFF667eea)),
                  title: const Text('Ver historial'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/tutor-history');
                  },
                ),
                if (_currentConversationId != null) ...[
                  ListTile(
                    leading: const Icon(
                      Icons.delete_sweep,
                      color: Colors.orange,
                    ),
                    title: const Text('Limpiar conversación'),
                    onTap: () async {
                      Navigator.pop(context);
                      await _clearConversation();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('Eliminar conversación'),
                    onTap: () async {
                      Navigator.pop(context);
                      await _deleteConversation();
                    },
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  Future<void> _clearConversation() async {
    if (_currentConversationId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('¿Limpiar conversación?'),
            content: const Text(
              'Se eliminarán todos los mensajes de esta conversación.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Limpiar',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    try {
      await TutorService.clearConversation(_currentConversationId!);
      if (!mounted) return;
      setState(() {
        _messages.clear();
        _conversationTitle = 'Nueva conversación';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteConversation() async {
    if (_currentConversationId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('¿Eliminar conversación?'),
            content: const Text('Esta acción no se puede deshacer.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Eliminar',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    try {
      await TutorService.deleteConversation(_currentConversationId!);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF667eea),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _conversationTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'Disponible 24/7 🤖',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: _showConversationMenu,
          ),
        ],
      ),
      body: Column(
        children: [
          // Mensajes
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        return _buildMessageBubble(message);
                      },
                    ),
          ),

          // Indicador de escritura
          if (_isSending)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTypingDot(0),
                        const SizedBox(width: 4),
                        _buildTypingDot(1),
                        const SizedBox(width: 4),
                        _buildTypingDot(2),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Campo de entrada
          _buildInputField(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 64,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '¡Hola! Soy tu tutor inteligente 👋',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF667eea),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Estoy aquí para ayudarte con cualquier duda sobre idiomas.\n\n'
              '• Gramática y vocabulario\n'
              '• Pronunciación y conversación\n'
              '• Cultura y expresiones\n'
              '• Consejos de aprendizaje',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const Text(
              '¡Pregúntame lo que quieras! 😊',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF764ba2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(TutorMessage message) {
    final isUser = message.isUser;
    final time = DateFormat('HH:mm').format(message.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF667eea),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient:
                    isUser
                        ? const LinearGradient(
                          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                        )
                        : null,
                color: isUser ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 15,
                      color: isUser ? Colors.white : Colors.black87,
                      height: 1.4,
                    ),
                  ),
                  if (message.hasAudio && !isUser) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 180),
                          child: InkWell(
                            onTap:
                                () => _playAudio(message.audioB64!, message.id),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    _isPlayingAudio &&
                                            _playingMessageId == message.id
                                        ? const Color(0xFF667eea)
                                        : const Color(
                                          0xFF667eea,
                                        ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isPlayingAudio &&
                                            _playingMessageId == message.id
                                        ? Icons.stop
                                        : Icons.play_circle_outline,
                                    color:
                                        _isPlayingAudio &&
                                                _playingMessageId == message.id
                                            ? Colors.white
                                            : const Color(0xFF667eea),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      _isPlayingAudio &&
                                              _playingMessageId == message.id
                                          ? 'Reproduciendo...'
                                          : 'Escuchar pronunciación',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color:
                                            _isPlayingAudio &&
                                                    _playingMessageId ==
                                                        message.id
                                                ? Colors.white
                                                : const Color(0xFF667eea),
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap:
                              () => _showPlaybackSpeedMenu(
                                message.audioB64!,
                                message.id,
                              ),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF667eea).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.speed,
                                  color: Color(0xFF667eea),
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${_playbackRate}x',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF667eea),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 11,
                      color: isUser ? Colors.white70 : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF764ba2),
              child: const Icon(Icons.person, color: Colors.white, size: 20),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        final delay = index * 0.2;
        final animValue = (value - delay).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, -4 * animValue),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              shape: BoxShape.circle,
            ),
          ),
        );
      },
      onEnd: () {
        if (mounted) setState(() {});
      },
    );
  }

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Botón de micrófono
            Container(
              decoration: BoxDecoration(
                color:
                    _isRecording
                        ? Colors.red.withOpacity(0.1)
                        : const Color(0xFFF5F7FA),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  _isRecording ? Icons.stop : Icons.mic,
                  color: _isRecording ? Colors.red : const Color(0xFF667eea),
                ),
                onPressed:
                    _isSending || !_isRecorderInitialized
                        ? null
                        : () {
                          if (_isRecording) {
                            _stopRecordingAndSend();
                          } else {
                            _startRecording();
                          }
                        },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Escribe tu pregunta...',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  enabled: !_isSending && !_isRecording,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF667eea).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                icon:
                    _isSending
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Icon(Icons.send, color: Colors.white),
                onPressed: _isSending || _isRecording ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
