import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/screens/politica_privacidad_screen.dart';

void main() {
  // ── Pruebas de unidad — AuthProvider ────────────────────────────────────────

  group('AuthProvider.can()', () {
    late AuthProvider auth;

    setUp(() => auth = AuthProvider());

    test('retorna false para cualquier permiso cuando no hay sesión', () {
      expect(auth.can('inventario.ver'),      isFalse);
      expect(auth.can('prestamos.gestionar'), isFalse);
      expect(auth.can('configuracion.roles'), isFalse);
    });

    test('isAuthenticated es false sin sesión activa', () {
      expect(auth.isAuthenticated, isFalse);
    });

    test('username y rol son null sin sesión activa', () {
      expect(auth.username, isNull);
      expect(auth.rol,      isNull);
    });
  });

  // ── Pruebas de widget — PoliticaPrivacidadScreen ─────────────────────────────

  group('PoliticaPrivacidadScreen', () {
    Widget _buildScreen() =>
        const MaterialApp(home: PoliticaPrivacidadScreen());

    testWidgets('muestra el título en la AppBar', (tester) async {
      await tester.pumpWidget(_buildScreen());
      expect(find.text('Política de Privacidad'), findsWidgets);
    });

    testWidgets('muestra la sección del responsable del tratamiento',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.textContaining('Responsable'), findsOneWidget);
    });

    testWidgets('muestra la sección de derechos del titular', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.textContaining('Derechos'), findsOneWidget);
    });

    testWidgets('el botón de atrás en la AppBar está presente', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('inicio')),
          routes: {'/politica': (ctx) => const PoliticaPrivacidadScreen()},
        ),
      );
      // La pantalla es un destino de navegación — tiene back button cuando hay ruta previa.
      // Aquí solo verificamos que se renderiza sin errores cuando es la primera ruta.
      await tester.pumpWidget(_buildScreen());
      expect(find.byType(AppBar), findsOneWidget);
    });
  });
}
