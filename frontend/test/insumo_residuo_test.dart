import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/insumo_model.dart';

Insumo _insumo(String tipo, {String semaforo = 'ROJO'}) => Insumo.fromJson({
      'id': '1',
      'nombre_insumo': 'X',
      'tipo_nombre': tipo,
      'stock_total': '3',
      'stock_minimo': '5',
      'semaforo': semaforo,
    });

void main() {
  test('un residuo no muestra semáforo y usa la ficha SGA', () {
    final r = _insumo(kTipoResiduo, semaforo: 'VERDE');
    expect(r.esResiduo, isTrue);
    expect(r.usaSga, isTrue);
    expect(r.estado, 'RESIDUO');
  });

  test('un químico conserva su semáforo y usa la ficha SGA', () {
    final q = _insumo('Químico');
    expect(q.esResiduo, isFalse);
    expect(q.usaSga, isTrue);
    expect(q.estado, 'ROJO');
  });

  test('vidriería no usa la ficha SGA', () {
    final v = _insumo('Vidriería', semaforo: 'AMARILLO');
    expect(v.usaSga, isFalse);
    expect(v.estado, 'AMARILLO');
  });
}
