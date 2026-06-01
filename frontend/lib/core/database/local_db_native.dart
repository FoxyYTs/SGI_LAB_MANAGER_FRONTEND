import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
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

    // En desktop usamos %APPDATA%/SGI_LAB_MANAGER/ para evitar problemas de
    // permisos cuando la app está instalada en Program Files.
    final String dbDir;
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final support = await getApplicationSupportDirectory();
      dbDir = support.path;
    } else {
      dbDir = await getDatabasesPath();
    }

    final path = join(dbDir, 'sgi_lab.db');
    return openDatabase(path, version: 2, onCreate: _create, onUpgrade: _upgrade);
  }

  static Future<void> _create(Database db, int version) async {
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

    await db.execute('''
      CREATE TABLE json_cache (
        clave     TEXT PRIMARY KEY,
        data      TEXT NOT NULL,
        cached_at INTEGER NOT NULL
      )
    ''');
  }

  static Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS json_cache (
          clave     TEXT PRIMARY KEY,
          data      TEXT NOT NULL,
          cached_at INTEGER NOT NULL
        )
      ''');
    }
  }
}
