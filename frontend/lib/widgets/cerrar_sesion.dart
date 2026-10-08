import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/sync/sync_service.dart';
import '../core/theme/colors.dart';
import '../providers/auth_provider.dart';

/// Opciones del aviso de operaciones sin sincronizar.
enum DecisionPendientes { reintentar, cancelar, cerrarIgual }

/// Nombre legible de cada operación de la cola offline (ver
/// SyncService._ejecutar).
const _nombreOperacion = {
  'APROBAR_PRESTAMO':  'aprobar préstamos',
  'RECHAZAR_PRESTAMO': 'rechazar préstamos',
  'PRESTAMO':          'registrar préstamos',
  'DEVOLUCION':        'devoluciones',
  'AJUSTE_STOCK':      'ajustes de stock',
};

/// Texto del aviso: "Tienes N operaciones sin sincronizar (aprobar
/// préstamos, devoluciones). Si cierras sesión se perderán."
/// [operaciones] = el campo `operacion` de las filas PENDIENTE de la cola.
String mensajeOperacionesPendientes(int n, Iterable<String> operaciones) {
  final tipos = <String>[];
  for (final op in operaciones) {
    final nombre = _nombreOperacion[op] ?? op.toLowerCase();
    if (!tipos.contains(nombre)) tipos.add(nombre);
  }
  final cuantas = n == 1 ? '1 operación' : '$n operaciones';
  final detalle = tipos.isEmpty ? '' : ' (${tipos.join(', ')})';
  return 'Tienes $cuantas sin sincronizar$detalle. '
      'Si cierras sesión se perderán.';
}

/// Cierre de sesión VOLUNTARIO (botones "Cerrar sesión").
///
/// En Android, antes de cerrar intenta subir la cola offline (máx. 10 s). Si
/// siguen quedando operaciones pendientes, pregunta al usuario: reintentar,
/// cancelar o cerrar igual (perdiéndolas, porque logout() borra la cola para
/// que el siguiente usuario del dispositivo no las ejecute con su identidad).
///
/// Los cierres forzados (refresh rechazado, expiración web a medianoche,
/// sesión web sin fecha) llaman a [AuthProvider.logout] directamente y no
/// muestran este aviso. En web la cola es no-op, así que tampoco aparece.
///
/// Devuelve `true` si la sesión se cerró, `false` si el usuario canceló.
Future<bool> cerrarSesionVoluntaria(BuildContext context) async {
  final auth = context.read<AuthProvider>();
  if (!kIsWeb) {
    while (true) {
      if (!context.mounted) return false;
      final pendientes = await _sincronizarConProgreso(context, auth);
      if (pendientes == 0) break;
      if (!context.mounted) return false;

      final cola = await SyncService.instance.historialCola();
      final ops = cola
          .where((f) => f['estado'] == 'PENDIENTE')
          .map((f) => '${f['operacion']}');
      if (!context.mounted) return false;

      final decision = await mostrarAvisoPendientes(
        context,
        mensajeOperacionesPendientes(pendientes, ops),
        sinConexion: !SyncService.instance.online,
      );
      switch (decision) {
        case DecisionPendientes.reintentar:
          continue;
        case DecisionPendientes.cerrarIgual:
          await auth.logout(sincronizarAntes: false);
          return true;
        case DecisionPendientes.cancelar:
        case null:
          return false;
      }
    }
  }
  await auth.logout();
  return true;
}

/// Sincroniza mostrando un diálogo de progreso (solo si hay algo pendiente)
/// y devuelve cuántas operaciones siguen sin sincronizar.
Future<int> _sincronizarConProgreso(BuildContext context, AuthProvider auth) async {
  if (SyncService.instance.pending == 0) return 0;
  final nav = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(children: [
          SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: kPrimary)),
          SizedBox(width: 16),
          Expanded(child: Text('Sincronizando operaciones pendientes…')),
        ]),
      ),
    ),
  );
  try {
    return await auth.sincronizarPendientes();
  } finally {
    if (nav.mounted) nav.pop();
  }
}

/// Diálogo "Tienes N operaciones sin sincronizar…" con las tres opciones.
Future<DecisionPendientes?> mostrarAvisoPendientes(
  BuildContext context,
  String mensaje, {
  bool sinConexion = false,
}) {
  return showDialog<DecisionPendientes>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Operaciones sin sincronizar'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(mensaje),
          if (sinConexion) ...[
            const SizedBox(height: 8),
            const Text('No hay conexión: conéctate a internet y reintenta.',
                style: TextStyle(color: kTextMuted, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, DecisionPendientes.cancelar),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, DecisionPendientes.cerrarIgual),
          child: const Text('Cerrar sesión igual', style: TextStyle(color: kDanger)),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, DecisionPendientes.reintentar),
          child: const Text('Reintentar sincronizar'),
        ),
      ],
    ),
  );
}
