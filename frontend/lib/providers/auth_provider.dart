import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/api/api_client.dart';
import '../core/sync/sync_service.dart';
import '../core/log_service.dart';
import '../services/notification_service.dart';
import '../services/background_tasks.dart';

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
    aOptions: AndroidOptions(),
    webOptions: WebOptions(
      dbName: 'sgi_lab_storage',
      publicKey: 'sgi_lab_key',
    ),
  );

  String?      _token;
  String?      _refreshToken;
  String?      _rol;
  String?      _username;
  String?      _fotoUrl;
  Set<String>  _permisos = {};
  Timer?       _medianochTimer;

  bool        get isAuthenticated => _token != null;
  String?     get rol             => _rol;
  String?     get token           => _token;
  String?     get username        => _username;
  String?     get fotoUrl         => _fotoUrl;
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
      _fotoUrl      = await _storage.read(key: 'foto_url');

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

      // Notificaciones y tareas de fondo solo en Android
      if (!kIsWeb && Platform.isAndroid) {
        await NotificationService.init();
        await NotificationService.requestPermission();
        await registerBackgroundTasks();
      }

      notifyListeners();
      return null;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      LogService.log('Login error: status=$code type=${e.type.name} msg=${e.message}');
      final friendly = _mensajeAmigable(e);
      if (LogService.devMode) {
        return '$friendly\n\n[DEV] HTTP ${code ?? "—"} · ${e.type.name}\n${e.message ?? ""}';
      }
      return friendly;
    } catch (e) {
      LogService.log('Login error inesperado: $e');
      if (LogService.devMode) return 'Error inesperado\n\n[DEV] $e';
      return 'Error inesperado. Intenta de nuevo.';
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
    // Cargar foto de perfil de forma independiente para no bloquear el login
    try {
      final dio  = ApiClient.instance.authenticatedDio(_token);
      final resp = await dio.get('usuarios/perfil/');
      final perfil = resp.data['perfil'] as Map<String, dynamic>?;
      final url = perfil?['foto_url'] as String?;
      _fotoUrl = (url != null && url.isNotEmpty) ? url : null;
      if (_fotoUrl != null) {
        await _storage.write(key: 'foto_url', value: _fotoUrl);
      } else {
        await _storage.delete(key: 'foto_url');
      }
    } catch (_) {
      // La foto es no-crítica; si falla no interrumpir el flujo
    }
  }

  /// Recarga solo la foto de perfil (llamar desde MiPerfilScreen tras subir foto).
  Future<void> recargarFoto() async {
    try {
      final dio  = ApiClient.instance.authenticatedDio(_token);
      final resp = await dio.get('usuarios/perfil/');
      final perfil = resp.data['perfil'] as Map<String, dynamic>?;
      final url = perfil?['foto_url'] as String?;
      _fotoUrl = (url != null && url.isNotEmpty) ? url : null;
      if (_fotoUrl != null) {
        await _storage.write(key: 'foto_url', value: _fotoUrl);
      } else {
        await _storage.delete(key: 'foto_url');
      }
      notifyListeners();
    } catch (_) {}
  }

  /// Fuerza recarga de permisos (útil después de que el admin modifique permisos).
  Future<void> recargarPermisos() async {
    await _cargarPermisos();
    notifyListeners();
  }

  Future<void> logout() async {
    _medianochTimer?.cancel();
    _medianochTimer = null;

    // Cancelar tareas de fondo al cerrar sesión (solo Android)
    if (!kIsWeb && Platform.isAndroid) await cancelBackgroundTasks();

    // Invalidar el refresh token en el servidor para que no pueda generar nuevos access tokens.
    // Fallo silencioso: si no hay red o el token ya expiró, la sesión local se limpia igual.
    if (_refreshToken != null) {
      try {
        await ApiClient.instance.dio.post(
          'token/blacklist/',
          data: {'refresh': _refreshToken},
        );
      } catch (_) {}
    }

    try {
      await _storage.deleteAll();
    } catch (e) {
      debugPrint('[AuthProvider] Error al borrar storage en logout: $e');
    }
    _token        = null;
    _refreshToken = null;
    _rol          = null;
    _username     = null;
    _fotoUrl      = null;
    _permisos     = {};
    notifyListeners();
  }

  static String _mensajeAmigable(DioException e) {
    final code = e.response?.statusCode;

    // Errores de autenticación
    if (code == 401) return 'Usuario o contraseña incorrectos.';
    if (code == 403) return 'No tienes permiso para acceder.';

    // Servidor caído o no disponible (Cloudflare + HTTP clásicos)
    if (code == 530 || code == 521 || code == 522 || code == 523 || code == 524) {
      return 'El servidor no está disponible.\nVerifica que el backend esté encendido e intenta de nuevo.';
    }
    if (code == 502 || code == 503 || code == 504) {
      return 'El servidor no está respondiendo.\nIntenta en unos momentos.';
    }
    if (code == 500) {
      return 'Error interno del servidor.\nContacta al administrador si el problema persiste.';
    }
    if (code != null) {
      return 'Error del servidor (código $code).\nIntenta más tarde.';
    }

    // Errores de red
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Tiempo de espera agotado.\nVerifica tu conexión a internet.';
      case DioExceptionType.connectionError:
        return 'No se pudo conectar al servidor.\nVerifica tu red o que el servidor esté activo.';
      default:
        return 'Error de conexión.\nVerifica tu internet e intenta de nuevo.';
    }
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
