// lib/services/user_service.dart
import 'package:dio/dio.dart';
import 'api.dart';

class UserService {
  /// GET /api/users/me/
  static Future<Map<String, dynamic>> me() async {
    try {
      final r = await Api.dio.get("users/me/");
      return Map<String, dynamic>.from(r.data as Map);
    } on DioException catch (e) {
      throw e.response?.data ?? e.message ?? "Error obteniendo perfil";
    }
  }

  /// PATCH /api/users/me/  (opcional: requiere soporte en backend)
  static Future<void> updateMe({String? level, String? targetLanguage}) async {
    final data = <String, dynamic>{};
    if (level != null) data['level'] = level;
    if (targetLanguage != null) data['target_language'] = targetLanguage;

    try {
      await Api.dio.patch("users/me/", data: data);
    } on DioException catch (e) {
      // si tu backend aún no soporta PATCH, esto puede devolver 405
      throw e.response?.data ?? e.message ?? "Error actualizando perfil";
    }
  }
}
