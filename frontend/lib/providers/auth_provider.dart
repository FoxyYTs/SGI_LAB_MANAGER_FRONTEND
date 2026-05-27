import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/api/api_client.dart';
import '../core/sync/sync_service.dart';

/// Proveedor de estado de autenticación y permisos del usuario.
///
/// Gestiona el ciclo de vida de la sesión JWT:
/// - [login]: obtiene access + refresh tokens de `/api/token/` y carga permisos.
/// - [cargarSesion]: restaura la sesión desde `FlutterSecureStorage` al iniciar.
/// - [logout]: borra todos los datos de la sesión del almacenamiento seguro.
///
/// Los permisos se almacenan localmente (cache) y se recargan en cada login.
/// El acceso a funciones de la UI usa [can] con las constantes de [Perm].
class AuthProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    webOptions: WebOptions(
      dbName: 'sgi_lab_storage',
      publicKey: 'sgi_lab_key',
    ),
  );

  String?      _token;
  String?      _refreshToken;
  String?      _rol;
  String?      _username;
  Set<String>  _permisos = {};
  Timer?       _medianochTimer;

  bool        get isAuthenticated => _token != null;
  String?     get rol             => _rol;
  String?     get token           => _token;
  String?     get username        => _username;
  Set<String> get permisos        => _permisos;

  /// Verifica si el usuario tiene un permiso concreto.
  bool can(String permiso) => _permisos.contains(permiso);

  /// Restaura el estado de la sesión desde el almacenamiento seguro del dispositivo.
  /// Llamado en el arranque de la app antes de mostrar cualquier pantalla.
  /// En web, verifica que la sesión no haya expirado a medianoche.
  Future<void> cargarSesion() async {
    try {
      _token = await _storage.read(key: 'token');

      if (_token != null && kIsWeb) {
        // Sesiones web expiran a medianoche: comparar fecha de login con hoy.
        final fechaStr = await _storage.read(key: 'login_date');
        if (fechaStr != null) {
          final fechaLogin = DateTime.parse(fechaStr);
          final hoy = DateTime.now();
          final expiro = fechaLogin.year < hoy.year ||
              fechaLogin.month < hoy.month ||
              fechaLogin.day < hoy.day;
          if (expiro) {
            await _storage.deleteAll();
            notifyListeners();
            return;
          }
        }
      }

      if (_token != null) await SyncService.instance.init(_token);
      _refreshToken = await _storage.read(key: 'refresh_token');
      _rol          = await _storage.read(key: 'rol');
      _username     = await _storage.read(key: 'username');

      final permsJson = await _storage.read(key: 'permisos');
      if (permsJson != null) {
        _permisos = Set<String>.from(jsonDecode(permsJson) as List);
      }

      if (_token != null && kIsWeb) _programarCierreMedianoche();
    } catch (e) {
      // Si el almacenamiento seguro falla (Keystore no disponible, etc.),
      // la sesión queda vacía y el usuario verá la pantalla de login.
      debugPrint('[AuthProvider] Error restaurando sesión: $e');
      _token = _refreshToken = _rol = _username = null;
      _permisos = {};
    }
    notifyListeners();
  }

  /// Devuelve `null` si el login fue exitoso, o un mensaje de error legible.
  Future<String?> login(String username, String password) async {
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
      // Guardar la fecha de login para la expiración web a medianoche
      if (kIsWeb) {
        await _storage.write(key: 'login_date', value: DateTime.now().toIso8601String());
      }

      await _cargarPermisos();
      await SyncService.instance.init(_token);
      if (kIsWeb) _programarCierreMedianoche();

      notifyListeners();
      return null;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      debugPrint('DioException en login: type=${e.type} status=$code msg=${e.message}');
      if (code == 401) return 'Error 401: usuario o contraseña incorrectos';
      if (code != null) return 'Error HTTP $code: ${e.message ?? e.type.name}';
      return 'Error red (${e.type.name}): ${e.message ?? "sin detalles"}';
    } catch (e) {
      debugPrint('Error inesperado en login: $e');
      return 'Error inesperado: $e';
    }
  }

  Future<void> _cargarPermisos() async {
    try {
      final dio  = ApiClient.instance.authenticatedDio(_token);
      final resp = await dio.get('usuarios/mis-permisos/');
      final list = List<String>.from(resp.data['permisos'] as List);
      _permisos  = Set<String>.from(list);
      _rol       = resp.data['rol'] as String?;
      await _storage.write(key: 'permisos', value: jsonEncode(list));
      if (_rol != null) await _storage.write(key: 'rol', value: _rol);
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
    _medianochTimer?.cancel();
    _medianochTimer = null;
    try {
      await _storage.deleteAll();
    } catch (e) {
      debugPrint('[AuthProvider] Error al borrar storage en logout: $e');
    }
    _token    = null;
    _rol      = null;
    _username = null;
    _permisos = {};
    notifyListeners();
  }

  /// Programa un Timer que cierra la sesión web justo a la siguiente medianoche.
  /// Solo se llama en web; en móvil/escritorio la sesión no expira automáticamente.
  void _programarCierreMedianoche() {
    _medianochTimer?.cancel();
    final ahora      = DateTime.now();
    final medianoche = DateTime(ahora.year, ahora.month, ahora.day + 1);
    final espera     = medianoche.difference(ahora);
    _medianochTimer  = Timer(espera, () async {
      debugPrint('Sesión web expirada a medianoche — cerrando sesión.');
      await logout();
    });
  }
}
