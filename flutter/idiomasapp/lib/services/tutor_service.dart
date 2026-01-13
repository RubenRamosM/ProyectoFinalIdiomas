import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api.dart';

class TutorService {
  static String get _baseUrl => Api.baseUrl;

  /// Obtiene la lista de conversaciones del usuario
  static Future<List<TutorConversation>> getConversations({
    int page = 1,
    int pageSize = 20,
    bool activeOnly = false,
  }) async {
    try {
      final token = await Api.storage.read(key: 'access');
      if (token == null) throw Exception('No hay token de autenticación');

      final params = {
        'page': page.toString(),
        'page_size': pageSize.toString(),
        if (activeOnly) 'active_only': 'true',
      };

      final uri = Uri.parse(
        '${_baseUrl}ia/tutor/conversations/',
      ).replace(queryParameters: params);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final results = data['results'] ?? data;
        if (results is List) {
          return results
              .map((json) => TutorConversation.fromJson(json))
              .toList();
        }
        return [];
      } else {
        throw Exception(
          'Error al obtener conversaciones: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Obtiene una conversación específica con todos sus mensajes
  static Future<TutorConversationDetail> getConversation(
    int conversationId,
  ) async {
    try {
      final token = await Api.storage.read(key: 'access');
      if (token == null) throw Exception('No hay token de autenticación');

      final response = await http.get(
        Uri.parse('${_baseUrl}ia/tutor/conversations/$conversationId/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return TutorConversationDetail.fromJson(data);
      } else {
        throw Exception(
          'Error al obtener conversación: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Envía un mensaje al tutor y obtiene la respuesta
  static Future<SendMessageResponse> sendMessage({
    String? message,
    String? audioB64,
    String? audioLanguage,
    int? conversationId,
  }) async {
    try {
      final token = await Api.storage.read(key: 'access');
      if (token == null) throw Exception('No hay token de autenticación');

      final body = <String, dynamic>{};
      if (message != null && message.isNotEmpty) {
        body['message'] = message;
      }
      if (audioB64 != null && audioB64.isNotEmpty) {
        body['audio_b64'] = audioB64;
      }
      if (audioLanguage != null) {
        body['audio_language'] = audioLanguage;
      }
      if (conversationId != null) {
        body['conversation_id'] = conversationId;
      }

      final response = await http.post(
        Uri.parse('${_baseUrl}ia/tutor/send/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return SendMessageResponse.fromJson(data);
      } else {
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(errorData['error'] ?? 'Error al enviar mensaje');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Elimina una conversación (soft delete)
  static Future<void> deleteConversation(int conversationId) async {
    try {
      final token = await Api.storage.read(key: 'access');
      if (token == null) throw Exception('No hay token de autenticación');

      final response = await http.delete(
        Uri.parse('${_baseUrl}ia/tutor/conversations/$conversationId/delete/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Error al eliminar conversación: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Limpia todos los mensajes de una conversación
  static Future<void> clearConversation(int conversationId) async {
    try {
      final token = await Api.storage.read(key: 'access');
      if (token == null) throw Exception('No hay token de autenticación');

      final response = await http.post(
        Uri.parse('${_baseUrl}ia/tutor/conversations/$conversationId/clear/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Error al limpiar conversación: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
}

// ==================== Modelos ====================

class TutorConversation {
  final int id;
  final String title;
  final String targetLanguage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final int messageCount;
  final TutorMessagePreview? lastMessage;

  TutorConversation({
    required this.id,
    required this.title,
    required this.targetLanguage,
    required this.createdAt,
    required this.updatedAt,
    required this.isActive,
    required this.messageCount,
    this.lastMessage,
  });

  factory TutorConversation.fromJson(Map<String, dynamic> json) {
    return TutorConversation(
      id: json['id'],
      title: json['title'] ?? 'Nueva conversación',
      targetLanguage: json['target_language'] ?? 'inglés',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      isActive: json['is_active'] ?? true,
      messageCount: json['message_count'] ?? 0,
      lastMessage:
          json['last_message'] != null
              ? TutorMessagePreview.fromJson(json['last_message'])
              : null,
    );
  }
}

class TutorMessagePreview {
  final String role;
  final String content;
  final DateTime createdAt;

  TutorMessagePreview({
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory TutorMessagePreview.fromJson(Map<String, dynamic> json) {
    return TutorMessagePreview(
      role: json['role'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class TutorConversationDetail {
  final int id;
  final String title;
  final String targetLanguage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final List<TutorMessage> messages;

  TutorConversationDetail({
    required this.id,
    required this.title,
    required this.targetLanguage,
    required this.createdAt,
    required this.updatedAt,
    required this.isActive,
    required this.messages,
  });

  factory TutorConversationDetail.fromJson(Map<String, dynamic> json) {
    return TutorConversationDetail(
      id: json['id'],
      title: json['title'] ?? 'Nueva conversación',
      targetLanguage: json['target_language'] ?? 'inglés',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      isActive: json['is_active'] ?? true,
      messages:
          (json['messages'] as List?)
              ?.map((m) => TutorMessage.fromJson(m))
              .toList() ??
          [],
    );
  }
}

class TutorMessage {
  final int id;
  final String role;
  final String content;
  final String? audioB64;
  final DateTime createdAt;

  TutorMessage({
    required this.id,
    required this.role,
    required this.content,
    this.audioB64,
    required this.createdAt,
  });

  factory TutorMessage.fromJson(Map<String, dynamic> json) {
    return TutorMessage(
      id: json['id'],
      role: json['role'],
      content: json['content'],
      audioB64: json['audio_b64'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
  bool get hasAudio => audioB64 != null && audioB64!.isNotEmpty;
}

class SendMessageResponse {
  final int conversationId;
  final String conversationTitle;
  final TutorMessage userMessage;
  final TutorMessage assistantMessage;

  SendMessageResponse({
    required this.conversationId,
    required this.conversationTitle,
    required this.userMessage,
    required this.assistantMessage,
  });

  factory SendMessageResponse.fromJson(Map<String, dynamic> json) {
    return SendMessageResponse(
      conversationId: json['conversation_id'],
      conversationTitle: json['conversation_title'] ?? 'Nueva conversación',
      userMessage: TutorMessage.fromJson(json['user_message']),
      assistantMessage: TutorMessage.fromJson(json['assistant_message']),
    );
  }
}
