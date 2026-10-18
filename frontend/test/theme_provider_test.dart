import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/providers/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('por defecto es system cuando no hay nada guardado', () async {
    SharedPreferences.setMockInitialValues({});
    final p = ThemeProvider();
    await p.cargar();
    expect(p.mode, ThemeMode.system);
  });

  test('carga el valor persistido', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
    final p = ThemeProvider();
    await p.cargar();
    expect(p.mode, ThemeMode.dark);
  });

  test('un valor corrupto cae a system (no revienta)', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'basura'});
    final p = ThemeProvider();
    await p.cargar();
    expect(p.mode, ThemeMode.system);
  });

  test('setMode persiste y notifica; otra instancia lo relee', () async {
    SharedPreferences.setMockInitialValues({});
    final p = ThemeProvider();
    var notificado = false;
    p.addListener(() => notificado = true);

    await p.setMode(ThemeMode.light);
    expect(p.mode, ThemeMode.light);
    expect(notificado, isTrue);

    final otra = ThemeProvider();
    await otra.cargar();
    expect(otra.mode, ThemeMode.light);
  });
}
