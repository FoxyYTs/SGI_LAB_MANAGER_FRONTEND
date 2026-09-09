/// Códigos de permiso — deben coincidir exactamente con los que devuelve
/// GET /api/usuarios/mis-permisos/
class Perm {
  static const inventarioVer        = 'inventario.ver';
  static const inventarioGestionar  = 'inventario.gestionar';
  static const prestamosVer         = 'prestamos.ver';
  static const prestamosGestionar   = 'prestamos.gestionar';
  static const bitacoraVer          = 'bitacora.ver';
  static const bitacoraGestionar    = 'bitacora.gestionar';
  static const academicoVer         = 'academico.ver';
  static const academicoGestionar   = 'academico.gestionar';
  static const configuracionGestion = 'configuracion.gestion';
  static const configuracionRoles   = 'configuracion.roles';
  static const informesVer          = 'informes.ver';
  static const informesGestionar    = 'informes.gestionar';

  /// Todos los permisos disponibles en el sistema
  static const todos = [
    inventarioVer, inventarioGestionar,
    prestamosVer, prestamosGestionar,
    bitacoraVer, bitacoraGestionar,
    academicoVer, academicoGestionar,
    configuracionGestion, configuracionRoles,
    informesVer, informesGestionar,
  ];

  /// Nombre legible para mostrar en la UI
  static String nombre(String codigo) => const {
    'inventario.ver':        'Ver inventario',
    'inventario.gestionar':  'Gestionar inventario',
    'prestamos.ver':         'Ver préstamos',
    'prestamos.gestionar':   'Gestionar préstamos',
    'bitacora.ver':          'Ver bitácora',
    'bitacora.gestionar':    'Gestionar bitácora',
    'academico.ver':         'Ver módulo académico',
    'academico.gestionar':   'Gestionar módulo académico',
    'configuracion.gestion': 'Acceder a configuración',
    'configuracion.roles':   'Gestionar permisos',
    'informes.ver':          'Ver informes',
    'informes.gestionar':    'Gestionar informes',
  }[codigo] ?? codigo;

  /// Descripción de qué habilita cada permiso — debe coincidir con
  /// PERMISOS en backend/usuarios/management/commands/seed_permisos.py
  static String descripcion(String codigo) => const {
    'inventario.ver':        'Acceder al listado de insumos y su stock',
    'inventario.gestionar':  'Crear, editar y eliminar insumos, tipos, ubicaciones y unidades',
    'prestamos.ver':         'Consultar el listado de préstamos y devoluciones',
    'prestamos.gestionar':   'Aprobar, rechazar y registrar devoluciones',
    'bitacora.ver':          'Consultar el historial de movimientos de inventario',
    'bitacora.gestionar':    'Registrar movimientos manuales (entrada, ajuste, rotura)',
    'academico.ver':         'Consultar áreas, asignaturas y guías de práctica',
    'academico.gestionar':   'Crear y editar áreas, asignaturas y guías',
    'configuracion.gestion': 'Gestionar tipos de insumo, ubicaciones y unidades de medida',
    'configuracion.roles':   'Modificar permisos por rol y por usuario',
    'informes.ver':          'Generar y descargar informes PDF del sistema',
    'informes.gestionar':    'Subir y eliminar informes manuales',
  }[codigo] ?? '';
}
