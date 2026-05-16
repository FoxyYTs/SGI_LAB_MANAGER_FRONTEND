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

  /// Todos los permisos disponibles en el sistema
  static const todos = [
    inventarioVer, inventarioGestionar,
    prestamosVer, prestamosGestionar,
    bitacoraVer, bitacoraGestionar,
    academicoVer, academicoGestionar,
    configuracionGestion, configuracionRoles,
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
  }[codigo] ?? codigo;
}
