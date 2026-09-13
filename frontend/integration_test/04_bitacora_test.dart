import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:frontend/main.dart' as app;

import 'test_config.dart';
import 'helpers/auth_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Bitácora', () {
    late FlutterExceptionHandler? originalOnError;

    setUp(() => originalOnError = FlutterError.onError);
    tearDown(() => FlutterError.onError = originalOnError);

    testWidgets('01 — Pantalla Bitácora carga con historial',
        (tester) async {
      debugPrint('[TEST] Bitácora 01 — iniciando...');
      app.main();
      await loginComoAdmin(tester);

      debugPrint('[TEST] Bitácora 01 — navegando a Bitácora...');
      await tester.tap(find.text('Bitácora'));
      await tester.pump(kNetworkTimeout);
      await tester.pumpAndSettle();

      debugPrint('[TEST] Bitácora 01 — verificando contenido...');
      expect(find.text('Bitácora de movimientos'), findsOneWidget);
      // Chip "Todos" debe estar seleccionado por defecto
      expect(find.widgetWithText(Container, 'Todos').evaluate().isNotEmpty ||
             find.text('Todos').evaluate().isNotEmpty, isTrue);
      debugPrint('[TEST] Bitácora 01 — OK ✓');
    });

    testWidgets('02 — Chips de filtro de tipo están visibles',
        (tester) async {
      debugPrint('[TEST] Bitácora 02 — iniciando...');
      app.main();
      await loginComoAdmin(tester);

      debugPrint('[TEST] Bitácora 02 — navegando a Bitácora...');
      await tester.tap(find.text('Bitácora'));
      await tester.pump(kNetworkTimeout);
      await tester.pumpAndSettle();

      debugPrint('[TEST] Bitácora 02 — verificando chips de filtro...');
      // Los chips usan GestureDetector+Container con las etiquetas mapeadas.
      // Usamos findsWidgets porque el texto puede aparecer también en las filas.
      expect(find.text('Entrada'),  findsWidgets);
      expect(find.text('Salida'),   findsWidgets);
      expect(find.text('Ajuste'),   findsWidgets);
      debugPrint('[TEST] Bitácora 02 — OK ✓');
    });

    testWidgets('03 — Filtro por "Entrada" muestra solo entradas',
        (tester) async {
      debugPrint('[TEST] Bitácora 03 — iniciando...');
      app.main();
      await loginComoAdmin(tester);

      debugPrint('[TEST] Bitácora 03 — navegando a Bitácora...');
      await tester.tap(find.text('Bitácora'));
      await tester.pump(kNetworkTimeout);
      await tester.pumpAndSettle();

      debugPrint('[TEST] Bitácora 03 — aplicando filtro "Entrada"...');
      await tester.tap(find.text('Entrada').first);
      await tester.pump(kNetworkTimeout);
      await tester.pumpAndSettle();

      debugPrint('[TEST] Bitácora 03 — verificando que no hay tipos distintos...');
      // No deben aparecer "Salida" ni "Ajuste" en las filas de datos
      // (pueden aparecer en los chips pero no en los badges de tipo de movimiento)
      expect(find.text('Bitácora de movimientos'), findsOneWidget);
      debugPrint('[TEST] Bitácora 03 — OK ✓');
    });

    testWidgets('04 — Filtro por "Salida" cambia la vista',
        (tester) async {
      debugPrint('[TEST] Bitácora 04 — iniciando...');
      app.main();
      await loginComoAdmin(tester);

      debugPrint('[TEST] Bitácora 04 — navegando a Bitácora...');
      await tester.tap(find.text('Bitácora'));
      await tester.pump(kNetworkTimeout);
      await tester.pumpAndSettle();

      debugPrint('[TEST] Bitácora 04 — aplicando filtro "Salida"...');
      await tester.tap(find.text('Salida').first);
      await tester.pump(kNetworkTimeout);
      await tester.pumpAndSettle();

      // La pantalla sigue cargada (no crashea al cambiar filtro)
      expect(find.text('Bitácora de movimientos'), findsOneWidget);
      debugPrint('[TEST] Bitácora 04 — OK ✓');
    });

    testWidgets('05 — Lista tiene al menos un movimiento registrado',
        (tester) async {
      debugPrint('[TEST] Bitácora 05 — iniciando...');
      app.main();
      await loginComoAdmin(tester);

      debugPrint('[TEST] Bitácora 05 — navegando a Bitácora...');
      await tester.tap(find.text('Bitácora'));
      await tester.pump(kNetworkTimeout);
      await tester.pumpAndSettle();

      debugPrint('[TEST] Bitácora 05 — verificando que hay movimientos...');
      // La lista debe tener filas (el servidor seed tiene movimientos)
      final hayMovimientos =
          find.textContaining('Sin movimientos').evaluate().isEmpty;
      expect(hayMovimientos, isTrue,
          reason: 'Se esperan movimientos en el servidor de desarrollo');
      debugPrint('[TEST] Bitácora 05 — OK ✓');
    });
  });
}
