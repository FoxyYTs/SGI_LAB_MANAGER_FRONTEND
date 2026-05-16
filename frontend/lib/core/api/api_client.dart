import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiClient {
  static ApiClient? _instance;

  late final Dio _dio;
  late final String baseUrl;

  ApiClient._() {
    // En Web usamos el mismo host desde donde se sirve la app
    // (funciona con localhost Y con 10.51.1.226 sin cambiar código)
    final host = kIsWeb ? Uri.base.host : 'localhost';
    baseUrl = 'http://$host:8000/api/';

    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 10),
    ));
  }

  static ApiClient get instance => _instance ??= ApiClient._();

  Dio get dio => _dio;

  // Agrega el header de autorización JWT en cada petición autenticada
  Dio authenticatedDio(String? token) {
    final authDio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    ));
    return authDio;
  }
}
