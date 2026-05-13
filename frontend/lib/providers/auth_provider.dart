import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthProvider with ChangeNotifier {
  // Cambia localhost por la IP de tu máquina si pruebas en móvil físico, 
  // pero para Linux Desktop 'localhost' está perfecto.
  final Dio _dio = Dio(BaseOptions(baseUrl: "http://localhost:8000/api/"));
  final _storage = const FlutterSecureStorage();
  
  String? _token;
  String? _rol;

  bool get isAuthenticated => _token != null;
  String? get rol => _rol;

  // CORRECCIÓN AQUÍ: El async va después de los parámetros
  Future<bool> login(String username, String password) async {
    try {
      final response = await _dio.post('token/', data: {
        'username': username,
        'password': password,
      });

      _token = response.data['access'];
      // Guardamos el token de forma segura
      await _storage.write(key: 'token', value: _token);
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Error en login: $e");
      return false;
    }
  }

  void logout() async {
    await _storage.delete(key: 'token');
    _token = null;
    notifyListeners();
  }
}