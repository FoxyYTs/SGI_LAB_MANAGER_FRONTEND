import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/sync/sync_service.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/widgets/cerrar_sesion.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUpAll(() {
    tmp = Directory.systemTemp.createTempSync('sgi_logout_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => tmp.path);
  });
  tearDownAll(() => tmp.deleteSync(recursive: true));

  group('mensajeOperacionesPendientes', () {
    test('plural, tipos sin repetir y en orden', () {
      expect(
        mensajeOperacionesPendientes(
            3, ['APROBAR_PRESTAMO', 'RECHAZAR_PRESTAMO', 'APROBAR_PRESTAMO']),
        'Tienes 3 operaciones sin sincronizar (aprobar préstamos, rechazar préstamos). '
        'Si cierras sesión se perderán.',
      );
    });

    test('singular y sin detalle si no se conocen los tipos', () {
      expect(mensajeOperacionesPendientes(1, const []),
          'Tienes 1 operación sin sincronizar. Si cierras sesión se perderán.');
    });
  });

  group('cerrarSesionVoluntaria con operaciones pendientes', () {
    late AuthProvider auth;
    late BuildContext ctx;
    final sync = SyncService.instance;

    // Mezcla async real (sqflite) con el reloj falso de testWidgets.
    Future<void> avanzar(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
    }

    Future<void> montar(WidgetTester tester) async {
      FlutterSecureStorage.setMockInitialValues({'token': 'x'});
      ApiClient.resetForTests();
      await tester.runAsync(() async {
        await sync.cerrarSesion(); // cola vacía
        // Sin token la cola no se procesa: la operación queda PENDIENTE
        // aunque se reintente (equivale a no tener red).
        await sync.encolar('APROBAR_PRESTAMO', {'prestamo_id': 1});
      });
      expect(sync.pending, 1);
      auth = AuthProvider();
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp(home: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        })),
      ));
    }

    testWidgets('Cancelar no cierra sesión ni borra la cola', (tester) async {
      await montar(tester);
      final resultado = cerrarSesionVoluntaria(ctx);
      await avanzar(tester);

      expect(find.textContaining('Tienes 1 operación sin sincronizar (aprobar préstamos)'),
          findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await avanzar(tester);

      expect(await tester.runAsync(() => resultado), isFalse);
      expect(sync.pending, 1);
    });

    testWidgets('Reintentar vuelve a sincronizar y vuelve a avisar', (tester) async {
      await montar(tester);
      final resultado = cerrarSesionVoluntaria(ctx);
      await avanzar(tester);
      await tester.tap(find.text('Reintentar sincronizar'));
      await avanzar(tester);

      expect(find.text('Operaciones sin sincronizar'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await avanzar(tester);
      expect(await tester.runAsync(() => resultado), isFalse);
    });

    testWidgets('Cerrar sesión igual cierra y descarta la cola', (tester) async {
      await montar(tester);
      final resultado = cerrarSesionVoluntaria(ctx);
      await avanzar(tester);
      await tester.tap(find.text('Cerrar sesión igual'));
      await avanzar(tester);

      expect(await tester.runAsync(() => resultado), isTrue);
      expect(sync.pending, 0);
      expect(auth.isAuthenticated, isFalse);
      expect(find.text('Operaciones sin sincronizar'), findsNothing);
    });
  });
}
