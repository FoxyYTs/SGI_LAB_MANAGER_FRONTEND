import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// DEV_MODE activa: log en archivo + detalles técnicos en la UI de errores.
///   --dart-define=DEV_MODE=true
/// FILE_LOG solo activa el log en archivo (sin tocar la UI de errores).
///   --dart-define=FILE_LOG=true
const _kDevMode = bool.fromEnvironment('DEV_MODE',  defaultValue: false);
const _kEnabled = bool.fromEnvironment('FILE_LOG',  defaultValue: false) || _kDevMode;

class LogService {
  static IOSink? _sink;
  static String? _logPath;

  static Future<void> init() async {
    if (!_kEnabled || kIsWeb) return;
    try {
      // getExternalStorageDirectory() → /sdcard/Android/data/<pkg>/files/
      // Visible en el administrador de archivos sin permisos extra (Android 10+).
      final dir = await getExternalStorageDirectory();
      if (dir == null) {
        // Fallback a documentos internos si el externo no está disponible.
        final inner = await getApplicationDocumentsDirectory();
        _logPath = '${inner.path}/sgi_debug.txt';
      } else {
        _logPath = '${dir.path}/sgi_debug.txt';
      }
      final file = File(_logPath!);
      // Appendea para no perder logs de reinicios anteriores.
      _sink = file.openWrite(mode: FileMode.writeOnlyAppend);
      _write('');
      _write('═══ INICIO APP  ${DateTime.now().toIso8601String()} ═══');
    } catch (e) {
      debugPrint('[LogService] No se pudo abrir log en archivo: $e');
    }
  }

  static void log(String msg) {
    final line = '[${DateTime.now().toIso8601String()}] $msg';
    debugPrint(line);
    if (!_kEnabled || kIsWeb) return;
    _sink?.writeln(line);
  }

  static void logError(String context, Object error, StackTrace? stack) {
    log('❌ ERROR en $context');
    log('   Tipo: ${error.runtimeType}');
    log('   Msg:  $error');
    if (stack != null) {
      log('   Stack:\n${stack.toString().split('\n').take(12).join('\n')}');
    }
    _sink?.flush();
  }

  static Future<void> flush() async {
    await _sink?.flush();
  }

  static Future<void> close() async {
    await _sink?.flush();
    await _sink?.close();
  }

  static String? get logPath => _logPath;
  static bool get enabled => _kEnabled && !kIsWeb;
  static bool get devMode  => _kDevMode;

  static void _write(String msg) => _sink?.writeln(msg);
}
