import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// IP del servidor inyectada en build time.
/// Ejemplo móvil: flutter run -d android --dart-define=SERVER_IP=192.168.1.50
const _kServerIp = String.fromEnvironment('SERVER_IP', defaultValue: '');

/// Cliente HTTP singleton para el backend SGI LAB MANAGER.
///
/// La URL base se construye en función de la plataforma:
/// - Si se pasa `--dart-define=SERVER_IP=<ip>` en build, se usa esa IP.
/// - En web, se usa el mismo host desde el que se sirvió la app.
/// - En desktop (Linux/Windows) sin `SERVER_IP`, se usa `localhost`.
///
/// Nota de seguridad: la API usa HTTP (no HTTPS). En producción se resolverá
/// con HTTPS a través del Cloudflare Tunnel.
class ApiClient {
  static ApiClient? _instance;

  late final Dio   _dio;
  late final String baseUrl;

  ApiClient._() {
    String host;
    if (_kServerIp.isNotEmpty) {
      host = _kServerIp;
    } else if (kIsWeb) {
      host = Uri.base.host;
    } else {
      host = 'localhost';
    }
    baseUrl = 'http://$host:8000/api/';

    _dio = Dio(BaseOptions(
      baseUrl:        baseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 10),
    ));
  }

  /// Instancia global del cliente. Inicializada en el primer acceso.
  static ApiClient get instance => _instance ??= ApiClient._();

  /// Dio sin autenticación — solo para login y rutas públicas.
  Dio get dio => _dio;

  /// Retorna un Dio pre-configurado con el header `Authorization: Bearer <token>`.
  /// Cada llamada crea una nueva instancia para que el token no quede cacheado.
  Dio authenticatedDio(String? token) => Dio(BaseOptions(
    baseUrl:        baseUrl,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 10),
    headers: {if (token != null) 'Authorization': 'Bearer $token'},
  ));
}
