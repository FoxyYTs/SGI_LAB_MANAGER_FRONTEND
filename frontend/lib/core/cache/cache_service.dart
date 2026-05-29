import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../database/local_db.dart';

/// Caché genérico de respuestas JSON en SQLite.
/// En web no hay SQLite → siempre devuelve null y no guarda nada.
class CacheService {
  CacheService._();
  static final CacheService instance = CacheService._();

  /// Guarda [data] bajo [clave]. No hace nada en web.
  Future<void> set(String clave, dynamic data) async {
    if (kIsWeb) return;
    try {
      final db = await LocalDb.instance;
      await db.rawInsert(
        'INSERT OR REPLACE INTO json_cache (clave, data, cached_at) VALUES (?, ?, ?)',
        [clave, jsonEncode(data), DateTime.now().millisecondsSinceEpoch],
      );
    } catch (e) {
      debugPrint('[CacheService] Error guardando $clave: $e');
    }
  }

  /// Devuelve [data] y [cachedAt] para [clave], o null si no existe.
  Future<({dynamic data, DateTime cachedAt})?> get(String clave) async {
    if (kIsWeb) return null;
    try {
      final db   = await LocalDb.instance;
      final rows = await db.query('json_cache', where: 'clave = ?', whereArgs: [clave]);
      if (rows.isEmpty) return null;
      final row = rows.first;
      return (
        data:     jsonDecode(row['data'] as String),
        cachedAt: DateTime.fromMillisecondsSinceEpoch(row['cached_at'] as int),
      );
    } catch (e) {
      debugPrint('[CacheService] Error leyendo $clave: $e');
      return null;
    }
  }

  /// Formatea cuánto tiempo hace que se cacheó.
  static String formatEdad(DateTime cachedAt) {
    final diff = DateTime.now().difference(cachedAt);
    if (diff.inMinutes < 1)  return 'justo ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours   < 24) return 'hace ${diff.inHours} h';
    return 'hace ${diff.inDays} día(s)';
  }
}
