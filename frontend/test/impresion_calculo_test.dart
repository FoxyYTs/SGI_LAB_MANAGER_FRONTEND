import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/impresion_calculo.dart';

void main() {
  ({double material, double maquina, double total}) calc({
    double gramos = 35.32, int horas = 2, int minutos = 38,
    double margen = 0, double minimo = 0,
  }) =>
      calcularCotizacion(
        precioRollo: 120000, pesoRolloG: 1000, gramos: gramos, horas: horas, minutos: minutos,
        tarifaHora: 8000, margenPct: margen, cobroMinimo: minimo,
      );

  test('ejemplo de "Costo Piezas.xlsx" da lo mismo que el backend (25.300)', () {
    final r = calc();
    expect(r.material, closeTo(4238.4, 0.01));
    expect(r.maquina, closeTo(21066.67, 0.01));
    expect(r.total, 25300);
  });

  test('margen sobre el material y cobro mínimo', () {
    expect(calc(margen: 10).total, 25700);
    expect(calc(gramos: 5, horas: 0, minutos: 20, minimo: 5000).total, 5000);
  });

  test('formato y lectura de pesos', () {
    expect(formatoPesos(25300), r'$25.300');
    expect(formatoPesos(1234567), r'$1.234.567');
    expect(formatoPesos(900), r'$900');
    expect(leerPesos('120.000'), 120000);
    expect(leerDecimal('35,32'), 35.32);
  });
}
