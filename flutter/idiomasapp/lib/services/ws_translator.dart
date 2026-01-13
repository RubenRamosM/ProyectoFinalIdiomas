import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import 'api.dart';

class WsTranslator {
  final String baseWsUrl; // ej: ws://192.168.1.6:8000/api/ws/translator/
  IOWebSocketChannel? _ch;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onMessage => _controller.stream;

  bool get isConnected => _ch != null;

  WsTranslator(this.baseWsUrl);

  Future<void> connect() async {
    if (_ch != null) return;

    // 1) Token
    final token = await Api.getToken();
    final sep = baseWsUrl.contains('?') ? '&' : '?';
    final url = '$baseWsUrl${sep}token=${Uri.encodeComponent(token ?? '')}';

    // DEBUG: print URL and masked token for troubleshooting (development only)
    try {
      final masked =
          (token != null && token.length > 8)
              ? '${token.substring(0, 8)}...'
              : (token ?? 'null');
      // ignore: avoid_print
      print('WsTranslator connecting to: $url token(masked)=$masked');
    } catch (_) {}

    // 2) Conexión (keep-alive cada 20s)
    final uri = Uri.parse(url);
    final channel = IOWebSocketChannel.connect(
      uri,
      pingInterval: const Duration(seconds: 20),
      headers: token != null ? {'Authorization': 'Bearer $token'} : null,
    );

    _ch = channel;

    // 3) Suscripciones
    channel.stream.listen(
      (raw) {
        try {
          if (raw is String) {
            final m = json.decode(raw) as Map<String, dynamic>;
            _controller.add(m);
          } else {
            _controller.add({'type': 'raw', 'data': raw.toString()});
          }
        } catch (e) {
          _controller.add({'type': 'error', 'detail': 'parse error: $e'});
        }
      },
      onError: (e, st) {
        _controller.add({'type': 'error', 'detail': e.toString()});
        close();
      },
      onDone: () {
        _controller.add({
          'type': 'closed',
          'code': channel.closeCode,
          'reason': channel.closeReason,
        });
        close();
      },
      cancelOnError: true,
    );
  }

  void sendConfig({required String source, required String target}) {
    _send({'type': 'config', 'source_lang': source, 'target_lang': target});
  }

  void sendText(String text) {
    _send({'type': 'text', 'chunk': text});
  }

  /// Send OCR-origin text and mark it so server may apply OCR-cleaning before translating.
  void sendOcrText(String text) {
    _send({'type': 'text', 'chunk': text, 'ocr': true});
  }

  void sendAudioBase64(String b64) {
    _send({'type': 'audio', 'chunk_b64': b64});
  }

  void end() => _send({'type': 'end'});

  void _send(Map<String, dynamic> msg) {
    final ch = _ch;
    if (ch == null) return;
    try {
      ch.sink.add(json.encode(msg));
    } catch (e) {
      _controller.add({'type': 'error', 'detail': 'send failed: $e'});
    }
  }

  Future<void> close() async {
    final ch = _ch;
    _ch = null;
    try {
      await ch?.sink.close(ws_status.normalClosure);
    } catch (_) {}
  }
}
