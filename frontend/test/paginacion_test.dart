import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/paginacion.dart';

/// Adaptador falso: responde según `page` simulando la paginación de DRF.
class _FakeAdapter implements HttpClientAdapter {
  final dynamic Function(RequestOptions) responder;
  final List<Uri> peticiones = [];
  _FakeAdapter(this.responder);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    peticiones.add(options.uri);
    return ResponseBody.fromString(jsonEncode(responder(options)), 200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_FakeAdapter a) =>
    Dio(BaseOptions(baseUrl: 'http://x/api/'))..httpClientAdapter = a;

void main() {
  group('listaDeRespuesta', () {
    test('acepta lista plana', () {
      expect(listaDeRespuesta([{'id': 1}, {'id': 2}]).length, 2);
    });
    test('acepta respuesta paginada', () {
      final r = listaDeRespuesta({
        'count': 1, 'next': null, 'results': [{'id': 1}],
      });
      expect(r, [{'id': 1}]);
    });
    test('formas inesperadas devuelven lista vacía', () {
      expect(listaDeRespuesta(null), isEmpty);
      expect(listaDeRespuesta({'detail': 'x'}), isEmpty);
      expect(listaDeRespuesta('texto'), isEmpty);
    });
  });

  group('obtenerTodas', () {
    test('recorre todas las páginas y conserva los filtros', () async {
      final a = _FakeAdapter((o) {
        final page = int.tryParse('${o.queryParameters['page'] ?? 1}') ?? 1;
        return {
          'count': 5,
          'next': page < 3 ? 'http://otro-host/?page=${page + 1}' : null,
          'results': [
            for (var i = 0; i < (page < 3 ? 2 : 1); i++) {'p': page, 'i': i},
          ],
        };
      });
      final todos = await obtenerTodas(_dio(a), 'operaciones/prestamos/',
          queryParameters: {'estado': 'PENDIENTE'});
      expect(todos.length, 5);
      expect(a.peticiones.length, 3);
      for (final u in a.peticiones) {
        expect(u.host, 'x'); // nunca usa el host de `next`
        expect(u.queryParameters['estado'], 'PENDIENTE');
      }
    });

    test('lista plana: una sola petición', () async {
      final a = _FakeAdapter((_) => [{'id': 1}, {'id': 2}, {'id': 3}]);
      final todos = await obtenerTodas(_dio(a), 'academico/areas/');
      expect(todos.length, 3);
      expect(a.peticiones.length, 1);
    });

    test('respeta el tope de páginas', () async {
      final a = _FakeAdapter((_) => {
            'next': 'siempre', 'results': [{'id': 1}],
          });
      final todos = await obtenerTodas(_dio(a), 'x/', maxPaginas: 4);
      expect(todos.length, 4);
    });
  });

  test('obtenerPagina informa hayMas y total', () async {
    final a = _FakeAdapter((_) => {
          'count': 120, 'next': 'n', 'results': [{'id': 1}],
        });
    final p = await obtenerPagina(_dio(a), 'x/', pagina: 2);
    expect(p.hayMas, isTrue);
    expect(p.total, 120);
    expect(a.peticiones.single.queryParameters['page'], '2');
  });
}
