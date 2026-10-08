import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_client.dart';

/// Respuesta simulada: status + cuerpo JSON, o una excepción de red.
class _R {
  final int status;
  final Object? body;
  final bool sinRed;
  const _R(this.status, [this.body]) : sinRed = false;
  const _R.sinRed() : status = 0, body = null, sinRed = true;
}

/// Adaptador HTTP falso: para cada path devuelve la siguiente respuesta de su
/// cola y registra lo que recibió.
class _FakeAdapter implements HttpClientAdapter {
  final Map<String, List<_R>> respuestas;
  final List<String> llamadas = [];
  final List<String?> auths = [];
  final List<int> bytesRecibidos = [];
  _FakeAdapter(this.respuestas);

  int veces(String path) => llamadas.where((p) => p == path).length;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? requestStream,
      Future<void>? cancelFuture) async {
    if (requestStream != null) {
      final chunks = await requestStream.toList();
      bytesRecibidos.add(chunks.fold<int>(0, (a, c) => a + c.length));
    }
    llamadas.add(o.path);
    auths.add(o.headers['Authorization'] as String?);
    final cola = respuestas[o.path];
    if (cola == null || cola.isEmpty) throw StateError('Sin respuesta para ${o.path}');
    final r = cola.length > 1 ? cola.removeAt(0) : cola.first;
    if (r.sinRed) {
      throw DioException.connectionError(requestOptions: o, reason: 'sin red');
    }
    return ResponseBody.fromString(jsonEncode(r.body ?? {}), r.status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ApiClient api;
  late _FakeAdapter http;
  late int logouts;
  late List<String> eventos;
  TokensPersistidos persistidos = (access: null, refresh: null);

  void preparar(Map<String, List<_R>> resp, {bool conPersistidos = false}) {
    ApiClient.resetForTests();
    api = ApiClient.instance;
    api.esperaRelecturaRefresh = Duration.zero;
    http = _FakeAdapter(resp);
    api.adapterParaTests = http;
    logouts = 0;
    eventos = [];
    api.setTokens(
      'access-viejo',
      'refresh-1',
      onRefreshed: (t) async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        eventos.add('access:$t');
      },
      onRefreshRotated: (r) async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        eventos.add('refresh:$r');
      },
      onLogout: () => logouts++,
      leerTokensPersistidos: conPersistidos ? () async => persistidos : null,
    );
  }

  // Ninguna petición debe quedar colgada: si el interceptor no llama al
  // handler, este timeout lo detecta.
  Future<Response> get(String path) =>
      api.authenticatedDio('access-viejo').get(path).timeout(const Duration(seconds: 5));

  test('401 → refresh OK → reintento con el token nuevo, rotación persistida antes', () async {
    preparar({
      'datos/': [const _R(401), const _R(200, {'ok': true})],
      'token/refresh/': [const _R(200, {'access': 'access-2', 'refresh': 'refresh-2'})],
    });
    final r = await get('datos/');
    expect(r.data['ok'], isTrue);
    expect(http.auths.last, 'Bearer access-2');
    expect(eventos, ['refresh:refresh-2', 'access:access-2']);
    expect(logouts, 0);
  });

  test('refresh rechazado → logout una vez y la petición termina con su 401 (no cuelga)', () async {
    preparar({
      'datos/': [const _R(401)],
      'token/refresh/': [const _R(401, {'code': 'token_not_valid'})],
    });
    await expectLater(
      get('datos/'),
      throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'status', 401)),
    );
    expect(logouts, 1);
    // Tras el logout ya no hay refresh: otro 401 se propaga sin bucles.
    await expectLater(get('datos/'), throwsA(isA<DioException>()));
    expect(http.veces('token/refresh/'), 1);
    expect(logouts, 1);
  });

  test('refresh sin red → NO cierra sesión y propaga el error de red', () async {
    preparar({
      'datos/': [const _R(401)],
      'token/refresh/': [const _R.sinRed()],
    });
    await expectLater(
      get('datos/'),
      throwsA(isA<DioException>()
          .having((e) => e.type, 'type', DioExceptionType.connectionError)
          .having((e) => e.requestOptions.path, 'path', 'datos/')),
    );
    expect(logouts, 0);
  });

  test('refresh con 503 → NO cierra sesión', () async {
    preparar({
      'datos/': [const _R(401)],
      'token/refresh/': [const _R(503)],
    });
    await expectLater(get('datos/'), throwsA(isA<DioException>()));
    expect(logouts, 0);
  });

  test('reintento que vuelve a dar error → se propaga el del reintento y no hay bucle', () async {
    preparar({
      'datos/': [const _R(401), const _R(403, {'detail': 'sin permiso'})],
      'token/refresh/': [const _R(200, {'access': 'access-2'})],
    });
    await expectLater(
      get('datos/'),
      throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'status', 403)),
    );
    expect(http.veces('token/refresh/'), 1);
  });

  test('reintento con 401 no vuelve a refrescar', () async {
    preparar({
      'datos/': [const _R(401)],
      'token/refresh/': [const _R(200, {'access': 'access-2'})],
    });
    await expectLater(get('datos/'), throwsA(isA<DioException>()));
    expect(http.veces('token/refresh/'), 1);
    expect(http.veces('datos/'), 2);
  });

  test('401 simultáneos comparten un único refresh', () async {
    preparar({
      'a/': [const _R(401), const _R(200)],
      'b/': [const _R(401), const _R(200)],
      'token/refresh/': [const _R(200, {'access': 'access-2', 'refresh': 'refresh-2'})],
    });
    await Future.wait([get('a/'), get('b/')]);
    expect(http.veces('token/refresh/'), 1);
  });

  test('FormData se reconstruye para el reintento tras refresh', () async {
    preparar({
      'subir/': [const _R(401), const _R(201)],
      'token/refresh/': [const _R(200, {'access': 'access-2'})],
    });
    final form = FormData.fromMap({
      'titulo': 'Informe',
      'archivo': MultipartFile.fromBytes(List.filled(64, 7), filename: 'a.pdf'),
    });
    final r = await api
        .authenticatedDio('access-viejo')
        .post('subir/', data: form)
        .timeout(const Duration(seconds: 5));
    expect(r.statusCode, 201);
    // Mismo cuerpo enviado dos veces (original + reintento).
    final subidas = http.bytesRecibidos.where((b) => b > 64).toList();
    expect(subidas.length, 2);
    expect(subidas[0], subidas[1]);
  });

  test('426 → marca requiereActualizacion y la petición termina con error', () async {
    preparar({'datos/': [const _R(426)]});
    expect(api.requiereActualizacion.value, isFalse);
    await expectLater(get('datos/'), throwsA(isA<DioException>()));
    expect(api.requiereActualizacion.value, isTrue);
  });

  test('426 en el Dio sin autenticar (refresco del arranque) también marca la bandera', () async {
    preparar({'token/refresh/': [const _R(426)]});
    await expectLater(
      api.dio.post('token/refresh/', data: {'refresh': 'x'}),
      throwsA(isA<DioException>()),
    );
    expect(api.requiereActualizacion.value, isTrue);
  });

  test('adopta tokens rotados por otro isolate sin llamar al refresh', () async {
    // access persistido con exp lejano (payload {"exp": 4102444800} = 2100-01-01)
    const accessBg = 'e30.eyJleHAiOjQxMDI0NDQ4MDB9.x';
    persistidos = (access: accessBg, refresh: 'refresh-bg');
    preparar({
      'datos/': [const _R(401), const _R(200)],
      'token/refresh/': [const _R(401)],
    }, conPersistidos: true);
    await get('datos/');
    expect(http.veces('token/refresh/'), 0);
    expect(http.auths.last, 'Bearer $accessBg');
    expect(logouts, 0);
  });

  test('refresh rechazado sin rotación ajena → logout', () async {
    persistidos = (access: 'access-viejo', refresh: 'refresh-1');
    preparar({
      'datos/': [const _R(401)],
      'token/refresh/': [const _R(401)],
    }, conPersistidos: true);
    await expectLater(get('datos/'), throwsA(isA<DioException>()));
    expect(logouts, 1);
  });
}
