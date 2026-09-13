import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:frontend/main.dart' as app;

import 'test_config.dart';
import 'helpers/auth_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Préstamos', () {
    late FlutterExceptionHandler? originalOnError;

    setUp(() {
      originalOnError = FlutterError.onError;
    });

    tearDown(() {
      FlutterError.onError = originalOnError;
    });

    testWidgets('01 — Pantalla Movimientos carga la lista de préstamos',
        (tester) async {
      debugPrint('[TEST] Préstamos 01 — iniciando...');
      app.main();
      await loginComoAdmin(tester);

      debugPrint('[TEST] Préstamos 01 — navegando a Movimientos...');
      await tester.tap(find.text('Movimientos'));
      await tester.pump(kNetworkTimeout);
      await tester.pumpAndSettle();

      debugPrint('[TEST] Préstamos 01 — verificando contenido...');
      expect(find.text('Movimientos y Préstamos'), findsOneWidget);
      debugPrint('[TEST] Préstamos 01 — OK ✓');
    });

    testWidgets('02 — Botón Nuevo Préstamo abre el formulario',
        (tester) async {
      debugPrint('[TEST] Préstamos 02 — iniciando...');
      app.main();
      await loginComoAdmin(tester);

      debugPrint('[TEST] Préstamos 02 — navegando a Movimientos...');
      await tester.tap(find.text('Movimientos'));
      await tester.pump(kNetworkTimeout);
      await tester.pumpAndSettle();

      debugPrint('[TEST] Préstamos 02 — abriendo formulario...');
      await tester.tap(find.text('Nuevo Préstamo'));
      await tester.pumpAndSettle();

      debugPrint('[TEST] Préstamos 02 — verificando formulario...');
      expect(find.text('Registrar préstamo'), findsOneWidget);
      debugPrint('[TEST] Préstamos 02 — OK ✓');
    });

    testWidgets('03 — Formulario vacío muestra validación al intentar registrar',
        (tester) async {
      debugPrint('[TEST] Préstamos 03 — iniciando...');
      app.main();
      await loginComoAdmin(tester);

      debugPrint('[TEST] Préstamos 03 — navegando a Movimientos...');
      await tester.tap(find.text('Movimientos'));
      await tester.pump(kNetworkTimeout);
      await tester.pumpAndSettle();

      debugPrint('[TEST] Préstamos 03 — abriendo formulario vacío...');
      await tester.tap(find.text('Nuevo Préstamo'));
      await tester.pumpAndSettle();

      debugPrint('[TEST] Préstamos 03 — intentando registrar sin datos...');
      await tester.tap(find.text('Registrar préstamo'));
      await tester.pumpAndSettle();

      // Debe seguir en la misma pantalla (validación impide envío)
      debugPrint('[TEST] Préstamos 03 — verificando que permanece en pantalla...');
      expect(find.text('Movimientos y Préstamos'), findsOneWidget);
      debugPrint('[TEST] Préstamos 03 — OK ✓');
    });

    testWidgets('04 — Formulario completo registra un préstamo',
        (tester) async {
      debugPrint('[TEST] Préstamos 04 — iniciando...');
      app.main();
      await loginComoAdmin(tester);

      debugPrint('[TEST] Préstamos 04 — navegando a Movimientos...');
      await tester.tap(find.text('Movimientos'));
      await tester.pump(kNetworkTimeout);
      await tester.pumpAndSettle();

      debugPrint('[TEST] Préstamos 04 — abriendo formulario...');
      await tester.tap(find.text('Nuevo Préstamo'));
      await tester.pumpAndSettle();

      debugPrint('[TEST] Préstamos 04 — llenando campos del solicitante...');
      final campos = find.byType(TextFormField);
      await tester.enterText(campos.at(0), '1022002153');
      await tester.enterText(campos.at(1), 'Test Integration');
      await tester.enterText(campos.at(2), 'test@integration.com');

      debugPrint('[TEST] Préstamos 04 — seleccionando insumo...');
      await tester.tap(find.text('Seleccionar insumo...'));
      await tester.pumpAndSettle();

      final items = find.byType(ListTile);
      if (items.evaluate().isNotEmpty) {
        await tester.tap(items.first);
        await tester.pumpAndSettle();
      }

      debugPrint('[TEST] Préstamos 04 — registrando préstamo...');
      await tester.tap(find.text('Registrar préstamo'));
      await tester.pump(kNetworkTimeout);
      await tester.pumpAndSettle();

      debugPrint('[TEST] Préstamos 04 — verificando resultado...');
      expect(
        find.text('Préstamo registrado correctamente.').evaluate().isNotEmpty ||
        find.text('PENDIENTE').evaluate().isNotEmpty,
        isTrue,
      );
      debugPrint('[TEST] Préstamos 04 — OK ✓');
    });
  });
}
