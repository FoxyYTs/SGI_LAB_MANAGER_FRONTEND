import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencia local (por dispositivo) del tema claro/oscuro. Se persiste
/// con `shared_preferences` bajo [_prefsKey] como 'system'|'light'|'dark'.
///
/// Se carga con [cargar] ANTES de levantar la UI (ver `main.dart`), igual
/// que la sesión de `AuthProvider`, para que la app arranque ya en el tema
/// elegido sin un parpadeo claro→oscuro.
class ThemeProvider with ChangeNotifier {
  static const _prefsKey = 'theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _mode = _parse(prefs.getString(_prefsKey));
    } catch (_) {
      // Un fallo leyendo prefs nunca debe impedir el arranque: queda en system.
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, _name(mode));
    } catch (_) {
      // Si no se pudo persistir, al menos el cambio ya aplicó en esta sesión.
    }
  }

  static ThemeMode _parse(String? v) => switch (v) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static String _name(ThemeMode m) => switch (m) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
}
