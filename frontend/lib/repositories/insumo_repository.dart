import 'package:flutter/foundation.dart';
import '../core/api/api_client.dart';
import '../core/database/local_db.dart';
import '../models/insumo_model.dart';

/// Repositorio de insumos con estrategia "servidor primero, caché offline".
///
/// En plataformas nativas (Linux/Windows/Android), cachea la respuesta del
/// servidor en SQLite. Si el servidor no responde, devuelve los datos del
/// caché local. En web, no hay caché y un error devuelve lista vacía.
class InsumoRepository {
  static const _entity = 'insumos';

  Future<List<Insumo>> fetchInsumos(String? token) async {
    try {
      final dio  = ApiClient.instance.authenticatedDio(token);
      final resp = await dio.get('inventario/lista/');
      final raw  = resp.data;
      final data = raw is List ? raw : ((raw as Map)['results'] as List? ?? []);
      final insumos = data.map((j) => Insumo.fromJson(j as Map<String, dynamic>)).toList();
      if (!kIsWeb) {
        try {
          await _cache(insumos);
        } catch (e) {
          debugPrint('[InsumoRepo] Error al cachear (no crítico): $e');
        }
      }
      return insumos;
    } catch (e) {
      debugPrint('[InsumoRepo] Sin red, cargando caché: $e');
      if (kIsWeb) return [];
      return _fromCache();
    }
  }

  Future<void> _cache(List<Insumo> insumos) async {
    final db    = await LocalDb.instance;
    final batch = db.batch();
    batch.delete('insumos_cache');
    for (final i in insumos) {
      batch.insert('insumos_cache', i.toLocal());
    }
    await batch.commit(noResult: true);

    await db.rawQuery(
      'INSERT OR REPLACE INTO sync_meta (entidad, last_sync) VALUES (?, ?)',
      [_entity, DateTime.now().millisecondsSinceEpoch],
    );
  }

  Future<List<Insumo>> _fromCache() async {
    final db   = await LocalDb.instance;
    final rows = await db.query('insumos_cache', where: 'activo = 1');
    return rows.map(Insumo.fromLocal).toList();
  }

  Future<DateTime?> lastSync() async {
    if (kIsWeb) return null;
    final db = await LocalDb.instance;
    final r  = await db.query('sync_meta', where: 'entidad = ?', whereArgs: [_entity]);
    if (r.isEmpty) return null;
    return DateTime.fromMillisecondsSinceEpoch(r.first['last_sync'] as int);
  }
}
