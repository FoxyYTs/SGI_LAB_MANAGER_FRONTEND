import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Singleton SQLite local — persiste datos offline y cola de sync.
class LocalDb {
  static Database? _db;

  static Future<Database> get instance async => _db ??= await _open();

  static Future<Database> _open() async {
    if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final path = join(await getDatabasesPath(), 'sgi_lab.db');
    return openDatabase(path, version: 1, onCreate: _create);
  }

  static Future<void> _create(Database db, int _) async {
    await db.execute('''
      CREATE TABLE insumos_cache (
        id         TEXT PRIMARY KEY,
        nombre     TEXT NOT NULL,
        tipo       TEXT NOT NULL,
        ubicacion  TEXT,
        unidad     TEXT,
        stock      REAL NOT NULL DEFAULT 0,
        stock_min  REAL NOT NULL DEFAULT 0,
        semaforo   TEXT NOT NULL DEFAULT 'VERDE',
        activo     INTEGER NOT NULL DEFAULT 1,
        cached_at  INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_queue (
        id          TEXT PRIMARY KEY,
        operacion   TEXT NOT NULL,
        payload     TEXT NOT NULL,
        estado      TEXT NOT NULL DEFAULT 'PENDIENTE',
        intentos    INTEGER NOT NULL DEFAULT 0,
        error_msg   TEXT,
        creado_en   INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_meta (
        entidad   TEXT PRIMARY KEY,
        last_sync INTEGER NOT NULL
      )
    ''');
  }
}
