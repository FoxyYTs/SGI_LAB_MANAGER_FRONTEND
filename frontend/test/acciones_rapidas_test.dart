import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/permissions.dart';
import 'package:frontend/core/secciones.dart';
import 'package:frontend/screens/dashboard_screen.dart';

/// Permisos por defecto de cada rol (seed_permisos del backend).
const _monitor = {
  Perm.inventarioVer, Perm.prestamosVer, Perm.prestamosGestionar,
  Perm.bitacoraVer, Perm.academicoVer,
};

void main() {
  group('accionesRapidasPara', () {
    test('con todos los permisos aparecen todas, en orden', () {
      expect(accionesRapidasPara(Perm.todos.contains), AccionRapida.values);
    });

    test('monitor: sin bitacora.gestionar no ve registrar entrada/salida', () {
      expect(accionesRapidasPara(_monitor.contains), [
        AccionRapida.nuevoPrestamo,
        AccionRapida.aprobarPrestamos,
        AccionRapida.registrarDevolucion,
        AccionRapida.buscarInsumo,
        AccionRapida.verBitacora,
      ]);
    });

    test('solo ver préstamos: nuevo préstamo pero no aprobar ni devolver', () {
      expect(accionesRapidasPara({Perm.prestamosVer}.contains),
          [AccionRapida.nuevoPrestamo]);
    });

    test('bitacora.gestionar sin inventario.ver no permite el buscador', () {
      expect(accionesRapidasPara({Perm.bitacoraGestionar}.contains), isEmpty);
    });

    test('sin permisos no hay acciones', () {
      expect(accionesRapidasPara((_) => false), isEmpty);
    });
  });

  group('Seccion.visiblePara', () {
    test('inicio siempre; el resto según su permiso', () {
      bool ninguno(String _) => false;
      expect(Seccion.inicio.visiblePara(ninguno), isTrue);
      for (final s in Seccion.values.where((s) => s != Seccion.inicio)) {
        expect(s.visiblePara(ninguno), isFalse, reason: s.name);
        expect(s.visiblePara((p) => p == s.permiso), isTrue, reason: s.name);
      }
    });

    test('movimientos depende de prestamos.ver y bitácora de bitacora.ver', () {
      expect(Seccion.movimientos.permiso, Perm.prestamosVer);
      expect(Seccion.bitacora.permiso, Perm.bitacoraVer);
      expect(Seccion.horario.permiso, Perm.academicoVer);
    });
  });
}
