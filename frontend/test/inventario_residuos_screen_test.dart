import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/models/insumo_model.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/inventario_provider.dart';
import 'package:frontend/screens/inventario_screen.dart';

/// Pantalla de inventario con la sección Residuos: leyenda sin desbordes en
/// móvil, chip "Total" coherente con la sección y búsqueda de residuos
/// desde "Todos".

class _FakeProv extends InventarioProvider {
  final List<Insumo> lista;
  _FakeProv(this.lista);
  @override
  List<Insumo> get insumos => lista;
  @override
  Future<void> fetchInsumos(String? token) async {}
}

Insumo _mk(String id, String nombre, String tipo, String sem) => Insumo(
    id: id, nombre: nombre, tipo: tipo,
    ubicacion: 'Estante de residuos — Laboratorio de química 2',
    unidad: 'L', stockActual: 12, stockMinimo: 5, semaforo: sem,
    activo: true, tieneSga: true);

final _datos = [
  _mk('1', 'Residuos de ácidos orgánicos diluidos', kTipoResiduo, 'VERDE'),
  _mk('2', 'Halogenados', kTipoResiduo, 'VERDE'),
  _mk('3', 'Ácido sulfúrico', 'Químico', 'ROJO'),
  _mk('4', 'Beaker 250 mL', 'Vidriería', 'AMARILLO'),
  _mk('5', 'Pinza', 'Implemento', 'VERDE'),
];

/// Un desborde (RenderFlex overflowed) se reporta como error de Flutter y
/// hace fallar el test por sí solo.
Future<void> _montar(WidgetTester t, double ancho) async {
  t.view.physicalSize = Size(ancho, 800);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  await t.pumpWidget(MultiProvider(providers: [
    ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
    ChangeNotifierProvider<InventarioProvider>(create: (_) => _FakeProv(_datos)),
  ], child: const MaterialApp(home: Scaffold(body: InventarioContent()))));
  await t.pump();
}

Future<void> _elegir(WidgetTester t, String chip) async {
  await t.ensureVisible(find.widgetWithText(ChoiceChip, chip));
  await t.pump();
  await t.tap(find.widgetWithText(ChoiceChip, chip));
  await t.pump();
}

void main() {
  // Con la fuente de pruebas (Ahem, más ancha que Roboto) el resultado es
  // conservador. La leyenda de residuos desbordaba 276 px a 360 px.
  for (final ancho in [360.0, 412.0, 1280.0]) {
    for (final chip in ['Todos', 'Químico', kTipoResiduo]) {
      testWidgets('sin desbordes en $chip a $ancho px', (t) async {
        await _montar(t, ancho);
        if (chip != 'Todos') await _elegir(t, chip);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('el chip Total cuenta la sección mostrada', (t) async {
    await _montar(t, 1280);
    expect(find.text('Total: 3'), findsOneWidget);       // sin los 2 residuos
    await _elegir(t, kTipoResiduo);
    expect(find.text('Total: 2'), findsOneWidget);
    expect(find.textContaining('Críticos'), findsNothing);
  });

  testWidgets('"Todos" oculta los residuos, pero la búsqueda sí los encuentra', (t) async {
    await _montar(t, 1280);
    expect(find.text('Halogenados'), findsNothing);
    await t.enterText(find.byType(TextField), 'halogen');
    await t.pump(const Duration(milliseconds: 350));      // debounce
    expect(find.text('Halogenados'), findsOneWidget);
    expect(find.text('RESIDUO'), findsOneWidget);
  });
}
