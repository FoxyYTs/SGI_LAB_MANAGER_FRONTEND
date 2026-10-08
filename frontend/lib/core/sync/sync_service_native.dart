import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../api/api_client.dart';
import '../database/local_db.dart';
import 'sync_errores.dart';

/// Estados posibles de una entrada en la cola de sync.
enum SyncEstado { pendiente, completado, error }

/// Gestiona la cola de operaciones offline y las sincroniza cuando hay red.
class SyncService extends ChangeNotifier {
  static final SyncService instance = SyncService._();
  SyncService._();

  String? _token;
  bool    _online  = true;
  bool    _syncing = false;
  int     _pending = 0;

  bool get online  => _online;
  bool get syncing => _syncing;
  int  get pending => _pending;

  StreamSubscription<List<ConnectivityResult>>? _sub;

  /// Se incrementa en cada logout: una pasada iniciada con la sesión anterior
  /// deja de procesar filas en cuanto lo detecta.
  int           _generacion = 0;
  bool          _otraPasada = false;
  Future<void>? _pasadaActual;

  static const _kTimeoutOperacion     = Duration(seconds: 45);
  static const _kMaxDuracionPasada    = Duration(minutes: 3);
  static const _kRetencionCompletados = Duration(days: 7);

  // ── Inicialización ───────────────────────────────────────────
  /// Inicia la escucha de conectividad y procesa la cola si hay red.
  /// Llamar con el access token YA válido (tras `ApiClient.setTokens`).
  Future<void> init(String? token) async {
    _token = token;
    await _sub?.cancel();

    // Linux desktop: connectivity_plus needs NetworkManager via D-Bus which
    // is not available on all setups (Arch + iwd/systemd-networkd).
    // Skip entirely and assume online — desktop is always connected.
    if (Platform.isLinux) {
      _online = true;
    } else {
      try {
        _sub = Connectivity().onConnectivityChanged.listen(
          _onConnectivity,
          onError: (_) {},
        );
        final results = await Connectivity().checkConnectivity();
        _online = results.any((r) => r != ConnectivityResult.none);
      } catch (_) {
        _online = true;
      }
    }

    await _refreshPending();
    notifyListeners();
    if (_online) _processQueue();
  }

  /// Actualiza el token con el que se sincroniza (refresco automático) y,
  /// si hay pendientes, reintenta.
  void updateToken(String? token) {
    _token = token;
    if (_online && _pending > 0) _processQueue();
  }

  /// Cierra la sesión del servicio: corta cualquier pasada en curso y borra
  /// los datos locales del usuario (cola offline, cachés). Así el siguiente
  /// usuario que inicie sesión en el dispositivo no ejecuta operaciones del
  /// anterior con su identidad ni ve su caché offline.
  /// Mantiene la escucha de conectividad (la usa la pantalla de login).
  Future<void> cerrarSesion() async {
    _token = null;
    _generacion++;
    try {
      final db = await LocalDb.instance;
      for (final tabla in const ['sync_queue', 'json_cache', 'insumos_cache', 'sync_meta']) {
        await db.delete(tabla);
      }
      await _refreshPending();
    } catch (e) {
      debugPrint('[SyncService] Error limpiando datos locales: $e');
    }
    notifyListeners();
  }

  /// Intenta sincronizar los pendientes ahora y espera como máximo [timeout].
  /// Se usa antes de un logout voluntario para no perder operaciones offline.
  Future<void> sincronizarAhora({Duration timeout = const Duration(seconds: 10)}) async {
    if (!_online || _token == null || _pending == 0) return;
    try {
      if (_syncing) {
        _otraPasada = true;
        await _pasadaActual?.timeout(timeout);
      } else {
        await _processQueue().timeout(timeout);
      }
    } catch (_) {/* best-effort */}
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // ── Encolar operación ────────────────────────────────────────
  Future<void> encolar(String operacion, Map<String, dynamic> payload) async {
    final db = await LocalDb.instance;
    await db.insert('sync_queue', {
      'id':        _uuid(),
      'operacion': operacion,
      'payload':   jsonEncode(payload),
      'estado':    'PENDIENTE',
      'intentos':  0,
      'creado_en': DateTime.now().millisecondsSinceEpoch,
    });
    await _refreshPending();
    if (_online) _processQueue();
  }

  // ── Proceso de cola ──────────────────────────────────────────
  Future<void> _processQueue() {
    if (_token == null) return Future.value();
    if (_syncing) {
      // Otra pasada en curso: repetir al terminar para recoger lo recién encolado.
      _otraPasada = true;
      return _pasadaActual ?? Future.value();
    }
    return _pasadaActual = _procesar();
  }

  Future<void> _procesar() async {
    _syncing = true;
    _otraPasada = false;
    final generacion = _generacion;
    final inicio = DateTime.now();
    notifyListeners();

    try {
      final db  = await LocalDb.instance;
      final dio = ApiClient.instance.authenticatedDio(_token);

      final rows = await db.query(
        'sync_queue',
        where:     "estado = 'PENDIENTE'",
        orderBy:   'creado_en ASC',
      );

      for (final row in rows) {
        // La sesión cambió (logout) o la pasada ya tardó demasiado: parar.
        if (generacion != _generacion || _token == null) break;
        if (DateTime.now().difference(inicio) > _kMaxDuracionPasada) break;

        final id        = row['id'] as String;
        final operacion = row['operacion'] as String;

        ResultadoSync resultado;
        Object? error;
        try {
          final payload = jsonDecode(row['payload'] as String) as Map<String, dynamic>;
          await _ejecutar(operacion, payload, dio).timeout(_kTimeoutOperacion);
          resultado = ResultadoSync.exito;
        } catch (e) {
          error     = e;
          resultado = clasificarErrorSync(operacion, e);
        }
        if (generacion != _generacion) break;

        final intentos = (row['intentos'] as int) + 1;
        switch (resultado) {
          case ResultadoSync.exito:
            await db.update('sync_queue', {'estado': 'COMPLETADO'},
                where: 'id = ?', whereArgs: [id]);
          case ResultadoSync.reintentar:
            await db.update('sync_queue', {
              'intentos':  intentos,
              'estado':    intentos >= 3 ? 'ERROR' : 'PENDIENTE',
              'error_msg': '$error',
            }, where: 'id = ?', whereArgs: [id]);
          case ResultadoSync.fallido:
            await db.update('sync_queue', {
              'intentos':  intentos,
              'estado':    'ERROR',
              'error_msg': _describirError(error),
            }, where: 'id = ?', whereArgs: [id]);
          case ResultadoSync.detener:
            break;
        }
        if (resultado != ResultadoSync.exito) {
          debugPrint('[SyncService] $operacion → ${resultado.name}'
              '${resultado == ResultadoSync.detener ? '' : ' (intento $intentos)'}: $error');
        }
        if (resultado == ResultadoSync.detener) break;
      }
      await _purgarCompletados();
    } catch (e) {
      debugPrint('[SyncService] Error procesando la cola: $e');
    } finally {
      _syncing = false;
      _pasadaActual = null;
      await _refreshPending();
      notifyListeners();
    }
    if (_otraPasada && _online && _token != null && generacion == _generacion) {
      await _processQueue();
    }
  }

  /// Borra las filas COMPLETADO con más de [_kRetencionCompletados] (la
  /// tabla crecía indefinidamente). Se conservan las recientes para el
  /// historial y las ERROR para que se puedan revisar.
  Future<void> _purgarCompletados() async {
    final db = await LocalDb.instance;
    final limite = DateTime.now().subtract(_kRetencionCompletados).millisecondsSinceEpoch;
    await db.delete('sync_queue',
        where: "estado = 'COMPLETADO' AND creado_en < ?", whereArgs: [limite]);
  }

  static String _describirError(Object? e) {
    if (e is DioException && e.response != null) {
      return 'HTTP ${e.response!.statusCode}: ${e.response!.data}';
    }
    return '$e';
  }

  Future<void> _ejecutar(String op, Map<String, dynamic> p, dynamic dio) async {
    switch (op) {
      case 'PRESTAMO':
        await dio.post('operaciones/prestamos/', data: p);
      case 'DEVOLUCION':
        await dio.post('operaciones/devoluciones/', data: p);
      case 'AJUSTE_STOCK':
        final id = p.remove('insumo_id');
        await dio.patch('inventario/lista/$id/', data: p);
      case 'APROBAR_PRESTAMO':
        final id = p['prestamo_id'];
        await dio.post('operaciones/prestamos/$id/aprobar/');
      case 'RECHAZAR_PRESTAMO':
        final id = p['prestamo_id'];
        await dio.post('operaciones/prestamos/$id/rechazar/');
      default:
        throw Exception('Operación desconocida: $op');
    }
  }

  // ── Cola info ────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> historialCola() async {
    final db = await LocalDb.instance;
    return db.query('sync_queue', orderBy: 'creado_en DESC', limit: 50);
  }

  Future<void> _refreshPending() async {
    try {
      final db = await LocalDb.instance;
      final r  = await db.rawQuery("SELECT COUNT(*) AS n FROM sync_queue WHERE estado='PENDIENTE'");
      _pending = Sqflite.firstIntValue(r) ?? 0;
    } catch (e) {
      // BD local no disponible: no romper login/arranque por el contador.
      debugPrint('[SyncService] No se pudo contar pendientes: $e');
    }
  }

  // ── Conectividad ─────────────────────────────────────────────
  void _onConnectivity(List<ConnectivityResult> results) {
    final wasOnline = _online;
    _online = results.any((r) => r != ConnectivityResult.none);
    if (!wasOnline && _online) _processQueue();
    notifyListeners();
  }

  // ── Utilidades ───────────────────────────────────────────────
  String _uuid() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).join();
    return '${h.substring(0,8)}-${h.substring(8,12)}-${h.substring(12,16)}-${h.substring(16,20)}-${h.substring(20)}';
  }
}
