import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config.dart';

class Api {
  // URL base actual (arranca con la del config)
  static String _baseUrl = kApiBase;

  // Cliente Dio con timeouts razonables
  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: kApiBase, // se actualizará en init() si hay override en storage
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
      headers: {"Content-Type": "application/json"},
    ),
  );

  static const FlutterSecureStorage storage = FlutterSecureStorage();
  static bool _interceptorsAdded = false;
  static bool _refreshingToken = false;

  static String get baseUrl => _baseUrl;

  /// Inicializa interceptores y carga URL de servidor guardada (si existe).
  static Future<void> init() async {
    if (_interceptorsAdded) return;
    _interceptorsAdded = true;

    // Intenta cargar baseUrl persistida (si el usuario la cambió antes)
    await _loadServerConfig();

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Inyecta access token si existe
          final access = await storage.read(key: "access");
          if (access != null && access.isNotEmpty) {
            options.headers["Authorization"] = "Bearer $access";
          }
          handler.next(options);
        },
        onError: (e, handler) async {
          // Evita refrescar si el error vino del propio refresh endpoint
          final isRefreshCall = e.requestOptions.path.contains(
            'auth/token/refresh',
          );

          if (e.response?.statusCode == 401 && !isRefreshCall) {
            // Intenta refresh con lock simple para evitar carreras
            if (_refreshingToken) {
              // Si otro refresh está en curso, espera un poco y reintenta el request original
              await Future.delayed(const Duration(milliseconds: 300));
              try {
                final clone = await dio.fetch(e.requestOptions);
                return handler.resolve(clone);
              } catch (_) {
                // dejar caer al handler.next(e)
              }
            } else {
              _refreshingToken = true;
              try {
                final refresh = await storage.read(key: "refresh");
                if (refresh != null && refresh.isNotEmpty) {
                  final r = await dio.post(
                    "auth/token/refresh/",
                    data: {"refresh": refresh},
                    // Evita heredar headers previos que puedan traer un Authorization vencido
                    options: Options(
                      headers: {"Content-Type": "application/json"},
                    ),
                  );

                  final newAccess =
                      (r.data is Map) ? r.data["access"] as String? : null;
                  if (newAccess != null && newAccess.isNotEmpty) {
                    await storage.write(key: "access", value: newAccess);

                    // Reintenta el request original con el nuevo token
                    final RequestOptions req = e.requestOptions;
                    req.headers["Authorization"] = "Bearer $newAccess";
                    final clone = await dio.fetch(req);
                    return handler.resolve(clone);
                  }
                }

                // Si no hay refresh, limpiar sesión
                await storage.deleteAll();
              } catch (err, st) {
                debugPrint('Token refresh error: $err\n$st');
                await storage.deleteAll();
              } finally {
                _refreshingToken = false;
              }
            }
          }

          // Si no pudimos resolver, deja pasar el error
          handler.next(e);
        },
      ),
    );
  }

  /// Devuelve el access token actual (o null).
  static Future<String?> getToken() async {
    return storage.read(key: "access");
  }

  /// Lee baseUrl persistida (si existe) y actualiza Dio + estado interno.
  static Future<void> _loadServerConfig() async {
    try {
      final savedUrl = await storage.read(key: 'api_base_url');
      if (savedUrl != null && savedUrl.isNotEmpty) {
        _applyBaseUrl(savedUrl);
      } else {
        _applyBaseUrl(kApiBase); // default del config
      }
    } catch (e) {
      debugPrint('Error loading server config: $e');
      _applyBaseUrl(kApiBase);
    }
  }

  /// Cambia la URL base (persiste y actualiza Dio).
  static Future<void> updateServerUrl(String newUrl) async {
    final normalized = _normalizeBaseUrl(newUrl);
    await storage.write(key: 'api_base_url', value: normalized);
    _applyBaseUrl(normalized);
  }

  /// Setter interno de baseUrl (sin tocar el config).
  static void _applyBaseUrl(String url) {
    _baseUrl = _normalizeBaseUrl(url);
    dio.options.baseUrl = _baseUrl;
  }

  /// Normaliza para evitar sorpresas (p.ej., faltante de slash final).
  static String _normalizeBaseUrl(String url) {
    var out = url.trim();
    // Si termina en '/', bien. Si no, se lo agregamos (Dio maneja paths relativos mejor así).
    if (!out.endsWith('/')) out = '$out/';
    return out;
  }

  // ---------------------------
  // OPCIONAL: Para soportar getUserLevel() en tu UI
  // ---------------------------

  /// Devuelve el nivel del usuario si está en storage; si no, intenta pedirlo al backend:
  /// Ajustá el endpoint 'users/me/' si en tu API es otro.
  static Future<String?> getUserLevel() async {
    // 1) Intentar leer de storage si vos lo guardás ahí
    final cached = await storage.read(key: 'user_level');
    if (cached != null && cached.isNotEmpty) return cached;

    // 2) Consultar al backend (ajustá el path si tu endpoint es distinto)
    try {
      final resp = await dio.get('users/me/');
      if (resp.statusCode == 200 && resp.data is Map) {
        final level = (resp.data as Map)['level'] as String?;
        if (level != null && level.isNotEmpty) {
          await storage.write(key: 'user_level', value: level);
          return level;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('getUserLevel() failed: $e');
      }
    }
    return null; // si no se pudo determinar
  }
}
