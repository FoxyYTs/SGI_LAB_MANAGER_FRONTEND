import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:frontend/main.dart' as app;

import 'test_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Login', () {
    late FlutterExceptionHandler? originalOnError;

    setUp(() {
      originalOnError = FlutterError.onError;
    });

    tearDown(() {
      FlutterError.onError = originalOnError;
    });

    testWidgets('01 — Pantalla de login muestra campos y botón Ingresar',
        (tester) async {
      debugPrint('[TEST] Login 01 — iniciando...');
      app.main();
      await tester.pump(kUiReady);
      await tester.pumpAndSettle();

      debugPrint('[TEST] Login 01 — verificando campos...');
      expect(find.byType(TextField), findsWidgets);
      expect(find.text('Ingresar'), findsOneWidget);
      debugPrint('[TEST] Login 01 — OK ✓');
    });

    testWidgets('02 — Credenciales incorrectas no navegan al Dashboard',
        (tester) async {
      debugPrint('[TEST] Login 02 — iniciando...');
      app.main();
      await tester.pump(kUiReady);
      await tester.pumpAndSettle();

      debugPrint('[TEST] Login 02 — ingresando credenciales incorrectas...');
      await tester.enterText(find.byType(TextField).at(0), 'usuario_invalido');
      await tester.enterText(find.byType(TextField).at(1), 'clave_incorrecta');
      await tester.tap(find.text('Ingresar'));

      debugPrint('[TEST] Login 02 — esperando respuesta del servidor...');
      await tester.pump(kNetworkTimeout);
      await tester.pumpAndSettle();

      debugPrint('[TEST] Login 02 — verificando que NO navega...');
      expect(find.text('Inventario'), findsNothing);
      debugPrint('[TEST] Login 02 — OK ✓');
    });

    testWidgets('03 — Credenciales correctas navegan al Dashboard',
        (tester) async {
      debugPrint('[TEST] Login 03 — iniciando...');
      app.main();
      await tester.pump(kUiReady);
      await tester.pumpAndSettle();

      debugPrint('[TEST] Login 03 — ingresando credenciales correctas...');
      await tester.enterText(find.byType(TextField).at(0), kTestUser);
      await tester.enterText(find.byType(TextField).at(1), kTestPassword);
      await tester.tap(find.text('Ingresar'));

      debugPrint('[TEST] Login 03 — esperando navegación al Dashboard...');
      await tester.pump(kNetworkTimeout);
      await tester.pumpAndSettle();

      debugPrint('[TEST] Login 03 — verificando sidebar...');
      expect(find.text('Inventario'), findsOneWidget);
      expect(find.text('Inicio'),     findsOneWidget);
      debugPrint('[TEST] Login 03 — OK ✓');
    });
  });
}
