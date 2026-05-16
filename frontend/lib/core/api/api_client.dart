import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// IP del servidor inyectada en build time.
/// Ejemplo móvil: flutter run -d android --dart-define=SERVER_IP=192.168.1.50
const _kServerIp = String.fromEnvironment('SERVER_IP', defaultValue: '');

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

  static ApiClient get instance => _instance ??= ApiClient._();

  Dio get dio => _dio;

  Dio authenticatedDio(String? token) => Dio(BaseOptions(
    baseUrl:        baseUrl,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 10),
    headers: {if (token != null) 'Authorization': 'Bearer $token'},
  ));
}
