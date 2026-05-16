import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../api/api_client.dart';
import '../database/local_db.dart';

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

  // ── Inicialización ───────────────────────────────────────────
  Future<void> init(String? token) async {
    _token = token;
    _sub?.cancel();

    // connectivity_plus en Linux necesita NetworkManager via D-Bus.
    // Si no está disponible (Arch sin NM, systemd-networkd, iwd, etc.)
    // se asume online y se omite el listener — en escritorio siempre hay red.
    try {
      _sub = Connectivity().onConnectivityChanged.listen(_onConnectivity);
      final results = await Connectivity().checkConnectivity();
      _online = results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      _online = true;
    }

    await _refreshPending();
    if (_online) _processQueue();
  }

  void updateToken(String? token) {
    _token = token;
    if (_online && _pending > 0) _processQueue();
  }

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
  Future<void> _processQueue() async {
    if (_syncing || _token == null) return;
    _syncing = true;
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
        final id        = row['id'] as String;
        final operacion = row['operacion'] as String;
        final payload   = jsonDecode(row['payload'] as String) as Map<String, dynamic>;

        try {
          await _ejecutar(operacion, payload, dio);
          await db.update(
            'sync_queue',
            {'estado': 'COMPLETADO'},
            where: 'id = ?', whereArgs: [id],
          );
        } catch (e) {
          final intentos = (row['intentos'] as int) + 1;
          await db.update(
            'sync_queue',
            {
              'intentos':  intentos,
              'estado':    intentos >= 3 ? 'ERROR' : 'PENDIENTE',
              'error_msg': e.toString(),
            },
            where: 'id = ?', whereArgs: [id],
          );
          debugPrint('[SyncService] Error en $operacion (intento $intentos): $e');
        }
      }
    } finally {
      _syncing = false;
      await _refreshPending();
      notifyListeners();
    }
  }

  Future<void> _ejecutar(String op, Map<String, dynamic> p, dynamic dio) async {
    switch (op) {
      case 'PRESTAMO':
        await dio.post('operaciones/prestamos/', data: p);
      case 'DEVOLUCION':
        final id = p['prestamo_id'];
        await dio.post('operaciones/prestamos/$id/devolver/', data: p);
      case 'AJUSTE_STOCK':
        final id = p.remove('insumo_id');
        await dio.patch('inventario/lista/$id/', data: p);
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
    final db = await LocalDb.instance;
    final r  = await db.rawQuery("SELECT COUNT(*) AS n FROM sync_queue WHERE estado='PENDIENTE'");
    _pending = Sqflite.firstIntValue(r) ?? 0;
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
