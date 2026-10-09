import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/sga_screen.dart';

void main() {
  Future<(String, String)?> abrir(WidgetTester tester,
      Future<void> Function() acciones, {String inicial = 'pdf'}) async {
    (String, String)? resultado;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (ctx) => TextButton(
        onPressed: () async =>
            resultado = await mostrarDialogoEtiqueta(ctx, salidaInicial: inicial),
        child: const Text('abrir'),
      )),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await acciones();
    await tester.pumpAndSettle();
    return resultado;
  }

  testWidgets('por defecto descarga en PDF', (tester) async {
    final r = await abrir(tester, () => tester.tap(find.text('Máx. 500 L')));
    expect(r, ('500l', 'pdf'));
  });

  testWidgets('se puede elegir Word (editable) antes del tamaño', (tester) async {
    final r = await abrir(tester, () async {
      await tester.tap(find.text('Word (editable)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pequeña'));
    });
    expect(r, ('pequena', 'docx'));
  });

  testWidgets('recuerda la salida elegida antes y cancelar devuelve null', (tester) async {
    final r = await abrir(tester, () => tester.tap(find.text('Cancelar')), inicial: 'docx');
    expect(r, isNull);
    final r2 = await abrir(tester, () => tester.tap(find.text('Más de 500 L')), inicial: 'docx');
    expect(r2, ('grande', 'docx'));
  });

  testWidgets('cabe en un teléfono angosto (360 dp) sin desbordarse', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final r = await abrir(tester, () async {
      await tester.tap(find.text('Word (editable)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Máx. 50 L'));
    });
    expect(tester.takeException(), isNull);
    expect(r, ('50l', 'docx'));
  });
}
