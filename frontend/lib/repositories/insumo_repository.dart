import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../core/api/api_client.dart';
import '../core/database/local_db.dart';
import '../models/insumo_model.dart';

/// Acceso a insumos: servidor primero, caché local como fallback offline.
class InsumoRepository {
  static const _entity = 'insumos';

  Future<List<Insumo>> fetchInsumos(String? token) async {
    try {
      final dio  = ApiClient.instance.authenticatedDio(token);
      final resp = await dio.get('inventario/lista/');
      final data = resp.data as List<dynamic>;
      final insumos = data.map((j) => Insumo.fromJson(j as Map<String, dynamic>)).toList();
      await _cache(insumos);
      return insumos;
    } catch (e) {
      debugPrint('[InsumoRepo] Sin red, cargando caché: $e');
      return _fromCache();
    }
  }

  Future<void> _cache(List<Insumo> insumos) async {
    final db    = await LocalDb.instance;
    final batch = db.batch();
    batch.delete('insumos_cache');
    for (final i in insumos) {
      batch.insert('insumos_cache', i.toLocal(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);

    await db.insert(
      'sync_meta',
      {'entidad': _entity, 'last_sync': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Insumo>> _fromCache() async {
    final db   = await LocalDb.instance;
    final rows = await db.query('insumos_cache', where: 'activo = 1');
    return rows.map(Insumo.fromLocal).toList();
  }

  /// Retorna cuándo se hizo la última sincronización, o null si nunca.
  Future<DateTime?> lastSync() async {
    final db = await LocalDb.instance;
    final r  = await db.query('sync_meta', where: 'entidad = ?', whereArgs: [_entity]);
    if (r.isEmpty) return null;
    return DateTime.fromMillisecondsSinceEpoch(r.first['last_sync'] as int);
  }
}
