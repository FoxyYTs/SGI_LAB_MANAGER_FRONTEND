import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthProvider with ChangeNotifier {
  final Dio _dio = Dio(BaseOptions(baseUrl: "http://localhost:8000/api/"));
  final _storage = const FlutterSecureStorage();

  String? _token;
  String? _rol;
  String? _username;

  bool get isAuthenticated => _token != null;
  String? get rol => _rol;
  String? get token => _token;
  String? get username => _username;

  // Llamar esto en el arranque de la app para restaurar la sesión guardada
  Future<void> cargarSesion() async {
    _token = await _storage.read(key: 'token');
    _rol = await _storage.read(key: 'rol');
    _username = await _storage.read(key: 'username');
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    try {
      final response = await _dio.post('token/', data: {
        'username': username,
        'password': password,
      });

      _token = response.data['access'];
      _username = username;
      await _storage.write(key: 'token', value: _token);
      await _storage.write(key: 'username', value: username);

      // El endpoint /token/ no retorna el rol directamente; lo pedimos aparte si existe
      // Por ahora lo dejamos en null hasta tener el endpoint de perfil
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Error en login: $e");
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'rol');
    await _storage.delete(key: 'username');
    _token = null;
    _rol = null;
    _username = null;
    notifyListeners();
  }
}
