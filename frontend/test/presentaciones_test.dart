import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/presentaciones.dart';

void main() {
  group('presentacionActiva', () {
    test('sin el campo (backend viejo / catálogo público) se asume activa', () {
      expect(presentacionActiva({'id': 'a'}), isTrue);
      expect(presentacionActiva({'id': 'a', 'activa': true}), isTrue);
      expect(presentacionActiva({'id': 'a', 'activa': false}), isFalse);
    });

    test('presentacionesActivas filtra y tolera null', () {
      expect(presentacionesActivas(null), isEmpty);
      final r = presentacionesActivas([
        {'id': 'a', 'activa': false},
        {'id': 'b'},
        {'id': 'c', 'activa': true},
      ]);
      expect(r.map((p) => p['id']), ['b', 'c']);
    });
  });

  group('presentacionDisponible', () {
    test('usa el booleano del catálogo público', () {
      expect(presentacionDisponible({'disponible': true}), isTrue);
      expect(presentacionDisponible({'disponible': false}), isFalse);
    });

    test('cae a stock_actual si no viene disponible', () {
      expect(presentacionDisponible({'stock_actual': '3.00'}), isTrue);
      expect(presentacionDisponible({'stock_actual': '0.00'}), isFalse);
      expect(presentacionDisponible({'stock_actual': '5', 'activa': false}), isFalse);
    });

    test('desconocido si no hay datos', () {
      expect(presentacionDisponible({'id': 'x'}), isNull);
    });
  });

  group('presentacionPorDefecto', () {
    test('prefiere la primera activa con existencias', () {
      final p = presentacionPorDefecto([
        {'id': 'inactiva', 'activa': false, 'stock_actual': '9'},
        {'id': 'agotada', 'stock_actual': '0'},
        {'id': 'con_stock', 'stock_actual': '2'},
      ]);
      expect(p?['id'], 'con_stock');
    });

    test('si todas están agotadas, la primera activa', () {
      final p = presentacionPorDefecto([
        {'id': 'a', 'disponible': false},
        {'id': 'b', 'disponible': false},
      ]);
      expect(p?['id'], 'a');
    });

    test('null si no hay activas', () {
      expect(presentacionPorDefecto([{'id': 'a', 'activa': false}]), isNull);
      expect(presentacionPorDefecto(null), isNull);
    });
  });

  group('insumoDisponible', () {
    test('true si alguna activa tiene existencias', () {
      expect(insumoDisponible([{'disponible': false}, {'disponible': true}]), isTrue);
    });
    test('false si todas agotadas o sin activas', () {
      expect(insumoDisponible([{'disponible': false}]), isFalse);
      expect(insumoDisponible([]), isFalse);
    });
    test('null si no se sabe', () {
      expect(insumoDisponible([{'id': 'a'}]), isNull);
    });
  });
}
