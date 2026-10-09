import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/sga_screen.dart';

void main() {
  const porDefecto = 'Error al descargar la etiqueta.';

  test('lee el detail de un cuerpo en bytes (descarga con responseType bytes)', () {
    final bytes = utf8.encode(jsonEncode({'detail': 'Un residuo solo tiene etiqueta de residuo.'}));
    expect(detalleDeError(bytes, porDefecto), 'Un residuo solo tiene etiqueta de residuo.');
  });

  test('lee el detail de un cuerpo ya decodificado', () {
    expect(detalleDeError({'detail': 'tipo_etiqueta inválido (fds|residuo).'}, porDefecto),
        'tipo_etiqueta inválido (fds|residuo).');
  });

  test('sin detail o con un cuerpo no JSON usa el mensaje genérico', () {
    expect(detalleDeError(null, porDefecto), porDefecto);
    expect(detalleDeError(utf8.encode('<html>502</html>'), porDefecto), porDefecto);
    expect(detalleDeError({'error': 'x'}, porDefecto), porDefecto);
  });
}
