import 'permissions.dart';

/// Secciones (pestañas) de la pantalla principal.
///
/// Qué pestañas existen depende de los permisos del usuario, así que su
/// POSICIÓN cambia de un usuario a otro: navegar con un índice fijo
/// (`onNavigateTo(2)`) llevaba a pantallas distintas según el rol. Por eso
/// se navega por identidad de sección y `MainShell` busca la posición real.
enum Seccion {
  inicio,
  inventario,
  movimientos,
  bitacora,
  horario,
  informes,
  configuracion,
}

extension SeccionPermiso on Seccion {
  /// Permiso que hace visible la pestaña (null = siempre visible).
  String? get permiso => switch (this) {
        Seccion.inicio        => null,
        Seccion.inventario    => Perm.inventarioVer,
        Seccion.movimientos   => Perm.prestamosVer,
        Seccion.bitacora      => Perm.bitacoraVer,
        Seccion.horario       => Perm.academicoVer,
        Seccion.informes      => Perm.informesVer,
        Seccion.configuracion => Perm.configuracionGestion,
      };

  /// ¿El usuario ve esta pestaña? `can` es normalmente `AuthProvider.can`.
  bool visiblePara(bool Function(String permiso) can) {
    final p = permiso;
    return p == null || can(p);
  }
}

/// Destino de una navegación hacia la pestaña de préstamos: con qué filtro
/// de estado abrirla o si abrir directamente el formulario de nuevo préstamo.
class DestinoPrestamos {
  /// Estado del filtro ('PENDIENTE', 'ACTIVO', …); null = no cambiarlo.
  final String? estado;
  final bool nuevoPrestamo;
  const DestinoPrestamos({this.estado, this.nuevoPrestamo = false});
}
