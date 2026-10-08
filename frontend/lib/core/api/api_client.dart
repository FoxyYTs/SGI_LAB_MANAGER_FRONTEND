import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../navigation_service.dart';
import '../../services/update_service.dart' show kAppVersion;
import 'token_utils.dart';

export 'token_utils.dart' show esRechazoDeRefresh;

/// URL completa del servidor (sin /api/ — se agrega automáticamente).
/// Producción: --dart-define=SERVER_URL=https://apisgi.foxyyts.qzz.io
const _kServerUrl = String.fromEnvironment('SERVER_URL', defaultValue: '');

/// IP del servidor para builds móviles/desktop en red local.
const _kServerIp = String.fromEnvironment('SERVER_IP', defaultValue: '');

/// Marca en `RequestOptions.extra` de una petición que ya se reintentó tras
/// refrescar el token — evita que un 401 del reintento dispare otro refresco.
const _kRetried = 'sgi_retried_after_refresh';

/// Tokens leídos del almacenamiento persistente (pueden haber sido rotados
/// por otro isolate, p. ej. la tarea de Workmanager).
typedef TokensPersistidos = ({String? access, String? refresh});

/// Cliente HTTP singleton para el backend SGI LAB MANAGER.
///
/// Resolución de URL base (orden de precedencia):
/// 1. `SERVER_URL` → URL completa (producción con HTTPS, Cloudflare Tunnel).
/// 2. `SERVER_IP`  → IP de red local en formato `http://IP:8000/api/`.
/// 3. Web sin defines → mismo host desde el que se sirvió la app.
/// 4. Desktop sin defines → localhost:8000.
///
/// Refresco automático de token:
/// Cuando una petición autenticada recibe HTTP 401, el interceptor intenta
/// obtener un nuevo access token con el refresh token (POST /api/token/refresh/).
/// - Si el refresco tiene éxito, la petición original se reintenta UNA vez con
///   el nuevo token (y el error del reintento, si lo hay, es el que se propaga).
/// - Si el servidor rechaza el refresh (ver [esRechazoDeRefresh]) se llama a
///   `onLogout` y la petición original termina con su 401.
/// - Si el refresco falla por red/5xx, NO se cierra sesión: la petición
///   original termina con ese error de red.
///
/// En todos los casos el interceptor termina llamando al `handler`: ninguna
/// petición queda colgada.
class ApiClient {
  static ApiClient? _instance;

  late final Dio    _dio;
  late final String baseUrl;

  // Estado del refresco de token
  String?            _refreshTokenStr;
  String?            _accessActual;
  Future<String?>?   _refreshFuture;        // evita múltiples refreshes simultáneos
  Future<void> Function(String newToken)?   _onTokenRefreshed;
  Future<void> Function(String newRefresh)? _onRefreshRotated;
  Future<TokensPersistidos> Function()?     _leerTokensPersistidos;
  void Function()?                          _onLogout;

  /// Pasa a `true` la primera vez que el servidor responde 426 (versión de la
  /// app por debajo de la mínima). `MyApp` lo escucha para mostrar la pantalla
  /// de actualización requerida — también cuando el 426 llega antes de
  /// `runApp` (refresco proactivo en `cargarSesion`), cuando todavía no hay
  /// navigator al que empujar la ruta.
  final ValueNotifier<bool> requiereActualizacion = ValueNotifier(false);

  HttpClientAdapter? _adapterTests;

  /// Tiempo que se espera antes de releer el almacenamiento cuando el servidor
  /// rechaza el refresh (por si otro isolate lo acaba de rotar).
  @visibleForTesting
  Duration esperaRelecturaRefresh = const Duration(milliseconds: 1500);

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

    _dio = _nuevoDio();

    // Interceptor global: maneja 426 Upgrade Required
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (e, handler) {
        if (e.response?.statusCode == 426) _marcarVersionObsoleta();
        handler.next(e);
      },
    ));
  }

  static ApiClient get instance => _instance ??= ApiClient._();

  /// Descarta el singleton (solo tests).
  @visibleForTesting
  static void resetForTests() => _instance = null;

  /// Sustituye el adaptador HTTP de todos los Dio que crea este cliente (tests).
  @visibleForTesting
  set adapterParaTests(HttpClientAdapter adapter) {
    _adapterTests = adapter;
    _dio.httpClientAdapter = adapter;
  }

  Dio get dio => _dio;

  Dio _nuevoDio({
    Map<String, dynamic>? headers,
    Duration connectTimeout = const Duration(seconds: 10),
    Duration receiveTimeout = const Duration(seconds: 15),
  }) {
    final d = Dio(BaseOptions(
      baseUrl:        baseUrl,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      headers:        {..._baseHeaders(), ...?headers},
    ));
    if (_adapterTests != null) d.httpClientAdapter = _adapterTests!;
    return d;
  }

  /// Registra los tokens y los callbacks necesarios para el refresco automático.
  /// Llamar desde AuthProvider tras login y tras restaurar sesión.
  ///
  /// Los callbacks son `async` y se esperan: el refresh rotado queda persistido
  /// antes de reintentar la petición original.
  void setTokens(
    String accessToken,
    String refreshToken, {
    required Future<void> Function(String newToken) onRefreshed,
    required void Function()                        onLogout,
    Future<void> Function(String newRefresh)?       onRefreshRotated,
    Future<TokensPersistidos> Function()?           leerTokensPersistidos,
  }) {
    _accessActual          = accessToken;
    _refreshTokenStr       = refreshToken;
    _onTokenRefreshed      = onRefreshed;
    _onRefreshRotated      = onRefreshRotated;
    _leerTokensPersistidos = leerTokensPersistidos;
    _onLogout              = onLogout;
  }

  /// Limpia el estado de tokens (al hacer logout). A partir de aquí un 401 ya
  /// no intenta refrescar: se propaga tal cual.
  void clearTokens() {
    _accessActual          = null;
    _refreshTokenStr       = null;
    _onTokenRefreshed      = null;
    _onRefreshRotated      = null;
    _leerTokensPersistidos = null;
    _onLogout              = null;
    _refreshFuture         = null;
  }

  /// Dio autenticado SIN interceptor de refresco y con timeouts cortos.
  /// Para llamadas best-effort durante el logout (borrar token FCM,
  /// blacklist), que no deben poder disparar otro refresh ni otro logout.
  Dio dioSinRefresco(String? token, {Duration timeout = const Duration(seconds: 5)}) {
    return _nuevoDio(
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
      connectTimeout: timeout,
      receiveTimeout: timeout,
    );
  }

  void _marcarVersionObsoleta() {
    if (requiereActualizacion.value) return;
    requiereActualizacion.value = true;
    // Si todavía no hay UI (arranque), MyApp mostrará la pantalla al construirse
    // porque escucha [requiereActualizacion].
    try {
      navigatorKey.currentState
          ?.pushNamedAndRemoveUntil('/actualizacion-requerida', (_) => false);
    } catch (e) {
      debugPrint('[ApiClient] No se pudo navegar a actualización requerida: $e');
    }
  }

  /// Intenta obtener un nuevo access token usando el refresh token.
  /// Si hay un refresco en curso, espera su resultado en lugar de lanzar otro.
  ///
  /// Devuelve el nuevo access, `null` si la sesión ya no es válida (y se llamó
  /// a `onLogout`) o lanza [DioException] si el fallo es transitorio.
  Future<String?> _tryRefresh() {
    return _refreshFuture ??=
        _doRefresh().whenComplete(() => _refreshFuture = null);
  }

  Future<String?> _doRefresh() async {
    var refresh = _refreshTokenStr;
    if (refresh == null) return null;

    // Otro isolate (Workmanager) pudo rotar los tokens: si el almacenamiento
    // tiene un refresh distinto, adoptarlo en vez de usar uno ya blacklisteado.
    final adoptado = await _adoptarTokensPersistidos(refresh);
    if (adoptado != null) return adoptado;
    refresh = _refreshTokenStr;
    if (refresh == null) return null;

    final Response resp;
    try {
      resp = await _dio.post('token/refresh/', data: {'refresh': refresh});
    } on DioException catch (e) {
      if (!esRechazoDeRefresh(e.response?.statusCode, e.response?.data)) {
        debugPrint('[ApiClient] Refresco fallido (transitorio): ${e.type.name} '
            '${e.response?.statusCode ?? ''} — se mantiene la sesión.');
        rethrow;
      }
      // Rechazado. Antes de cerrar sesión, comprobar si otro isolate rotó el
      // refresh justo a la vez (su escritura puede llegar un instante después).
      if (_leerTokensPersistidos != null) {
        await Future<void>.delayed(esperaRelecturaRefresh);
        final rescate = await _adoptarTokensPersistidos(refresh);
        if (rescate != null) return rescate;
      }
      if (_refreshTokenStr != refresh) return null; // la sesión cambió entretanto
      debugPrint('[ApiClient] Refresh rechazado por el servidor — cerrando sesión.');
      _sesionInvalida();
      return null;
    }

    if (_refreshTokenStr != refresh) {
      // logout/login mientras se refrescaba: no mezclar tokens de sesiones.
      return null;
    }
    final data       = resp.data;
    final newToken   = data is Map ? data['access'] as String? : null;
    if (newToken == null) {
      throw DioException(
        requestOptions: resp.requestOptions,
        response:       resp,
        error:          'Respuesta de token/refresh/ sin access token',
      );
    }
    // ROTATE_REFRESH_TOKENS=True: el endpoint devuelve también un nuevo refresh
    // token y blacklistea el anterior. Hay que persistirlo o el siguiente
    // refresh (o el siguiente arranque) fallará.
    final newRefresh = (data as Map)['refresh'] as String?;
    if (newRefresh != null) {
      _refreshTokenStr = newRefresh;
      await _llamarCallback(_onRefreshRotated, newRefresh);
    }
    _accessActual = newToken;
    await _llamarCallback(_onTokenRefreshed, newToken);
    debugPrint('[ApiClient] Token refrescado correctamente.');
    return newToken;
  }

  /// Si el almacenamiento tiene un refresh distinto de [usado], lo adopta.
  /// Devuelve el access a usar (el persistido si sigue vigente, o uno nuevo
  /// refrescado con el refresh adoptado) o `null` si no había nada que adoptar.
  Future<String?> _adoptarTokensPersistidos(String usado) async {
    final leer = _leerTokensPersistidos;
    if (leer == null) return null;
    TokensPersistidos persistidos;
    try {
      persistidos = await leer();
    } catch (e) {
      debugPrint('[ApiClient] No se pudieron leer tokens persistidos: $e');
      return null;
    }
    final pRefresh = persistidos.refresh;
    final pAccess  = persistidos.access;
    if (pRefresh == null || pRefresh == usado || _refreshTokenStr != usado) {
      return null;
    }
    debugPrint('[ApiClient] Adoptando tokens rotados por otro isolate.');
    _refreshTokenStr = pRefresh;
    await _llamarCallback(_onRefreshRotated, pRefresh);
    if (pAccess != null && !jwtExpiraPronto(pAccess)) {
      _accessActual = pAccess;
      await _llamarCallback(_onTokenRefreshed, pAccess);
      return pAccess;
    }
    // El access persistido también caducó: refrescar con el refresh adoptado.
    return _doRefresh();
  }

  Future<void> _llamarCallback(Future<void> Function(String)? cb, String v) async {
    if (cb == null) return;
    try {
      await cb(v);
    } catch (e) {
      debugPrint('[ApiClient] Error persistiendo token: $e');
    }
  }

  void _sesionInvalida() {
    final onLogout = _onLogout;
    clearTokens();
    onLogout?.call();
  }

  /// Devuelve un Dio con el header Authorization configurado.
  /// Incluye un interceptor que refresca el token automáticamente en caso de 401.
  Dio authenticatedDio(String? token) {
    final d = _nuevoDio(headers: {
      if (token != null) 'Authorization': 'Bearer $token',
    });

    d.interceptors.add(InterceptorsWrapper(
      onError: (e, handler) async {
        Object resultado;
        try {
          resultado = await _resolverError(d, e);
        } catch (err) {
          debugPrint('[ApiClient] Error inesperado en interceptor: $err');
          resultado = e;
        }
        if (resultado is Response) {
          handler.resolve(resultado);
        } else {
          handler.next(resultado as DioException);
        }
      },
    ));
    return d;
  }

  /// Decide cómo termina una petición fallida: devuelve una [Response] (se
  /// resuelve con ella) o un [DioException] (se propaga ese error).
  Future<Object> _resolverError(Dio d, DioException e) async {
    final status = e.response?.statusCode;
    if (status == 426) {
      _marcarVersionObsoleta();
      return e;
    }

    final opts = e.requestOptions;
    if (status != 401 || opts.extra[_kRetried] == true || _refreshTokenStr == null) {
      return e;
    }

    String? nuevo;
    final enviado = opts.headers['Authorization'];
    if (_accessActual != null && enviado != 'Bearer $_accessActual') {
      // Otra petición ya refrescó mientras esta viajaba con el token viejo.
      nuevo = _accessActual;
    } else {
      try {
        nuevo = await _tryRefresh();
      } on DioException catch (refreshErr) {
        // Fallo transitorio del refresco (red/5xx): sin logout; propagar ese
        // error, que describe mejor el problema que el 401 original.
        return refreshErr.copyWith(requestOptions: opts);
      }
    }
    if (nuevo == null) return e; // sesión cerrada: termina con su 401

    opts.extra[_kRetried] = true;
    opts.headers['Authorization'] = 'Bearer $nuevo';
    // Un FormData solo se puede enviar una vez: reconstruirlo para el reintento.
    if (opts.data is FormData) opts.data = (opts.data as FormData).clone();
    try {
      return await d.fetch(opts);
    } on DioException catch (retryErr) {
      return retryErr;
    } catch (retryErr) {
      return DioException(requestOptions: opts, error: retryErr);
    }
  }

  static Map<String, String> _baseHeaders() {
    if (kIsWeb) return {};
    return {'X-App-Version': kAppVersion};
  }
}
