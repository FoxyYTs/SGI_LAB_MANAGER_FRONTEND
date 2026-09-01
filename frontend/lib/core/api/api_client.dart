import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../navigation_service.dart';
import '../../services/update_service.dart' show kAppVersion;

/// URL completa del servidor (sin /api/ — se agrega automáticamente).
/// Producción: --dart-define=SERVER_URL=https://apisgi.foxyyts.qzz.io
const _kServerUrl = String.fromEnvironment('SERVER_URL', defaultValue: '');

/// IP del servidor para builds móviles/desktop en red local.
const _kServerIp = String.fromEnvironment('SERVER_IP', defaultValue: '');

/// Cliente HTTP singleton para el backend SGI LAB MANAGER.
///
/// Resolución de URL base (orden de precedencia):
/// 1. `SERVER_URL` → URL completa (producción con HTTPS, Cloudflare Tunnel).
/// 2. `SERVER_IP`  → IP de red local en formato http://<ip>:8000/api/.
/// 3. Web sin defines → mismo host desde el que se sirvió la app.
/// 4. Desktop sin defines → localhost:8000.
///
/// Refresco automático de token:
/// Cuando una petición autenticada recibe HTTP 401, el interceptor intenta
/// obtener un nuevo access token con el refresh token (POST /api/token/refresh/).
/// Si el refresco tiene éxito, la petición original se reintenta con el nuevo
/// token sin que el usuario lo note. Si falla (refresh expirado), se llama a
/// [_onLogout] para cerrar la sesión limpiamente.
class ApiClient {
  static ApiClient? _instance;

  late final Dio    _dio;
  late final String baseUrl;

  // Estado del refresco de token
  String?            _refreshTokenStr;
  Future<String?>?   _refreshFuture;        // evita múltiples refreshes simultáneos
  void Function(String newToken)?   _onTokenRefreshed;
  void Function(String newRefresh)? _onRefreshRotated;
  void Function()?                  _onLogout;

  ApiClient._() {
    if (_kServerUrl.isNotEmpty) {
      final root = _kServerUrl.endsWith('/')
          ? _kServerUrl.substring(0, _kServerUrl.length - 1)
          : _kServerUrl;
      baseUrl = '$root/api/';
    } else {
      String host;
      String scheme;
      if (_kServerIp.isNotEmpty) {
        host   = _kServerIp;
        scheme = 'http';
      } else if (kIsWeb) {
        host   = Uri.base.host;
        scheme = Uri.base.scheme;
      } else {
        host   = 'localhost';
        scheme = 'http';
      }
      baseUrl = '$scheme://$host:8000/api/';
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

  /// Registra los tokens y los callbacks necesarios para el refresco automático.
  /// Llamar desde AuthProvider tras login y tras restaurar sesión.
  void setTokens(
    String accessToken,
    String refreshToken, {
    required void Function(String newToken)   onRefreshed,
    required void Function()                  onLogout,
    void Function(String newRefresh)?         onRefreshRotated,
  }) {
    _refreshTokenStr   = refreshToken;
    _onTokenRefreshed  = onRefreshed;
    _onRefreshRotated  = onRefreshRotated;
    _onLogout          = onLogout;
  }

  /// Limpia el estado de tokens (al hacer logout).
  void clearTokens() {
    _refreshTokenStr  = null;
    _onTokenRefreshed = null;
    _onRefreshRotated = null;
    _onLogout         = null;
    _refreshFuture    = null;
  }

  /// Intenta obtener un nuevo access token usando el refresh token.
  /// Si hay un refresco en curso, espera su resultado en lugar de lanzar otro.
  Future<String?> _tryRefresh() {
    _refreshFuture ??= _doRefresh().whenComplete(() => _refreshFuture = null);
    return _refreshFuture!;
  }

  Future<String?> _doRefresh() async {
    if (_refreshTokenStr == null) return null;
    try {
      final resp       = await _dio.post('token/refresh/', data: {'refresh': _refreshTokenStr});
      final newToken   = resp.data['access']  as String;
      // ROTATE_REFRESH_TOKENS=True: el endpoint devuelve también un nuevo refresh token
      // y blacklistea el anterior. Hay que actualizarlo o el siguiente refresh fallará.
      final newRefresh = resp.data['refresh'] as String?;
      if (newRefresh != null) {
        _refreshTokenStr = newRefresh;
        _onRefreshRotated?.call(newRefresh);
      }
      _onTokenRefreshed?.call(newToken);
      debugPrint('[ApiClient] Token refrescado correctamente.');
      return newToken;
    } catch (e) {
      debugPrint('[ApiClient] Refresco fallido: $e — cerrando sesión.');
      _onLogout?.call();
      return null;
    }
  }

  /// Devuelve un Dio con el header Authorization configurado.
  /// Incluye un interceptor que refresca el token automáticamente en caso de 401.
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
      onError: (e, handler) async {
        if (e.response?.statusCode == 426) {
          navigatorKey.currentState?.pushReplacementNamed('/actualizacion-requerida');
          return;
        }

        // Refresco automático de token en 401
        if (e.response?.statusCode == 401 && _refreshTokenStr != null) {
          final newToken = await _tryRefresh();
          if (newToken != null) {
            // Reintentar la petición original con el nuevo token
            try {
              final opts = e.requestOptions;
              opts.headers['Authorization'] = 'Bearer $newToken';
              final retryResp = await d.fetch(opts);
              return handler.resolve(retryResp);
            } catch (retryErr) {
              return handler.next(e);
            }
          }
          // Si el refresco falló, _onLogout ya fue llamado desde _doRefresh
          return;
        }

        handler.next(e);
      },
    ));
    return d;
  }

  static Map<String, String> _baseHeaders() {
    if (kIsWeb) return {};
    return {'X-App-Version': kAppVersion};
  }
}
