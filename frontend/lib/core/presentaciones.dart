/// Utilidades para las presentaciones de un insumo (frasco 500 mL, caja 50 u…).
///
/// Las presentaciones llegan como mapas JSON desde dos fuentes:
///  - `inventario/lista/` y el detalle (personal): `id`, `unidad_nombre`,
///    `stock_actual`, `activa`.
///  - `inventario/lista-publica/` (formularios QR): `id`, `unidad_nombre`,
///    `disponible` (booleano, sin cifra de stock) y solo las activas.
///
/// Un backend anterior a la desactivación no manda `activa`: se asume activa.
library;

/// `true` salvo que la presentación venga marcada explícitamente inactiva.
bool presentacionActiva(Map p) => p['activa'] != false;

/// Presentaciones activas de [lista] (vacía si es null), en el mismo orden.
List<Map<String, dynamic>> presentacionesActivas(List? lista) => [
      for (final p in lista ?? const [])
        if (p is Map && presentacionActiva(p)) Map<String, dynamic>.from(p),
    ];

/// ¿Hay existencias? Usa `disponible` (catálogo público) o, si no viene,
/// `stock_actual > 0`. Devuelve null si la respuesta no trae ninguno de los
/// dos (backend viejo): en ese caso no se muestra "agotado".
bool? presentacionDisponible(Map p) {
  final disp = p['disponible'];
  if (disp is bool) return disp && presentacionActiva(p);
  final stock = double.tryParse(p['stock_actual']?.toString() ?? '');
  if (stock == null) return null;
  return stock > 0 && presentacionActiva(p);
}

/// Presentación a preseleccionar al elegir un insumo: la primera activa
/// con existencias y, si ninguna tiene, la primera activa. null si el
/// insumo no tiene presentaciones activas.
Map<String, dynamic>? presentacionPorDefecto(List? lista) {
  final activas = presentacionesActivas(lista);
  if (activas.isEmpty) return null;
  for (final p in activas) {
    if (presentacionDisponible(p) == true) return p;
  }
  return activas.first;
}

/// Disponibilidad del insumo completo para el selector: true si alguna
/// presentación activa tiene existencias, false si todas están agotadas,
/// null si no se sabe.
bool? insumoDisponible(List? lista) {
  final activas = presentacionesActivas(lista);
  if (activas.isEmpty) return false;
  var desconocido = false;
  for (final p in activas) {
    final d = presentacionDisponible(p);
    if (d == true) return true;
    if (d == null) desconocido = true;
  }
  return desconocido ? null : false;
}
