/// Impresión 3D — VISTA PREVIA del total mientras se llena el formulario.
/// Repite `calcular_pieza()` y `total_encargo()` del backend
/// (operaciones/services.py); el valor que se guarda es siempre el del backend.
///
///   por pieza:  material    = precio_rollo × gramos ÷ peso_rollo × (1 + margen %)
///               máquina     = (horas + minutos/60) × tarifa_hora
///               preparación = cargo fijo por pieza
///   encargo:    suma × (1 + recargo % si es urgente), a la centena,
///               nunca menos del mínimo
({double material, double maquina, double preparacion}) calcularPieza({
  required double precioRollo,
  required double pesoRolloG,
  required double gramos,
  required int horas,
  required int minutos,
  required double tarifaHora,
  required double margenPct,
  double cargoPreparacion = 0,
}) {
  final material = pesoRolloG > 0 ? precioRollo * gramos / pesoRolloG * (1 + margenPct / 100) : 0.0;
  final maquina = (horas + minutos / 60) * tarifaHora;
  return (material: material, maquina: maquina, preparacion: cargoPreparacion);
}

/// Total del encargo a partir de los costos de sus piezas.
double totalEncargo(
  Iterable<({double material, double maquina, double preparacion})> piezas, {
  required double cobroMinimo,
  double recargoUrgenciaPct = 0,
  bool urgente = false,
}) {
  var suma = piezas.fold(0.0, (s, p) => s + p.material + p.maquina + p.preparacion);
  if (urgente) suma *= 1 + recargoUrgenciaPct / 100;
  final total = (suma / 100).round() * 100.0;
  return total < cobroMinimo ? cobroMinimo : total;
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

/// Estados del trabajo de un encargo (CotizacionImpresion.Estado en el backend).
const estadosTrabajoImpresion = {
  'COTIZADO': 'Cotizado',
  'EN_IMPRESION': 'En impresión',
  'LISTO': 'Listo para recoger',
  'ENTREGADO': 'Entregado',
};

/// Estados del pago, calculados por el backend a partir de los abonos.
const estadosPagoImpresion = {
  'PENDIENTE': 'Pendiente',
  'ABONADO': 'Abonado',
  'PAGADO': 'Pagado',
};
