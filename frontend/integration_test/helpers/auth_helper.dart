import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test_config.dart';

/// Realiza el login con las credenciales de prueba y espera llegar al Dashboard.
///
/// Los campos se ubican por índice: 0 = Usuario, 1 = Contraseña.
/// La pantalla de login usa [TextField] (no TextFormField).
Future<void> loginComoAdmin(WidgetTester tester) async {
  await tester.pump(kUiReady);
  await tester.pumpAndSettle();

  expect(find.byType(TextField), findsWidgets);

  await tester.enterText(find.byType(TextField).at(0), kTestUser);
  await tester.enterText(find.byType(TextField).at(1), kTestPassword);
  await tester.tap(find.text('Ingresar'));

  await tester.pump(kNetworkTimeout);
  await tester.pumpAndSettle();
}
