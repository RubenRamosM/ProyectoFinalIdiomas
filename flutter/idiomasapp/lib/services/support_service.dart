import '../models/support_models.dart';
import 'package:flutter/foundation.dart';
import 'api.dart';

class SupportService {
  /// Obtener todas las FAQs
  static Future<List<FAQ>> getFAQs({String? category}) async {
    try {
      String url = 'support/faqs/';
      if (category != null && category.isNotEmpty) {
        url += '?category=$category';
      }

      debugPrint('📍 Intentando cargar FAQs desde: [Api.baseUrl}$url');

      final response = await Api.dio.get(url);

      debugPrint('📡 Respuesta FAQs: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => FAQ.fromJson(json)).toList();
      } else {
        throw Exception('Error al cargar FAQs: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error en getFAQs: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  /// Obtener una FAQ específica por ID
  static Future<FAQ> getFAQById(int id) async {
    try {
      final response = await Api.dio.get('support/faqs/$id/');

      if (response.statusCode == 200) {
        return FAQ.fromJson(response.data);
      } else {
        throw Exception('Error al cargar FAQ: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Crear un nuevo ticket de soporte
  static Future<SupportTicket> createTicket({
    required String subject,
    required String message,
  }) async {
    try {
      final token = await Api.storage.read(key: 'access');
      if (token == null) {
        throw Exception('No hay token de autenticación');
      }

      debugPrint('📍 Creando ticket en: ${Api.baseUrl}support/tickets/');

      final response = await Api.dio.post(
        'support/tickets/',
        data: {'subject': subject, 'message': message},
      );

      debugPrint('📡 Respuesta crear ticket: ${response.statusCode}');

      if (response.statusCode == 201) {
        return SupportTicket.fromJson(response.data);
      } else if (response.statusCode == 401) {
        throw Exception('Sesión expirada. Por favor inicia sesión nuevamente.');
      } else {
        throw Exception('Error al crear ticket: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al crear ticket: $e');
    }
  }

  /// Obtener todos los tickets del usuario autenticado
  static Future<List<SupportTicket>> getMyTickets() async {
    try {
      final token = await Api.storage.read(key: 'access');
      if (token == null) {
        throw Exception('No hay token de autenticación');
      }

      final response = await Api.dio.get('support/tickets/');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => SupportTicket.fromJson(json)).toList();
      } else if (response.statusCode == 401) {
        throw Exception('Sesión expirada. Por favor inicia sesión nuevamente.');
      } else {
        throw Exception('Error al cargar tickets: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Obtener un ticket específico por ID
  static Future<SupportTicket> getTicketById(int id) async {
    try {
      final token = await Api.storage.read(key: 'access');
      if (token == null) {
        throw Exception('No hay token de autenticación');
      }

      final response = await Api.dio.get('support/tickets/$id/');

      if (response.statusCode == 200) {
        return SupportTicket.fromJson(response.data);
      } else if (response.statusCode == 401) {
        throw Exception('Sesión expirada. Por favor inicia sesión nuevamente.');
      } else {
        throw Exception('Error al cargar ticket: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
}
