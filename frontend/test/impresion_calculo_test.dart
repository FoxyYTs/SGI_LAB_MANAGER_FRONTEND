import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/impresion_calculo.dart';

void main() {
  ({double material, double maquina, double preparacion}) pieza({
    double gramos = 35.32, int horas = 2, int minutos = 38,
    double margen = 0, double preparacion = 0,
  }) =>
      calcularPieza(
        precioRollo: 120000, pesoRolloG: 1000, gramos: gramos, horas: horas, minutos: minutos,
        tarifaHora: 8000, margenPct: margen, cargoPreparacion: preparacion,
      );

  test('ejemplo de "Costo Piezas.xlsx" da lo mismo que el backend (25.300)', () {
    final r = pieza();
    expect(r.material, closeTo(4238.4, 0.01));
    expect(r.maquina, closeTo(21066.67, 0.01));
    expect(totalEncargo([r], cobroMinimo: 0), 25300);
  });

  test('margen sobre el material y cobro mínimo', () {
    expect(totalEncargo([pieza(margen: 10)], cobroMinimo: 0), 25700);
    expect(totalEncargo([pieza(gramos: 5, horas: 0, minutos: 20)], cobroMinimo: 5000), 5000);
  });

  test('mínimo, preparación y urgencia sobre el encargo (igual que el backend)', () {
    final chica = pieza(gramos: 5, horas: 0, minutos: 20);
    expect(totalEncargo([chica, chica], cobroMinimo: 5000), 6500);
    expect(totalEncargo([pieza(preparacion: 2000), pieza(preparacion: 2000)], cobroMinimo: 0), 54600);
    expect(totalEncargo([pieza()], cobroMinimo: 0, recargoUrgenciaPct: 15, urgente: true), 29100);
    expect(totalEncargo([pieza()], cobroMinimo: 0, recargoUrgenciaPct: 15), 25300);
  });

  test('formato y lectura de pesos', () {
    expect(formatoPesos(25300), r'$25.300');
    expect(formatoPesos(1234567), r'$1.234.567');
    expect(formatoPesos(900), r'$900');
    expect(leerPesos('120.000'), 120000);
    expect(leerDecimal('35,32'), 35.32);
  });
}
