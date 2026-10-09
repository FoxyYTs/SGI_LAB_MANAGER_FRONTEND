import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/registrar_movimiento_dialog.dart';

/// Abre el diálogo y devuelve un getter del resultado con el que se cerró.
Future<ResultadoMovimiento? Function()> _abrir(
    WidgetTester tester, Widget dialogo) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  ResultadoMovimiento? resultado;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              resultado = await showDialog<ResultadoMovimiento>(
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

DioException _error400(Object data) {
  final req = RequestOptions(path: 'operaciones/bitacora/');
  return DioException(
    requestOptions: req,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: req, statusCode: 400, data: data),
  );
}

void main() {
  const unaPres = [
    {'id': 'p1', 'unidad_nombre': 'L', 'stock_actual': '10.00', 'activa': true},
  ];
  const variasPres = [
    {'id': 'p1', 'unidad_nombre': 'Frasco 500 mL', 'stock_actual': '3', 'activa': true},
    {'id': 'p2', 'unidad_nombre': 'Galón', 'stock_actual': '1', 'activa': true},
    {'id': 'p3', 'unidad_nombre': 'Caneca vieja', 'stock_actual': '0', 'activa': false},
  ];

  group('validarCantidad', () {
    test('rechaza vacío, cero, negativo, texto y más de 2 decimales', () {
      expect(validarCantidad(''), isNotNull);
      expect(validarCantidad('0'), isNotNull);
      expect(validarCantidad('-2'), isNotNull);
      expect(validarCantidad('abc'), isNotNull);
      expect(validarCantidad('1.234'), isNotNull);
      expect(validarCantidad('100000000'), isNotNull);
    });
    test('acepta enteros, decimales y coma decimal', () {
      expect(validarCantidad('3'), isNull);
      expect(validarCantidad('2.5'), isNull);
      expect(validarCantidad('2,75'), isNull);
    });
  });

  test('fmtCantidad no muestra decimales sobrantes', () {
    expect(fmtCantidad(12), '12');
    expect(fmtCantidad(2.5), '2.5');
    expect(fmtCantidad(0.25), '0.25');
  });

  testWidgets('una presentación: preseleccionada, envía ENTRADA y devuelve el stock del backend',
      (tester) async {
    Map<String, dynamic>? enviado;
    final resultado = await _abrir(
      tester,
      RegistrarMovimientoDialog(
        insumoNombre: 'Ácido acético',
        esResiduo: false,
        tipo: MovimientoStock.entrada,
        presentaciones: unaPres,
        enviar: (body) async {
          enviado = body;
          return {'stock_posterior': '12.50'};
        },
      ),
    );
    expect(find.byKey(const ValueKey('mov-presentacion')), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('mov-cantidad')), '2,5');
    await tester.enterText(
        find.byKey(const ValueKey('mov-observaciones')), 'Factura 123');
    await tester.tap(find.byKey(const ValueKey('mov-guardar')));
    await tester.pumpAndSettle();

    expect(enviado, {
      'presentacion': 'p1',
      'tipo_movimiento': 'ENTRADA',
      'cantidad': '2.5',
      'observaciones': 'Factura 123',
    });
    expect(resultado()?.stockResultante, 12.5);
    expect(resultado()?.unidad, 'L');
    expect(find.byType(RegistrarMovimientoDialog), findsNothing);
  });

  testWidgets('cantidad inválida no envía', (tester) async {
    var llamadas = 0;
    await _abrir(
      tester,
      RegistrarMovimientoDialog(
        insumoNombre: 'X',
        esResiduo: false,
        tipo: MovimientoStock.salida,
        presentaciones: unaPres,
        enviar: (_) async => llamadas++,
      ),
    );
    await tester.enterText(find.byKey(const ValueKey('mov-cantidad')), '0');
    await tester.tap(find.byKey(const ValueKey('mov-guardar')));
    await tester.pumpAndSettle();
    expect(llamadas, 0);
    expect(find.text('Debe ser mayor a 0'), findsOneWidget);
  });

  testWidgets('varias presentaciones: obliga a elegir y no ofrece las inactivas',
      (tester) async {
    Map<String, dynamic>? enviado;
    await _abrir(
      tester,
      RegistrarMovimientoDialog(
        insumoNombre: 'Etanol',
        esResiduo: false,
        tipo: MovimientoStock.salida,
        presentaciones: variasPres,
        enviar: (body) async {
          enviado = body;
          return {'stock_posterior': '2'};
        },
      ),
    );
    await tester.enterText(find.byKey(const ValueKey('mov-cantidad')), '1');
    await tester.tap(find.byKey(const ValueKey('mov-guardar')));
    await tester.pumpAndSettle();
    expect(enviado, isNull);
    expect(find.text('Elige la presentación'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mov-presentacion')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Caneca vieja'), findsNothing);
    await tester.tap(find.textContaining('Galón').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mov-guardar')));
    await tester.pumpAndSettle();
    expect(enviado?['presentacion'], 'p2');
    expect(enviado?['tipo_movimiento'], 'SALIDA');
  });

  testWidgets('error del backend: muestra el mensaje y el diálogo sigue abierto',
      (tester) async {
    final resultado = await _abrir(
      tester,
      RegistrarMovimientoDialog(
        insumoNombre: 'X',
        esResiduo: false,
        tipo: MovimientoStock.salida,
        presentaciones: unaPres,
        enviar: (_) async => throw _error400({
          'error': ["Stock insuficiente para 'X': disponible 10, solicitado 50."]
        }),
      ),
    );
    await tester.enterText(find.byKey(const ValueKey('mov-cantidad')), '50');
    await tester.tap(find.byKey(const ValueKey('mov-guardar')));
    await tester.pumpAndSettle();
    expect(find.text("Stock insuficiente para 'X': disponible 10, solicitado 50."),
        findsOneWidget);
    expect(find.byType(RegistrarMovimientoDialog), findsOneWidget);
    expect(resultado(), isNull);
  });

  testWidgets('doble toque en Guardar envía una sola vez', (tester) async {
    var llamadas = 0;
    final completer = Completer<dynamic>();
    await _abrir(
      tester,
      RegistrarMovimientoDialog(
        insumoNombre: 'X',
        esResiduo: false,
        tipo: MovimientoStock.entrada,
        presentaciones: unaPres,
        enviar: (_) {
          llamadas++;
          return completer.future;
        },
      ),
    );
    await tester.enterText(find.byKey(const ValueKey('mov-cantidad')), '1');
    await tester.tap(find.byKey(const ValueKey('mov-guardar')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('mov-guardar')),
        warnIfMissed: false);
    await tester.pump();
    expect(llamadas, 1);
    completer.complete({'stock_posterior': '11'});
    await tester.pumpAndSettle();
    expect(find.byType(RegistrarMovimientoDialog), findsNothing);
  });

  testWidgets('residuo: la salida se rotula "Entregar al gestor"', (tester) async {
    await _abrir(
      tester,
      RegistrarMovimientoDialog(
        insumoNombre: 'Ácidos orgánicos',
        esResiduo: true,
        tipo: MovimientoStock.salida,
        presentaciones: unaPres,
        enviar: (_) async => null,
      ),
    );
    expect(find.text('Entregar al gestor'), findsOneWidget);
    expect(find.text('Gestor y n.º de manifiesto'), findsOneWidget);
  });

  testWidgets('backend viejo sin stock_posterior: estima con el stock conocido',
      (tester) async {
    final resultado = await _abrir(
      tester,
      RegistrarMovimientoDialog(
        insumoNombre: 'X',
        esResiduo: true,
        tipo: MovimientoStock.salida,
        presentaciones: unaPres,
        enviar: (_) async => {'cantidad': '4.00'},
      ),
    );
    await tester.enterText(find.byKey(const ValueKey('mov-cantidad')), '4');
    await tester.tap(find.byKey(const ValueKey('mov-guardar')));
    await tester.pumpAndSettle();
    expect(resultado()?.stockResultante, 6);
  });
}
