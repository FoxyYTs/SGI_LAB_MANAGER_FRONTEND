import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/screens/sga_screen.dart';

/// La ficha SGA de un residuo no tiene ficha Colmena ARL ni extracción
/// desde FDS (son de la etiqueta SGA/FDS de los químicos).

/// Responde 404 a todo: la ficha queda vacía ("Sin datos SGA cargados").
class _Adapter404 implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async =>
      ResponseBody.fromString(jsonEncode({'detail': 'No encontrado.'}), 404, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });

  @override
  void close({bool force = false}) {}
}

Future<void> _montar(WidgetTester t, {required bool esResiduo}) async {
  ApiClient.resetForTests();
  ApiClient.instance.adapterParaTests = _Adapter404();
  await t.pumpWidget(ChangeNotifierProvider<AuthProvider>(
    create: (_) => AuthProvider(),
    child: MaterialApp(home: SgaScreen(
        insumoId: 'x', insumoNombre: 'Halogenados', esResiduo: esResiduo)),
  ));
  await t.pumpAndSettle();
}

void main() {
  tearDown(ApiClient.resetForTests);

  testWidgets('residuo: sin Colmena ARL ni Subir FDS; etiqueta de residuo', (t) async {
    await _montar(t, esResiduo: true);
    expect(find.byType(Tab), findsNWidgets(2));
    expect(find.text('Colmena ARL'), findsNothing);
    expect(find.byTooltip('Subir FDS para extraer datos'), findsNothing);
    expect(find.text('Subir FDS'), findsNothing);
    expect(find.byTooltip('Etiqueta de residuo'), findsOneWidget);
  });

  testWidgets('químico: conserva Colmena ARL y Subir FDS', (t) async {
    await _montar(t, esResiduo: false);
    expect(find.byType(Tab), findsNWidgets(3));
    expect(find.text('Colmena ARL'), findsOneWidget);
    expect(find.byTooltip('Subir FDS para extraer datos'), findsOneWidget);
    expect(find.text('Subir FDS'), findsOneWidget);
    expect(find.byTooltip('Generar etiqueta GHS'), findsOneWidget);
  });
}
