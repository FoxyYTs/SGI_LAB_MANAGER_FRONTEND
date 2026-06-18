import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:frontend/main.dart' as app;

import 'test_config.dart';
import 'helpers/auth_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Inventario', () {
    late FlutterExceptionHandler? originalOnError;

    setUp(() {
      originalOnError = FlutterError.onError;
    });

    tearDown(() {
      FlutterError.onError = originalOnError;
    });

    testWidgets('01 — La lista de insumos carga con al menos un ítem',
        (tester) async {
      debugPrint('[TEST] Inventario 01 — iniciando...');
      app.main();
      await loginComoAdmin(tester);

      debugPrint('[TEST] Inventario 01 — navegando a Inventario...');
      await tester.tap(find.text('Inventario'));
      await tester.pump(kNetworkTimeout);
      await tester.pumpAndSettle();

      debugPrint('[TEST] Inventario 01 — verificando contenido...');
      expect(find.text('Todos'), findsOneWidget);
      expect(find.textContaining('Críticos:'), findsOneWidget);
      debugPrint('[TEST] Inventario 01 — OK ✓');
    });

    testWidgets('02 — Filtro por tipo "Químico" cambia el header',
        (tester) async {
      debugPrint('[TEST] Inventario 02 — iniciando...');
      app.main();
      await loginComoAdmin(tester);

      debugPrint('[TEST] Inventario 02 — navegando a Inventario...');
      await tester.tap(find.text('Inventario'));
      await tester.pump(kNetworkTimeout);
      await tester.pumpAndSettle();

      debugPrint('[TEST] Inventario 02 — tocando chip "Químico"...');
      // Usar ChoiceChip para evitar ambigüedad con las filas de la tabla
      await tester.tap(find.widgetWithText(ChoiceChip, 'Químico'));
      await tester.pump(kAnimationDelay);
      await tester.pumpAndSettle();

      debugPrint('[TEST] Inventario 02 — verificando header...');
      expect(find.text('Inventario de Químicos'), findsWidgets);
      debugPrint('[TEST] Inventario 02 — OK ✓');
    });

    testWidgets('03 — Chip resumen de críticos está visible',
        (tester) async {
      debugPrint('[TEST] Inventario 03 — iniciando...');
      app.main();
      await loginComoAdmin(tester);

      debugPrint('[TEST] Inventario 03 — navegando a Inventario...');
      await tester.tap(find.text('Inventario'));
      await tester.pump(kNetworkTimeout);
      await tester.pumpAndSettle();

      debugPrint('[TEST] Inventario 03 — verificando chips...');
      expect(find.textContaining('Críticos:'), findsOneWidget);
      expect(find.textContaining('Bajos:'),    findsOneWidget);
      debugPrint('[TEST] Inventario 03 — OK ✓');
    });

    testWidgets('04 — Tap en la primera fila abre pantalla de detalle',
        (tester) async {
      debugPrint('[TEST] Inventario 04 — iniciando...');
      app.main();
      await loginComoAdmin(tester);

      debugPrint('[TEST] Inventario 04 — navegando a Inventario...');
      await tester.tap(find.text('Inventario'));
      await tester.pump(kNetworkTimeout);
      await tester.pumpAndSettle();

      debugPrint('[TEST] Inventario 04 — tocando primera fila...');
      final filas = find.byType(InkWell);
      expect(filas, findsWidgets);
      await tester.tap(filas.first);
      await tester.pump(kNetworkTimeout);
      await tester.pumpAndSettle();

      debugPrint('[TEST] Inventario 04 — verificando pantalla de detalle...');
      expect(
        find.textContaining('Stock').evaluate().isNotEmpty ||
        find.textContaining('Presentaciones').evaluate().isNotEmpty,
        isTrue,
      );
      debugPrint('[TEST] Inventario 04 — OK ✓');
    });
  });
}
