class Insumo {
  final String id;
  final String nombre;
  final String tipo;
  final String ubicacion;
  final double stockActual;
  final double stockMinimo;
  final String semaforo; // "ROJO", "AMARILLO", "VERDE"
  final String? observaciones;

  Insumo({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.ubicacion,
    required this.stockActual,
    required this.stockMinimo,
    required this.semaforo,
    this.observaciones,
  });

  // Constructor para convertir de JSON (Django) a Objeto (Flutter)
  factory Insumo.fromJson(Map<String, dynamic> json) {
    return Insumo(
      id: json['id'],
      nombre: json['nombre_insumo'],
      tipo: json['tipo_nombre'] ?? 'General',
      ubicacion: json['ubicacion_nombre'] ?? 'Sin ubicación',
      stockActual: double.parse(json['stock_actual'].toString()),
      stockMinimo: double.parse(json['stock_minimo'].toString()),
      semaforo: json['semaforo'],
      observaciones: json['observaciones'],
    );
  }
}