import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/text_utils.dart';

void main() {
  test('normalizarBusqueda quita tildes, mayúsculas y espacios extremos', () {
    expect(normalizarBusqueda('  Ácido Sulfúrico '), 'acido sulfurico');
  });

  test('una búsqueda con espacio final sigue encontrando la fórmula', () {
    expect(normalizarBusqueda('H2SO4').contains(normalizarBusqueda('h2so4 ')),
        isTrue);
  });
}
