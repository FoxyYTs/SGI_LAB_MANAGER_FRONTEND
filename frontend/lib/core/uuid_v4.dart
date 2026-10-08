// Generador de UUID v4 sin dependencias externas (Random.secure()).
//
// Se usa como clave de idempotencia (`client_request_id`) al crear
// préstamos: el formulario genera un UUID al abrirse y lo reutiliza en
// cada reintento, así el backend reconoce un reenvío (por timeout o doble
// tap) y devuelve el préstamo ya creado en vez de duplicarlo.

import 'dart:math';

final Random _rng = Random.secure();

/// Devuelve un UUID versión 4 (aleatorio) en formato canónico
/// `xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx`.
String uuidV4() {
  final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // versión 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variante RFC 4122
  String hex(int b) => b.toRadixString(16).padLeft(2, '0');
  final h = bytes.map(hex).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}
