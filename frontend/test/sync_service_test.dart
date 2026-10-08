import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/database/local_db.dart';
import 'package:frontend/core/sync/sync_service.dart';

/// Responde según el path; `null` = error de red.
class _FakeAdapter implements HttpClientAdapter {
  final Map<String, (int, Object?)?> respuestas;
  _FakeAdapter(this.respuestas);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    final r = respuestas[o.path];
    if (r == null) throw DioException.connectionError(requestOptions: o, reason: 'sin red');
    return ResponseBody.fromString(jsonEncode(r.$2 ?? {}), r.$1, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUpAll(() {
    tmp = Directory.systemTemp.createTempSync('sgi_sync_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => tmp.path);
  });
  tearDownAll(() => tmp.deleteSync(recursive: true));

  Future<List<Map<String, Object?>>> filas() async {
    final db = await LocalDb.instance;
    return db.query('sync_queue', orderBy: 'creado_en ASC');
  }

  test('cola: éxito idempotente, 4xx sin reintento, sin red queda pendiente; logout limpia', () async {
    ApiClient.resetForTests();
    ApiClient.instance.adapterParaTests = _FakeAdapter({
      'operaciones/prestamos/1/aprobar/': (400, {'error': 'El préstamo ya está en estado ACTIVO.'}),
      'operaciones/prestamos/2/aprobar/': (400, {'error': 'Debe agregar los ítems del préstamo antes de aprobarlo.'}),
      'operaciones/devoluciones/': null, // sin red
    });

    final sync = SyncService.instance;
    await sync.cerrarSesion(); // BD limpia
    // Encolar sin token: no se procesa todavía.
    await sync.encolar('APROBAR_PRESTAMO', {'prestamo_id': 1});
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await sync.encolar('APROBAR_PRESTAMO', {'prestamo_id': 2});
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await sync.encolar('DEVOLUCION', {'detalle': 9});
    expect(sync.pending, 3);

    await sync.init('access-1');
    await sync.sincronizarAhora();
    while (sync.syncing) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    final r = await filas();
    expect(r.map((f) => f['estado']).toList(), ['COMPLETADO', 'ERROR', 'PENDIENTE']);
    expect(r[1]['intentos'], 1);  // 4xx: ERROR al primer intento
    expect(r[2]['intentos'], 0);  // sin red: no gasta intentos
    expect(sync.syncing, isFalse);
    expect(sync.pending, 1);

    // Logout: la cola y las cachés del usuario desaparecen.
    final db = await LocalDb.instance;
    await db.rawInsert('INSERT INTO json_cache (clave, data, cached_at) VALUES (?, ?, ?)', ['k', '{}', 0]);
    await sync.cerrarSesion();
    expect(await filas(), isEmpty);
    expect(await db.query('json_cache'), isEmpty);
    expect(sync.pending, 0);
  });
}
