import 'package:dio/dio.dart';
import 'api.dart';

class AuthService {
  /// Registro de usuario
  /// Debe coincidir con tu serializer en Django (password2 obligatorio).
  static Future<void> register({
    required String username,
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String nativeLanguage,
    required String targetLanguage,
    int? age,
    String? level,
    String? nationality, // ← NUEVO
  }) async {
    try {
      final data = <String, dynamic>{
          "username": username,
          "first_name": firstName,
          "last_name": lastName,
          "email": email,
          "password": password,
          "password2": password, // el backend lo requiere
          "native_language": nativeLanguage,
          "target_language": targetLanguage,
          "age": age,
          "level": level,
          "nationality": nationality, // ← NUEVO
        }
        // elimina las claves con null para no romper validaciones DRF
        ..removeWhere((_, v) => v == null);

      await Api.dio.post("users/register/", data: data);
    } on DioException catch (e) {
      throw _formatDioError(e, defaultMsg: "No se pudo registrar.");
    }
  }

  /// Login: guarda access/refresh en SecureStorage
  static Future<void> login({
    required String username,
    required String password,
  }) async {
    try {
      final r = await Api.dio.post(
        "auth/token/",
        data: {"username": username, "password": password},
      );
      final access = r.data["access"] as String?;
      final refresh = r.data["refresh"] as String?;
      if (access == null || refresh == null) {
        throw "Respuesta de login inválida.";
      }
      await Api.storage.write(key: "access", value: access);
      await Api.storage.write(key: "refresh", value: refresh);
    } on DioException catch (e) {
      throw _formatDioError(e, defaultMsg: "Credenciales inválidas.");
    }
  }

  /// Cerrar sesión: borra tokens
  static Future<void> logout() async {
    await Api.storage.delete(key: "access");
    await Api.storage.delete(key: "refresh");
  }

  /// ¿Hay sesión válida? (sólo verifica que existan tokens)
  static Future<bool> isLoggedIn() async {
    final access = await Api.storage.read(key: "access");
    final refresh = await Api.storage.read(key: "refresh");
    return access != null &&
        access.isNotEmpty &&
        refresh != null &&
        refresh.isNotEmpty;
  }

  /// Obtener el access por si lo necesitas (Dio ya lo añade en el interceptor)
  static Future<String?> getAccessToken() => Api.storage.read(key: "access");

  // ----------------- helpers -----------------

  static String _formatDioError(DioException e, {required String defaultMsg}) {
    // Intenta extraer mensajes de error del backend DRF
    final data = e.response?.data;
    if (data is Map) {
      // DRF típico: {"email":["Este campo ya existe."], "password":["Muy corta"], "detail":"..."}
      if (data["detail"] is String) return data["detail"];

      final buffer = StringBuffer();
      data.forEach((k, v) {
        if (v is List && v.isNotEmpty) {
          buffer.writeln("$k: ${v.first}");
        } else if (v is String) {
          buffer.writeln("$k: $v");
        }
      });
      final msg = buffer.toString().trim();
      if (msg.isNotEmpty) return msg;
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return "Tiempo de conexión agotado. Verificá tu red o la URL del backend.";
    }
    if (e.type == DioExceptionType.badResponse) {
      return "Error del servidor (${e.response?.statusCode}).";
    }
    return defaultMsg;
  }
}
