import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:frontend/main.dart' as app;

import 'test_config.dart';
import 'helpers/auth_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('SGA', () {
    late FlutterExceptionHandler? originalOnError;

    setUp(() => originalOnError = FlutterError.onError);
    tearDown(() => FlutterError.onError = originalOnError);

    /// Navega a Inventario → filtra por Químico → abre la ficha SGA del primero.
    Future<bool> _abrirFichaSga(WidgetTester tester) async {
      debugPrint('[TEST] SGA — navegando a Inventario...');
      await tester.tap(find.text('Inventario'));
      await tester.pump(kNetworkTimeout);
      await tester.pumpAndSettle();

      debugPrint('[TEST] SGA — filtrando por Químico...');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Químico'));
      await tester.pump(kAnimationDelay);
      await tester.pumpAndSettle();

      debugPrint('[TEST] SGA — buscando botón Ver ficha SGA...');
      final btnSga = find.byTooltip('Ver ficha SGA');
      if (btnSga.evaluate().isEmpty) {
        debugPrint('[TEST] SGA — no hay químicos con botón SGA visible');
        return false;
      }

      debugPrint('[TEST] SGA — abriendo ficha SGA del primer químico...');
      await tester.tap(btnSga.first);
      await tester.pump(kNetworkTimeout);
      await tester.pumpAndSettle();
      return true;
    }

    testWidgets('01 — Botón "Ver ficha SGA" existe en la tabla de Químicos',
        (tester) async {
      debugPrint('[TEST] SGA 01 — iniciando...');
      app.main();
      await loginComoAdmin(tester);

      debugPrint('[TEST] SGA 01 — navegando a Inventario y filtrando...');
      await tester.tap(find.text('Inventario'));
      await tester.pump(kNetworkTimeout);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Químico'));
      await tester.pump(kAnimationDelay);
      await tester.pumpAndSettle();

      debugPrint('[TEST] SGA 01 — verificando botón SGA en tabla...');
      expect(find.byTooltip('Ver ficha SGA'), findsWidgets,
          reason: 'Debe haber al menos un químico con botón SGA');
      debugPrint('[TEST] SGA 01 — OK ✓');
    });

    testWidgets('02 — Pantalla SGA abre con las 3 pestañas',
        (tester) async {
      debugPrint('[TEST] SGA 02 — iniciando...');
      app.main();
      await loginComoAdmin(tester);

      final abierto = await _abrirFichaSga(tester);
      if (!abierto) {
        debugPrint('[TEST] SGA 02 — skip: sin datos SGA ✓');
        return;
      }

      debugPrint('[TEST] SGA 02 — verificando título y pestañas...');
      expect(find.text('Ficha SGA/GHS'), findsOneWidget);
      expect(find.text('Datos SGA'),     findsOneWidget);
      expect(find.text('Editar'),        findsOneWidget);
      expect(find.text('Colmena ARL'),   findsOneWidget);
      debugPrint('[TEST] SGA 02 — OK ✓');
    });

    testWidgets('03 — Pestaña "Datos SGA" muestra datos o mensaje vacío',
        (tester) async {
      debugPrint('[TEST] SGA 03 — iniciando...');
      app.main();
      await loginComoAdmin(tester);

      final abierto = await _abrirFichaSga(tester);
      if (!abierto) { debugPrint('[TEST] SGA 03 — skip ✓'); return; }

      debugPrint('[TEST] SGA 03 — verificando contenido de Datos SGA...');
      final sinDatos = find.textContaining('Sin datos SGA cargados').evaluate().isNotEmpty;
      if (sinDatos) {
        debugPrint('[TEST] SGA 03 — sin datos SGA (estado válido) ✓');
      } else {
        // Debe haber algún campo de peligro, fórmula o pictograma
        expect(
          find.textContaining('PELIGRO').evaluate().isNotEmpty ||
          find.textContaining('ATENCIÓN').evaluate().isNotEmpty ||
          find.byType(Image).evaluate().isNotEmpty,
          isTrue,
          reason: 'Debe haber contenido SGA visible si los datos están cargados',
        );
        debugPrint('[TEST] SGA 03 — tiene datos SGA ✓');
      }
      debugPrint('[TEST] SGA 03 — OK ✓');
    });

    testWidgets('04 — Pestaña "Editar" muestra formulario SGA',
        (tester) async {
      debugPrint('[TEST] SGA 04 — iniciando...');
      app.main();
      await loginComoAdmin(tester);

      final abierto = await _abrirFichaSga(tester);
      if (!abierto) { debugPrint('[TEST] SGA 04 — skip ✓'); return; }

      debugPrint('[TEST] SGA 04 — tocando pestaña Editar...');
      await tester.tap(find.text('Editar'));
      await tester.pump(kAnimationDelay);
      await tester.pumpAndSettle();

      debugPrint('[TEST] SGA 04 — verificando formulario...');
      expect(find.byType(TextFormField), findsWidgets);
      debugPrint('[TEST] SGA 04 — OK ✓');
    });

    testWidgets('05 — Pestaña "Colmena ARL" carga sin error',
        (tester) async {
      debugPrint('[TEST] SGA 05 — iniciando...');
      app.main();
      await loginComoAdmin(tester);

      final abierto = await _abrirFichaSga(tester);
      if (!abierto) { debugPrint('[TEST] SGA 05 — skip ✓'); return; }

      debugPrint('[TEST] SGA 05 — tocando pestaña Colmena ARL...');
      await tester.tap(find.text('Colmena ARL'));
      await tester.pump(kNetworkTimeout);
      await tester.pumpAndSettle();

      debugPrint('[TEST] SGA 05 — verificando que Colmena cargó sin error...');
      expect(find.textContaining('Error al cargar').evaluate().isEmpty, isTrue,
          reason: 'La pestaña Colmena no debe mostrar error de red');
      debugPrint('[TEST] SGA 05 — OK ✓');
    });

    testWidgets('06 — Botón etiqueta GHS abre diálogo de tamaños',
        (tester) async {
      debugPrint('[TEST] SGA 06 — iniciando...');
      app.main();
      await loginComoAdmin(tester);

      final abierto = await _abrirFichaSga(tester);
      if (!abierto) { debugPrint('[TEST] SGA 06 — skip ✓'); return; }

      debugPrint('[TEST] SGA 06 — buscando botón de etiqueta GHS...');
      final btnEtiqueta = find.byTooltip('Generar etiqueta GHS');
      if (btnEtiqueta.evaluate().isEmpty) {
        debugPrint('[TEST] SGA 06 — botón deshabilitado (sin datos SGA) — skip ✓');
        return;
      }

      await tester.tap(btnEtiqueta);
      await tester.pumpAndSettle();

      debugPrint('[TEST] SGA 06 — verificando diálogo de tamaños...');
      expect(find.text('Seleccionar tamaño de etiqueta'), findsOneWidget);
      expect(find.text('Pequeña'),       findsOneWidget);
      expect(find.text('Máx. 50 L'),     findsOneWidget);
      expect(find.text('Máx. 500 L'),    findsOneWidget);
      expect(find.text('Más de 500 L'),  findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      debugPrint('[TEST] SGA 06 — OK ✓');
    });
  });
}
