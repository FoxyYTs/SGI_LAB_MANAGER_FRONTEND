import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/horario_utils.dart';
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

  Future<void> elegirHora(WidgetTester tester, String key, String hora) async {
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(hora).last);
    await tester.pumpAndSettle();
  }

  Future<void> tocar(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  String resumen(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('resumen-total'))).data!;

  BloqueFormDialog dialogoEnc({Set<int> dias = const {0}, int hora = 8}) => BloqueFormDialog(
        modo: ModoBloque.encargado,
        titulo: 'Asignar varios días',
        textoBoton: 'Asignar',
        multiDia: true,
        diasIniciales: dias,
        horaInicio: hora,
        horaFin: hora + 1,
        encargados: encargados,
      );

  testWidgets('varios días en móvil: rangos distintos por día y dos rangos el mismo día',
      (tester) async {
    // Celda vacía tocada: lunes 8 AM → lunes 8–9 precargado.
    final res = await _abrir(tester, dialogoEnc());
    expect(tester.takeException(), isNull); // sin overflow a 360 px
    expect(find.byKey(const ValueKey('rango-0-0')), findsOneWidget);
    expect(resumen(tester), 'Total: 1 h en 1 día');

    // Sin encargado no deja aceptar.
    await tocar(tester, find.text('Asignar'));
    expect(find.text('Elige el encargado'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beto Gil · LAB').last);
    await tester.pumpAndSettle();

    // Lunes 11–15.
    await elegirHora(tester, 'desde-0-0', '11 AM');
    await elegirHora(tester, 'hasta-0-0', '3 PM');
    // Marcar miércoles precarga el último rango usado (11–15).
    await tocar(tester, find.text('Mié'));
    expect(resumen(tester), 'Total: 8 h en 2 días');
    // Miércoles 8–10 y + rango → 11–12, luego 11–13.
    await elegirHora(tester, 'desde-2-0', '8 AM');
    await elegirHora(tester, 'hasta-2-0', '10 AM');
    await tocar(tester, find.byKey(const ValueKey('agregar-2')));
    expect(find.byKey(const ValueKey('rango-2-1')), findsOneWidget);
    await elegirHora(tester, 'hasta-2-1', '1 PM');
    expect(tester.takeException(), isNull);
    expect(resumen(tester), 'Total: 8 h en 2 días');

    // Sábado 8–12.
    await tocar(tester, find.text('Sáb'));
    await elegirHora(tester, 'desde-5-0', '8 AM');
    await elegirHora(tester, 'hasta-5-0', '12 PM');
    expect(resumen(tester), 'Total: 12 h en 3 días');
    expect(tester.takeException(), isNull);

    await tocar(tester, find.text('Asignar'));
    final r = res();
    expect(r, isNotNull);
    expect(r!.usuario, 2);
    expect(r.nombreUsuario, 'Beto Gil');
    expect(r.dias, [0, 2, 5]);
    expect(r.rangos, const [
      RangoHoras(0, 11, 15),
      RangoHoras(2, 8, 10),
      RangoHoras(2, 11, 13),
      RangoHoras(5, 8, 12),
    ]);
    expect(r.bloquesJson.first, {'dia': 0, 'hora_inicio': 11, 'hora_fin': 15});
  });

  testWidgets('copiar un rango a todos los días, solapes y quitar rangos', (tester) async {
    final res = await _abrir(tester, BloqueFormDialog(
      modo: ModoBloque.encargado,
      titulo: 'Asignar varios días',
      textoBoton: 'Asignar',
      multiDia: true,
      diasIniciales: const {},
      horaInicio: 8,
      horaFin: 9,
      encargados: encargados,
      usuarioInicial: 1,
    ));
    expect(find.textContaining('Marca los días'), findsOneWidget);

    // Lun a Vie con 8–9; el botón de copiar solo aparece con varios días.
    await tocar(tester, find.text('Lun a Vie'));
    expect(resumen(tester), 'Total: 5 h en 5 días');
    expect(find.byKey(const ValueKey('copiar-3-0')), findsOneWidget);

    // Jueves 2 PM → conserva la duración (2–3 PM) y se copia a todos.
    await elegirHora(tester, 'desde-3-0', '2 PM');
    await elegirHora(tester, 'hasta-3-0', '6 PM');
    await tocar(tester, find.byKey(const ValueKey('copiar-3-0')));
    expect(resumen(tester), 'Total: 20 h en 5 días');

    // Un rango solapado el mismo día se une al calcular el total.
    await tocar(tester, find.byKey(const ValueKey('agregar-0')));
    await elegirHora(tester, 'desde-0-1', '4 PM');   // 4–5 PM, dentro de 2–6 PM
    expect(resumen(tester), 'Total: 20 h en 5 días');

    // Quitar el único rango del viernes desmarca el día.
    await tocar(tester, find.byKey(const ValueKey('quitar-4-0')));
    expect(find.byKey(const ValueKey('dia-4')), findsNothing);
    expect(resumen(tester), 'Total: 16 h en 4 días');
    expect(tester.takeException(), isNull);

    await tocar(tester, find.text('Asignar'));
    final r = res()!;
    expect(r.dias, [0, 1, 2, 3]);
    expect(r.rangos.every((x) => x.inicio == 14 && x.fin == 18), isTrue);
    expect(r.rangos.length, 4); // el 4–5 PM del lunes se fusionó
  });

  testWidgets('sin días marcados no deja aceptar', (tester) async {
    final res = await _abrir(tester, BloqueFormDialog(
      modo: ModoBloque.encargado,
      titulo: 'Agregar encargado',
      textoBoton: 'Asignar',
      multiDia: true,
      diasIniciales: const {1},
      horaInicio: 21,
      horaFin: 22,
      encargados: encargados,
      usuarioInicial: 1,
    ));
    await tocar(tester, find.byKey(const ValueKey('quitar-1-0')));
    await tocar(tester, find.text('Asignar'));
    expect(find.text('Elige al menos un día'), findsOneWidget);
    expect(res(), isNull);
  });

  testWidgets('asignatura usa los mismos rangos por día', (tester) async {
    final res = await _abrir(tester, const BloqueFormDialog(
      modo: ModoBloque.asignatura,
      titulo: 'Agregar asignatura',
      textoBoton: 'Asignar',
      multiDia: true,
      diasIniciales: {3},
      horaInicio: 18,
      horaFin: 19,
      asignaturas: [{'id': 'a1', 'nombre_asignatura': 'Química'}],
      asignaturaInicial: 'a1',
      grupoInicial: 'G1',
    ));
    await tocar(tester, find.byKey(const ValueKey('agregar-3')));   // 20–21
    await tocar(tester, find.text('Lun'));                          // 18–19
    expect(resumen(tester), 'Total: 3 h en 2 días');
    expect(tester.takeException(), isNull);
    await tocar(tester, find.text('Asignar'));
    final r = res()!;
    expect(r.asignatura, 'a1');
    expect(r.grupo, 'G1');
    expect(r.rangos, const [RangoHoras(0, 18, 19), RangoHoras(3, 18, 19), RangoHoras(3, 20, 21)]);
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
