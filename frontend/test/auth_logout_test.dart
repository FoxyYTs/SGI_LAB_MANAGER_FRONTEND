import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/providers/auth_provider.dart';

class _FakeAdapter implements HttpClientAdapter {
  final Map<String, List<(int, Object?)>> respuestas;
  final List<String> llamadas = [];
  _FakeAdapter(this.respuestas);
  int veces(String p) => llamadas.where((x) => x == p).length;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    llamadas.add(o.path);
    final cola = respuestas[o.path] ?? [(200, {})];
    final r = cola.length > 1 ? cola.removeAt(0) : cola.first;
    return ResponseBody.fromString(jsonEncode(r.$2 ?? {}), r.$1, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = FlutterSecureStorage();

  late _FakeAdapter http;

  Future<AuthProvider> sesionRestaurada(Map<String, List<(int, Object?)>> resp) async {
    FlutterSecureStorage.setMockInitialValues({
      'token': 'access-1',
      'refresh_token': 'refresh-1',
      'username': 'monitor',
      'permisos': jsonEncode(['inventario.ver']),
    });
    ApiClient.resetForTests();
    http = _FakeAdapter(resp);
    ApiClient.instance.adapterParaTests = http;
    ApiClient.instance.esperaRelecturaRefresh = Duration.zero;
    final auth = AuthProvider();
    await auth.cargarSesion();
    return auth;
  }

  test('cargarSesion persiste el refresh rotado', () async {
    final auth = await sesionRestaurada({
      'token/refresh/': [(200, {'access': 'access-2', 'refresh': 'refresh-2'})],
    });
    expect(auth.isAuthenticated, isTrue);
    expect(auth.token, 'access-2');
    expect(await storage.read(key: 'refresh_token'), 'refresh-2');
  });

  test('cargarSesion con servidor caído (503) conserva la sesión', () async {
    final auth = await sesionRestaurada({'token/refresh/': [(503, null)]});
    expect(auth.isAuthenticated, isTrue);
    expect(auth.can('inventario.ver'), isTrue);
  });

  test('cargarSesion con refresh rechazado (401) cierra la sesión', () async {
    final auth = await sesionRestaurada({
      'token/refresh/': [(401, {'code': 'token_not_valid'})],
    });
    expect(auth.isAuthenticated, isFalse);
    expect(await storage.read(key: 'token'), isNull);
  });

  test('refresh rechazado en uso → un solo logout, sin bucle, la petición termina', () async {
    final auth = await sesionRestaurada({
      'token/refresh/': [
        (200, {'access': 'access-2', 'refresh': 'refresh-2'}),
        (401, {'code': 'token_not_valid'}),
      ],
      'datos/': [(401, null)],
    });
    expect(auth.isAuthenticated, isTrue);

    await expectLater(
      ApiClient.instance.authenticatedDio(auth.token).get('datos/')
          .timeout(const Duration(seconds: 5)),
      throwsA(isA<DioException>()),
    );
    // Dejar terminar el logout disparado por ApiClient.
    await auth.logout().timeout(const Duration(seconds: 5));

    expect(auth.isAuthenticated, isFalse);
    expect(await storage.read(key: 'token'), isNull);
    expect(http.veces('token/refresh/'), 2); // arranque + el rechazado
    expect(http.veces('token/blacklist/'), 1);
  });

  test('logout es reentrante: llamadas simultáneas comparten la ejecución', () async {
    final auth = await sesionRestaurada({
      'token/refresh/': [(200, {'access': 'access-2', 'refresh': 'refresh-2'})],
    });
    await Future.wait([auth.logout(), auth.logout(), auth.logout()])
        .timeout(const Duration(seconds: 5));
    expect(auth.isAuthenticated, isFalse);
    expect(http.veces('token/blacklist/'), 1);
  });
}
