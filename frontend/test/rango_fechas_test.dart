import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/rango_fechas.dart';
import 'package:frontend/widgets/filtro_rango_fechas.dart';

void main() {
  test('fechaApi rellena con ceros', () {
    expect(fechaApi(DateTime(2026, 3, 5)), '2026-03-05');
  });

  test('paramsRango vacío sin rango e inclusivo con rango', () {
    expect(paramsRango(null), isEmpty);
    final r = DateTimeRange(start: DateTime(2026, 10, 1), end: DateTime(2026, 10, 8));
    expect(paramsRango(r), {'desde': '2026-10-01', 'hasta': '2026-10-08'});
  });

  test('etiquetaRango de un día o de varios', () {
    final d = DateTime(2026, 10, 5);
    expect(etiquetaRango(DateTimeRange(start: d, end: d)), '05/10/2026');
    expect(etiquetaRango(DateTimeRange(start: d, end: DateTime(2026, 10, 7))),
        '05/10/2026 – 07/10/2026');
  });

  testWidgets('el chip con rango se limpia con la x', (tester) async {
    DateTimeRange? actual = DateTimeRange(
        start: DateTime(2026, 10, 1), end: DateTime(2026, 10, 2));
    var limpiado = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FiltroRangoFechas(
          rango: actual,
          onChanged: (r) { actual = r; limpiado = r == null; },
        ),
      ),
    ));
    expect(find.text('01/10/2026 – 02/10/2026'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    expect(limpiado, isTrue);
    expect(actual, isNull);
  });

  testWidgets('sin rango muestra el botón Fechas', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: FiltroRangoFechas(rango: null, onChanged: (_) {})),
    ));
    expect(find.text('Fechas'), findsOneWidget);
  });
}
