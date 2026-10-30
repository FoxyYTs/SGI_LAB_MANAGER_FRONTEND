/// Cotización de impresión 3D — VISTA PREVIA del total mientras se llena el
/// formulario. Repite la fórmula de `calcular_cotizacion()` del backend
/// (operaciones/services.py); el valor que se guarda es siempre el del backend.
///
///   material = precio_rollo × gramos ÷ peso_rollo × (1 + margen %)
///   máquina  = (horas + minutos/60) × tarifa_hora
///   total    = material + máquina, a la centena, nunca menos del mínimo
({double material, double maquina, double total}) calcularCotizacion({
  required double precioRollo,
  required double pesoRolloG,
  required double gramos,
  required int horas,
  required int minutos,
  required double tarifaHora,
  required double margenPct,
  required double cobroMinimo,
}) {
  final material = pesoRolloG > 0 ? precioRollo * gramos / pesoRolloG * (1 + margenPct / 100) : 0.0;
  final maquina = (horas + minutos / 60) * tarifaHora;
  final total = ((material + maquina) / 100).round() * 100.0;
  return (material: material, maquina: maquina, total: total < cobroMinimo ? cobroMinimo : total);
}

/// "$25.300" — pesos colombianos sin decimales, punto de miles.
String formatoPesos(num valor) {
  final entero = valor.round().abs().toString();
  final conPuntos = entero.replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => '.');
  return '${valor < 0 ? '-' : ''}\$$conPuntos';
}

/// Lee un valor en pesos escrito con o sin puntos de miles ("120.000").
double? leerPesos(String texto) =>
    double.tryParse(texto.trim().replaceAll('.', '').replaceAll(',', '.'));

/// Lee un decimal con coma o punto ("35,32").
double? leerDecimal(String texto) => double.tryParse(texto.trim().replaceAll(',', '.'));
