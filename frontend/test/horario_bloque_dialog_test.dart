import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/horario_bloque_dialog.dart';

/// Abre el diálogo en una pantalla de teléfono (360×640) y devuelve un
/// getter del resultado con el que se cerró.
Future<BloqueFormResultado? Function()> _abrir(WidgetTester tester, Widget dialogo) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  BloqueFormResultado? resultado;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              resultado = await showDialog<BloqueFormResultado>(
                  context: context, builder: (_) => dialogo);
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return () => resultado;
}

void main() {
  final encargados = [
    {'id': 1, 'username': 'ana', 'nombre_completo': 'Ana Ruiz', 'rol': 'MONITOR'},
    {'id': 2, 'username': 'beto', 'nombre_completo': 'Beto Gil', 'rol': 'LAB'},
  ];

  testWidgets('asignar varios días en móvil: chips, validación y resultado', (tester) async {
    final res = await _abrir(
      tester,
      BloqueFormDialog(
        modo: ModoBloque.encargado,
        titulo: 'Asignar varios días',
        textoBoton: 'Asignar',
        multiDia: true,
        diasIniciales: const {0},
        horaInicio: 8,
        horaFin: 9,
        encargados: encargados,
      ),
    );
    expect(tester.takeException(), isNull); // sin overflow a 360 px

    // Sin encargado no deja aceptar.
    await tester.tap(find.text('Asignar'));
    await tester.pump();
    expect(find.text('Elige el encargado'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beto Gil · LAB').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mié'));
    await tester.tap(find.text('Vie'));
    await tester.pump();
    expect(find.textContaining('L, X, V'), findsOneWidget);

    await tester.ensureVisible(find.text('Asignar'));
    await tester.tap(find.text('Asignar'));
    await tester.pumpAndSettle();
    final r = res();
    expect(r, isNotNull);
    expect(r!.usuario, 2);
    expect(r.nombreUsuario, 'Beto Gil');
    expect(r.dias, [0, 2, 4]);
    expect((r.horaInicio, r.horaFin), (8, 9));
  });

  testWidgets('editar rango precarga persona y horas (día fijo)', (tester) async {
    final res = await _abrir(
      tester,
      BloqueFormDialog(
        modo: ModoBloque.encargado,
        titulo: 'Editar bloque',
        textoBoton: 'Guardar',
        multiDia: false,
        diasIniciales: const {0},
        horaInicio: 8,
        horaFin: 11,
        encargados: encargados,
        usuarioInicial: 1,
      ),
    );
    expect(find.byType(FilterChip), findsNothing);
    expect(find.text('Lunes'), findsOneWidget);
    expect(find.text('11 AM'), findsOneWidget);
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    final r = res();
    expect(r!.usuario, 1);
    expect(r.dias, [0]);
    expect((r.horaInicio, r.horaFin), (8, 11));
  });

  test('mensajeErrorApi lee detail o el primer error de campo', () {
    expect(mensajeErrorApi({'detail': 'No.'}), 'No.');
    expect(mensajeErrorApi({'dias': ['Elige al menos un día.']}), 'Elige al menos un día.');
    expect(mensajeErrorApi('x'), isNull);
  });
}
