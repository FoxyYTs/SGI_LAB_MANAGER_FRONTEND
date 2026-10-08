import '../core/presentaciones.dart';

/// Nombre del TipoInsumo de los residuos de laboratorio.
const kTipoResiduo = 'Residuo';

/// Modelo de dominio para un insumo del inventario.
///
/// [fromJson] construye desde la respuesta de `GET /api/inventario/lista/` (InsumoListSerializer).
/// [fromLocal] construye desde la tabla `insumos_cache` del SQLite local.
/// [toLocal] serializa al formato de la tabla local para cacheo offline.
class Insumo {
  final String id;
  final String nombre;
  final String tipo;
  final String ubicacion;
  final String unidad;
  final double stockActual;
  final double stockMinimo;
  final String semaforo;
  final bool   activo;
  final bool   tieneSga;
  final String? observaciones;
  final String? fotoUrl;
  final String formulaQuimica;
  /// Presentaciones tal como llegan del backend (`id`, `unidad_nombre`,
  /// `stock_actual`, `activa`). null = desconocidas (insumo leído de la
  /// caché offline, que no las guarda): en ese caso el préstamo se envía
  /// solo con `insumo` y el backend usa la primera presentación activa.
  final List<Map<String, dynamic>>? presentaciones;

  const Insumo({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.ubicacion,
    required this.unidad,
    required this.stockActual,
    required this.stockMinimo,
    required this.semaforo,
    required this.activo,
    this.tieneSga = false,
    this.observaciones,
    this.fotoUrl,
    this.formulaQuimica = '',
    this.presentaciones,
  });

  /// Residuo de laboratorio (tipo "Residuo"): no se presta y no tiene
  /// semáforo de stock (el backend devuelve VERDE por compatibilidad).
  bool get esResiduo => tipo == kTipoResiduo;

  /// Químicos y residuos tienen ficha SGA y etiqueta.
  bool get usaSga => tipo == 'Químico' || esResiduo;

  /// Estado a mostrar: el semáforo, o 'RESIDUO' para los residuos.
  String get estado => esResiduo ? 'RESIDUO' : semaforo;

  factory Insumo.fromJson(Map<String, dynamic> json) {
    // La unidad viene de la primera presentación ACTIVA (las desactivadas
    // no cuentan en stock_total); si no hay activas, de la primera.
    final presentaciones = json['presentaciones'] as List?;
    final activas = presentacionesActivas(presentaciones);
    final referencia = activas.isNotEmpty
        ? activas.first
        : (presentaciones?.isNotEmpty == true ? presentaciones!.first as Map : null);
    final primeraUnidad = referencia != null
        ? referencia['unidad_nombre'] as String? ?? ''
        : json['unidad_abreviatura'] as String? ?? '';

    // stock_total es la suma de presentaciones; fallback a stock_actual legacy
    final stockRaw = json['stock_total'] ?? json['stock_actual'] ?? 0;

    return Insumo(
      id:          json['id'] as String,
      nombre:      json['nombre_insumo'] as String,
      tipo:        json['tipo_nombre'] as String? ?? 'General',
      ubicacion:   json['ubicacion_nombre'] as String? ?? 'Sin ubicación',
      unidad:      primeraUnidad,
      stockActual: double.parse(stockRaw.toString()),
      stockMinimo: double.parse(json['stock_minimo'].toString()),
      semaforo:    json['semaforo'] as String,
      activo:      json['activo'] as bool? ?? true,
      tieneSga:    json['tiene_sga'] as bool? ?? false,
      observaciones: json['observaciones'] as String?,
      fotoUrl:     json['foto'] as String?,
      formulaQuimica: json['formula_quimica'] as String? ?? '',
      presentaciones: presentaciones
          ?.whereType<Map>()
          .map((p) => Map<String, dynamic>.from(p))
          .toList(),
    );
  }

  factory Insumo.fromLocal(Map<String, dynamic> row) => Insumo(
    id:          row['id'] as String,
    nombre:      row['nombre'] as String,
    tipo:        row['tipo'] as String,
    ubicacion:   row['ubicacion'] as String? ?? '',
    unidad:      row['unidad'] as String? ?? '',
    stockActual: (row['stock'] as num).toDouble(),
    stockMinimo: (row['stock_min'] as num).toDouble(),
    semaforo:    row['semaforo'] as String,
    activo:      (row['activo'] as int) == 1,
  );

  Map<String, dynamic> toLocal() => {
    'id':        id,
    'nombre':    nombre,
    'tipo':      tipo,
    'ubicacion': ubicacion,
    'unidad':    unidad,
    'stock':     stockActual,
    'stock_min': stockMinimo,
    'semaforo':  semaforo,
    'activo':    activo ? 1 : 0,
    'cached_at': DateTime.now().millisecondsSinceEpoch,
  };
}
