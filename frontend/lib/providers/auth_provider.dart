import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding, WidgetsBindingObserver, AppLifecycleState;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
/// Los permisos se almacenan localmente (cache) y se recargan en cada login,
/// y también cada vez que la app vuelve a primer plano (ver
/// [didChangeAppLifecycleState]) — así un cambio de permisos hecho por un
/// ADMIN desde otra sesión se refleja sin necesitar cerrar sesión.
/// El acceso a funciones de la UI usa [can] con las constantes de [Perm].
class AuthProvider with ChangeNotifier, WidgetsBindingObserver {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
    webOptions: WebOptions(
      dbName: 'sgi_lab_storage',
      publicKey: 'sgi_lab_key',
    ),
  );

  AuthProvider() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Al volver a primer plano, refresca permisos/rol/hace_turnos_monitor
  /// desde el servidor — cubre el caso de que otro ADMIN haya cambiado algo
  /// mientras la app estaba en segundo plano, sin exigir logout manual.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && isAuthenticated) {
      recargarPermisos();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _medianochTimer?.cancel();
    _fcmRefreshSub?.cancel();
    super.dispose();
  }

  String?      _token;
  String?      _refreshToken;
  String?      _rol;
  bool         _haceTurnosMonitor = false;
  String?      _username;
  String?      _fotoUrl;
  Set<String>  _permisos = {};
  Timer?       _medianochTimer;
  Future<void>? _logoutEnCurso;
  StreamSubscription<String>? _fcmRefreshSub;

  bool        get isAuthenticated     => _token != null;
  String?     get rol                 => _rol;
  /// Cumple turnos de monitor, independiente del rol — ver
  /// Perfil.hace_turnos_monitor en el backend. Un ADMIN/LAB que también
  /// monitorea tiene esto en `true` sin necesitar rol == 'MONITOR'.
  bool        get haceTurnosMonitor   => _haceTurnosMonitor;
  String?     get token               => _token;
  String?     get username            => _username;
  String?     get fotoUrl             => _fotoUrl;
  Set<String> get permisos            => _permisos;

  /// Verifica si el usuario tiene un permiso concreto.
  bool can(String permiso) => _permisos.contains(permiso);

  /// Sesiones web: expiran a la medianoche del día de login. Una sesión sin
  /// `login_date` (o con una fecha ilegible) se considera expirada: son las
  /// guardadas antes de que existiera la expiración y, si no, no expirarían
  /// nunca. Tras el logout, el siguiente login ya guarda la fecha, así que
  /// esto fuerza el cierre una sola vez.
  @visibleForTesting
  static bool sesionWebExpirada(String? loginDate, DateTime ahora) {
    final fecha = loginDate == null ? null : DateTime.tryParse(loginDate);
    if (fecha == null) return true;
    final diaLogin = DateTime(fecha.year, fecha.month, fecha.day);
    final hoy      = DateTime(ahora.year, ahora.month, ahora.day);
    return diaLogin.isBefore(hoy);
  }

  /// Restaura el estado de la sesión desde el almacenamiento seguro del dispositivo.
  /// Llamado en el arranque de la app antes de mostrar cualquier pantalla.
  /// En web, verifica que la sesión no haya expirado a medianoche.
  Future<void> cargarSesion() async {
    try {
      _token = await _storage.read(key: 'token');

      if (_token != null && kIsWeb &&
          sesionWebExpirada(await _storage.read(key: 'login_date'), DateTime.now())) {
        // Antes solo se borraba el storage y `_token` quedaba en memoria:
        // la app seguía "autenticada" con un token sin refresh. Se pasa por
        // logout() para invalidar también el refresh en el servidor.
        LogService.log('Sesión web expirada o sin fecha de login — cerrando sesión.');
        _refreshToken = await _storage.read(key: 'refresh_token');
        await logout(sesionExpirada: true);
        return;
      }

      _refreshToken      = await _storage.read(key: 'refresh_token');
      _rol               = await _storage.read(key: 'rol');
      _haceTurnosMonitor = (await _storage.read(key: 'hace_turnos_monitor')) == 'true';
      _username          = await _storage.read(key: 'username');
      _fotoUrl           = await _storage.read(key: 'foto_url');

      final permsJson = await _storage.read(key: 'permisos');
      if (permsJson != null) {
        _permisos = Set<String>.from(jsonDecode(permsJson) as List);
      }

      if (_token != null && _refreshToken != null) {
        // Android: refrescar proactivamente al arrancar para obtener tokens frescos.
        // Solo un rechazo del servidor de autenticación (401 / 400 de simplejwt)
        // cierra la sesión; red caída, 5xx, 52x de Cloudflare, 429 o 426
        // (versión obsoleta, ver ApiClient.requiereActualizacion) conservan la
        // sesión cacheada.
        if (!kIsWeb) {
          try {
            final resp = await ApiClient.instance.dio.post(
              'token/refresh/',
              data: {'refresh': _refreshToken},
            );
            final newRefresh = resp.data['refresh'] as String?;
            if (newRefresh != null) {
              // Primero el refresh: el anterior ya quedó blacklisteado.
              _refreshToken = newRefresh;
              await _storage.write(key: 'refresh_token', value: _refreshToken);
            }
            _token = resp.data['access'] as String;
            await _storage.write(key: 'token', value: _token);
          } on DioException catch (e) {
            if (esRechazoDeRefresh(e.response?.statusCode, e.response?.data) &&
                !await _otroIsolateRotoElRefresh()) {
              LogService.log('Sesión guardada rechazada por el servidor '
                  '(HTTP ${e.response?.statusCode}) — cerrando sesión.');
              await logout(sesionExpirada: true);
              return;
            }
            LogService.log('Refresco al arrancar falló (${e.type.name} '
                '${e.response?.statusCode ?? ''}) — se usa el token cacheado.');
          }
        }

        _configurarApiClient();
      }

      // Tras setTokens: si la cola recibe un 401, el interceptor ya puede refrescar.
      if (_token != null) await SyncService.instance.init(_token);

      if (_token != null && kIsWeb) _programarCierreMedianoche();
    } catch (e) {
      // Si el almacenamiento seguro falla (Keystore no disponible, etc.),
      // la sesión queda vacía y el usuario verá la pantalla de login.
      debugPrint('[AuthProvider] Error restaurando sesión: $e');
      ApiClient.instance.clearTokens();
      _limpiarEstadoEnMemoria();
    }
    notifyListeners();
  }

  /// La tarea de Workmanager (otro isolate) también refresca y rota el
  /// refresh token. Si el servidor rechazó el nuestro, comprobar si es porque
  /// ese isolate lo acaba de rotar: en tal caso adoptar los tokens guardados.
  Future<bool> _otroIsolateRotoElRefresh() async {
    final usado = _refreshToken;
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final guardado = await _storage.read(key: 'refresh_token');
    if (guardado == null || guardado == usado) return false;
    _refreshToken = guardado;
    _token = await _storage.read(key: 'token') ?? _token;
    LogService.log('Refresh rotado por la tarea de fondo — se adoptan los tokens guardados.');
    return true;
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
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      LogService.log('Login error: status=$code type=${e.type.name} msg=${e.message}');
      final friendly = _mensajeAmigable(e);
      if (LogService.devMode) {
        return '$friendly\n\n[DEV] HTTP ${code ?? "—"} · ${e.type.name}\n${e.message ?? ""}';
      }
      return friendly;
    } catch (e) {
      // Fallo guardando la sesión (Keystore, etc.): no dejar media sesión.
      LogService.log('Login error inesperado: $e');
      _limpiarEstadoEnMemoria();
      if (LogService.devMode) return 'Error inesperado\n\n[DEV] $e';
      return 'Error inesperado. Intenta de nuevo.';
    }

    _configurarApiClient();
    await _cargarPermisos();
    await SyncService.instance.init(_token);
    if (kIsWeb) _programarCierreMedianoche();

    notifyListeners();

    // Notificaciones, tareas de fondo y FCM: opcionales — un fallo aquí no
    // invalida un login que ya fue exitoso.
    await iniciarServiciosDispositivo();
    return null;
  }

  /// Registra en ApiClient los tokens actuales y los callbacks de refresco.
  void _configurarApiClient() {
    ApiClient.instance.setTokens(
      _token!,
      _refreshToken!,
      onRefreshed:           _actualizarToken,
      onLogout:              () => logout(sesionExpirada: true),
      onRefreshRotated:      _actualizarRefreshToken,
      leerTokensPersistidos: _leerTokensPersistidos,
    );
  }

  Future<TokensPersistidos> _leerTokensPersistidos() async => (
        access:  await _storage.read(key: 'token'),
        refresh: await _storage.read(key: 'refresh_token'),
      );

  /// Notificaciones locales, tareas de Workmanager y token FCM (solo Android).
  /// Se llama tras login y tras restaurar la sesión al arrancar. Cada paso es
  /// best-effort e independiente.
  Future<void> iniciarServiciosDispositivo() async {
    if (kIsWeb || !Platform.isAndroid || !isAuthenticated) return;
    Future<void> paso(String nombre, Future<void> Function() f) async {
      try {
        await f();
      } catch (e) {
        LogService.log('[AuthProvider] $nombre falló: $e');
      }
    }

    await paso('NotificationService.init', NotificationService.init);
    await paso('requestPermission', NotificationService.requestPermission);
    await paso('registerBackgroundTasks', registerBackgroundTasks);
    // Sin await: getToken() puede tardar y no debe retrasar la UI.
    unawaited(paso('registrar FCM', _registrarFcmToken));
  }

  Future<void> _cargarPermisos() async {
    try {
      final dio  = ApiClient.instance.authenticatedDio(_token);
      final resp = await dio.get('usuarios/mis-permisos/');
      final list = List<String>.from(resp.data['permisos'] as List);
      _permisos          = Set<String>.from(list);
      _rol               = resp.data['rol'] as String?;
      _haceTurnosMonitor = resp.data['hace_turnos_monitor'] as bool? ?? false;
      await _storage.write(key: 'permisos', value: jsonEncode(list));
      if (_rol != null) await _storage.write(key: 'rol', value: _rol);
      await _storage.write(
        key: 'hace_turnos_monitor',
        value: _haceTurnosMonitor.toString(),
      );
    } catch (e) {
      debugPrint('Error cargando permisos: $e');
      // Sin red / servidor caído: conservar los permisos que ya teníamos
      // (si no, al volver a primer plano offline desaparecerían los menús).
      // Solo un rechazo explícito de credenciales/permiso los vacía.
      final code = e is DioException ? e.response?.statusCode : null;
      if (code == 401 || code == 403) _permisos = {};
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

  /// Registra el token FCM del dispositivo en el backend y escucha rotaciones.
  /// Idempotente: solo mantiene una suscripción a `onTokenRefresh`.
  Future<void> _registrarFcmToken() async {
    try {
      await _fcmRefreshSub?.cancel();
      _fcmRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(_enviarFcmToken);
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) await _enviarFcmToken(fcmToken);
    } catch (e) {
      debugPrint('[AuthProvider] Error registrando FCM token: $e');
    }
  }

  Future<void> _enviarFcmToken(String fcmToken) async {
    if (_token == null) return;
    try {
      final dio = ApiClient.instance.authenticatedDio(_token);
      await dio.post('usuarios/fcm-token/', data: {'token': fcmToken});
      debugPrint('[AuthProvider] FCM token registrado.');
    } catch (e) {
      debugPrint('[AuthProvider] No se pudo registrar el FCM token: $e');
    }
  }

  /// Desvincula el dispositivo de las notificaciones push del usuario.
  /// Best-effort y sin refresco de token (se llama durante el logout):
  /// 1. DELETE en el backend con el access que haya (si ya caducó, falla).
  /// 2. `deleteToken()` invalida el token en Firebase, así que aunque el
  ///    paso 1 falle, el backend deja de poder entregarle push a este usuario.
  Future<void> _eliminarFcmToken(String? access) async {
    await _fcmRefreshSub?.cancel();
    _fcmRefreshSub = null;
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken()
          .timeout(const Duration(seconds: 5));
      if (fcmToken != null && access != null) {
        await ApiClient.instance
            .dioSinRefresco(access)
            .delete('usuarios/fcm-token/', data: {'token': fcmToken});
      }
    } catch (e) {
      debugPrint('[AuthProvider] No se pudo eliminar el FCM token en el backend: $e');
    }
    try {
      await FirebaseMessaging.instance.deleteToken().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[AuthProvider] Error en FirebaseMessaging.deleteToken: $e');
    }
  }

  /// Callback invocado por ApiClient cuando obtiene un nuevo access token.
  Future<void> _actualizarToken(String newToken) async {
    _token = newToken;
    SyncService.instance.updateToken(newToken);
    await _storage.write(key: 'token', value: newToken);
    debugPrint('[AuthProvider] Access token actualizado por refresco automático.');
  }

  /// Callback invocado cuando ROTATE_REFRESH_TOKENS rota el refresh token.
  /// Persiste el nuevo refresh token para que el siguiente arranque lo use.
  Future<void> _actualizarRefreshToken(String newRefresh) async {
    _refreshToken = newRefresh;
    await _storage.write(key: 'refresh_token', value: newRefresh);
    debugPrint('[AuthProvider] Refresh token actualizado por rotación.');
  }

  /// Reemplaza el par de tokens de la sesión actual. Lo usa MiPerfilScreen
  /// tras cambiar la contraseña: el backend pone en la blacklist todos los
  /// refresh tokens del usuario (cierra las demás sesiones) y devuelve un
  /// par nuevo para este dispositivo — sin adoptarlo, el siguiente refresco
  /// fallaría y la sesión se cerraría.
  Future<void> reemplazarTokens(String access, String refresh) async {
    _token        = access;
    _refreshToken = refresh;
    await _storage.write(key: 'token',         value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
    ApiClient.instance.setTokens(
      access,
      refresh,
      onRefreshed:      _actualizarToken,
      onLogout:         () => logout(),
      onRefreshRotated: _actualizarRefreshToken,
    );
    notifyListeners();
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

  /// Cierra la sesión. Reentrante: llamadas concurrentes (botón + refresh
  /// rechazado + medianoche web) comparten la misma ejecución.
  ///
  /// [sesionExpirada] = la llamó ApiClient/arranque porque el servidor rechazó
  /// el refresh: no se intenta sincronizar la cola (no hay credenciales).
  ///
  /// [sincronizarAntes] = false cuando el usuario ya intentó sincronizar y
  /// eligió "Cerrar sesión igual" en el aviso de operaciones pendientes (ver
  /// widgets/cerrar_sesion.dart): no tiene sentido esperar otros 10 s.
  Future<void> logout({bool sesionExpirada = false, bool sincronizarAntes = true}) {
    return _logoutEnCurso ??= _logout(sesionExpirada, sincronizarAntes)
        .whenComplete(() => _logoutEnCurso = null);
  }

  /// Intenta subir ya las operaciones offline pendientes (máx. 10 s) y
  /// devuelve cuántas siguen sin sincronizar. Siempre 0 en web (sin cola).
  /// Lo usa el botón de cerrar sesión para avisar antes de perderlas.
  Future<int> sincronizarPendientes() async {
    await SyncService.instance.sincronizarAhora();
    return SyncService.instance.pending;
  }

  Future<void> _logout(bool sesionExpirada, bool sincronizarAntes) async {
    _medianochTimer?.cancel();
    _medianochTimer = null;

    // Logout voluntario con red: intentar subir las operaciones offline
    // pendientes antes de borrarlas junto con el resto de datos locales.
    if (!sesionExpirada && sincronizarAntes) {
      await SyncService.instance.sincronizarAhora();
    }

    final access  = _token;
    final refresh = _refreshToken;

    // Lo primero: cortar el refresco automático. A partir de aquí ningún 401
    // (p. ej. del DELETE de FCM con el access caducado) puede disparar otro
    // refresh ni otro logout.
    ApiClient.instance.clearTokens();
    SyncService.instance.updateToken(null);

    final online = SyncService.instance.online;
    await Future.wait([
      // Cancelar tareas de fondo y desvincular FCM (solo Android)
      if (!kIsWeb && Platform.isAndroid) ...[
        _ignorarErrores(cancelBackgroundTasks()),
        _eliminarFcmToken(online ? access : null),
      ],
      // Invalidar el refresh token en el servidor para que no pueda generar
      // nuevos access tokens. Best-effort: sin red o ya expirado, se limpia
      // igual la sesión local.
      if (refresh != null && online)
        _ignorarErrores(ApiClient.instance
            .dioSinRefresco(null)
            .post('token/blacklist/', data: {'refresh': refresh})),
    ]);

    // Cola offline y cachés del usuario: no deben sobrevivir al logout.
    await SyncService.instance.cerrarSesion();

    try {
      await _storage.deleteAll();
    } catch (e) {
      debugPrint('[AuthProvider] Error al borrar storage en logout: $e');
    }
    _limpiarEstadoEnMemoria();
    notifyListeners();
  }

  static Future<void> _ignorarErrores(Future<dynamic> f) async {
    try {
      await f;
    } catch (e) {
      debugPrint('[AuthProvider] (logout best-effort) $e');
    }
  }

  void _limpiarEstadoEnMemoria() {
    _token             = null;
    _refreshToken      = null;
    _rol               = null;
    _haceTurnosMonitor = false;
    _username          = null;
    _fotoUrl           = null;
    _permisos          = {};
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
