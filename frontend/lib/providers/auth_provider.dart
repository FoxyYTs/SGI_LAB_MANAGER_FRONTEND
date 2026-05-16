import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/api/api_client.dart';
import '../core/sync/sync_service.dart';

class AuthProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage();

  String?      _token;
  String?      _refreshToken;
  String?      _rol;
  String?      _username;
  Set<String>  _permisos = {};

  bool        get isAuthenticated => _token != null;
  String?     get rol             => _rol;
  String?     get token           => _token;
  String?     get username        => _username;
  Set<String> get permisos        => _permisos;

  /// Verifica si el usuario tiene un permiso concreto.
  bool can(String permiso) => _permisos.contains(permiso);

  Future<void> cargarSesion() async {
    _token        = await _storage.read(key: 'token');
    if (_token != null) await SyncService.instance.init(_token);
    _refreshToken = await _storage.read(key: 'refresh_token');
    _rol          = await _storage.read(key: 'rol');
    _username     = await _storage.read(key: 'username');

    final permsJson = await _storage.read(key: 'permisos');
    if (permsJson != null) {
      _permisos = Set<String>.from(jsonDecode(permsJson) as List);
    }
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    try {
      final response = await ApiClient.instance.dio.post('token/', data: {
        'username': username,
        'password': password,
      });

      _token        = response.data['access'];
      _refreshToken = response.data['refresh'];
      _username     = username;

      await _storage.write(key: 'token',         value: _token);
      await _storage.write(key: 'refresh_token', value: _refreshToken);
      await _storage.write(key: 'username',       value: username);

      // Carga permisos y arranca sync
      await _cargarPermisos();
      await SyncService.instance.init(_token);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error en login: $e');
      return false;
    }
  }

  Future<void> _cargarPermisos() async {
    try {
      final dio  = ApiClient.instance.authenticatedDio(_token);
      final resp = await dio.get('usuarios/mis-permisos/');
      final list = List<String>.from(resp.data['permisos'] as List);
      _permisos  = Set<String>.from(list);
      await _storage.write(key: 'permisos', value: jsonEncode(list));
    } catch (e) {
      debugPrint('Error cargando permisos: $e');
      _permisos = {};
    }
  }

  /// Fuerza recarga de permisos (útil después de que el admin modifique permisos).
  Future<void> recargarPermisos() async {
    await _cargarPermisos();
    notifyListeners();
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    _token    = null;
    _rol      = null;
    _username = null;
    _permisos = {};
    notifyListeners();
  }
}
