import 'package:dio/dio.dart';

class ApiClient {
  final Dio _dio = Dio();

  // Si estás en Desktop usa localhost, si es emulador Android usa 10.0.2.2
  final String baseUrl = "http://localhost:8000/api";

  ApiClient() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 5);
    _dio.options.receiveTimeout = const Duration(seconds: 3);
  }

  Dio get instance => _dio;
}