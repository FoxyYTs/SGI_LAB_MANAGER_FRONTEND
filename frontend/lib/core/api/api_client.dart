import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../navigation_service.dart';
import '../../services/update_service.dart' show kAppVersion;

/// URL completa del servidor (sin /api/ — se agrega automáticamente).
/// Producción: --dart-define=SERVER_URL=https://apisgi.foxyyts.qzz.io
const _kServerUrl = String.fromEnvironment('SERVER_URL', defaultValue: '');

/// IP del servidor para builds móviles/desktop en red local.
/// Ejemplo: flutter run -d android --dart-define=SERVER_IP=192.168.1.50
const _kServerIp = String.fromEnvironment('SERVER_IP', defaultValue: '');


/// Cliente HTTP singleton para el backend SGI LAB MANAGER.
///
/// Resolución de URL base (orden de precedencia):
/// 1. `SERVER_URL` → URL completa (producción con HTTPS, Cloudflare Tunnel).
/// 2. `SERVER_IP`  → IP de red local en formato http://<ip>:8000/api/.
/// 3. Web sin defines → mismo host desde el que se sirvió la app.
/// 4. Desktop sin defines → localhost:8000.
class ApiClient {
  static ApiClient? _instance;

  late final Dio    _dio;
  late final String baseUrl;

  ApiClient._() {
    if (_kServerUrl.isNotEmpty) {
      final root = _kServerUrl.endsWith('/')
          ? _kServerUrl.substring(0, _kServerUrl.length - 1)
          : _kServerUrl;
      baseUrl = '$root/api/';
    } else {
      String host;
      if (_kServerIp.isNotEmpty) {
        host = _kServerIp;
      } else if (kIsWeb) {
        host = Uri.base.host;
      } else {
        host = 'localhost';
      }
      baseUrl = 'http://$host:8000/api/';
    }

    _dio = Dio(BaseOptions(
      baseUrl:        baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers:        _baseHeaders(),
    ));

    // Interceptor global: maneja 426 Upgrade Required
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (e, handler) {
        if (e.response?.statusCode == 426) {
          navigatorKey.currentState?.pushReplacementNamed('/actualizacion-requerida');
          return;
        }
        handler.next(e);
      },
    ));
  }

  static ApiClient get instance => _instance ??= ApiClient._();

  Dio get dio => _dio;

  Dio authenticatedDio(String? token) {
    final d = Dio(BaseOptions(
      baseUrl:        baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        ..._baseHeaders(),
        if (token != null) 'Authorization': 'Bearer $token',
      },
    ));
    d.interceptors.add(InterceptorsWrapper(
      onError: (e, handler) {
        if (e.response?.statusCode == 426) {
          navigatorKey.currentState?.pushReplacementNamed('/actualizacion-requerida');
          return;
        }
        handler.next(e);
      },
    ));
    return d;
  }

  /// Headers base: incluye X-App-Version solo en clientes no-web,
  /// para que el middleware del backend pueda verificar la versión.
  static Map<String, String> _baseHeaders() {
    if (kIsWeb) return {};
    return {'X-App-Version': kAppVersion};
  }
}
