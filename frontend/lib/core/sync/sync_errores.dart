import 'dart:async';
import 'package:dio/dio.dart';

/// Qué hacer con una operación de la cola offline tras intentar ejecutarla.
enum ResultadoSync {
  /// Se aplicó (o el servidor ya estaba en el estado deseado) → COMPLETADO.
  exito,

  /// Fallo transitorio que pudo llegar al servidor → contar intento y
  /// reintentar en la próxima pasada (ERROR al tercer intento).
  reintentar,

  /// Rechazo definitivo (4xx de validación/permiso) → ERROR sin reintentos.
  fallido,

  /// No se pudo ni contactar al servidor (sin red) o la app está obsoleta
  /// (426) → dejar PENDIENTE sin gastar intentos y cortar la pasada.
  detener,
}

final _reYaEnEstado = RegExp(r'ya está en estado (\w+)');

/// Estados de préstamo que confirman que la operación ya está aplicada.
const _estadosQueConfirman = <String, Set<String>>{
  'APROBAR_PRESTAMO':  {'ACTIVO', 'DEVUELTO'},
  'RECHAZAR_PRESTAMO': {'RECHAZADO'},
};

/// Clasifica el error [error] obtenido al ejecutar la operación [operacion].
///
/// Caso especial: si un APROBAR/RECHAZAR se reintenta tras un timeout cuya
/// petición sí llegó al servidor, el reintento recibe 400 "El préstamo ya está
/// en estado ACTIVO" — la operación tuvo éxito y se marca como tal.
ResultadoSync clasificarErrorSync(String operacion, Object error) {
  if (error is TimeoutException) return ResultadoSync.reintentar;
  if (error is! DioException) return ResultadoSync.fallido;

  final status = error.response?.statusCode;
  if (status == null) {
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
        return ResultadoSync.detener;
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        return ResultadoSync.reintentar;
    }
  }

  if (status == 426) return ResultadoSync.detener;
  if (status == 401 || status == 408 || status == 429) return ResultadoSync.reintentar;
  if (status >= 500) return ResultadoSync.reintentar;

  if (status == 400) {
    final confirman = _estadosQueConfirman[operacion];
    if (confirman != null) {
      final data = error.response?.data;
      final msg  = data is Map ? '${data['error'] ?? data['detail'] ?? ''}' : '$data';
      final m    = _reYaEnEstado.firstMatch(msg);
      if (m != null && confirman.contains(m.group(1))) return ResultadoSync.exito;
    }
  }
  return ResultadoSync.fallido;
}
