import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/sync/sync_errores.dart';

DioException _http(int status, [Object? data]) {
  final ro = RequestOptions(path: '/x');
  return DioException(
    requestOptions: ro,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: ro, statusCode: status, data: data),
  );
}

DioException _red(DioExceptionType t) =>
    DioException(requestOptions: RequestOptions(path: '/x'), type: t);

void main() {
  group('clasificarErrorSync', () {
    test('reintento de APROBAR que ya se aplicó cuenta como éxito', () {
      final e = _http(400, {'error': 'El préstamo ya está en estado ACTIVO.'});
      expect(clasificarErrorSync('APROBAR_PRESTAMO', e), ResultadoSync.exito);
      final e2 = _http(400, {'error': 'El préstamo ya está en estado DEVUELTO.'});
      expect(clasificarErrorSync('APROBAR_PRESTAMO', e2), ResultadoSync.exito);
    });

    test('APROBAR de un préstamo que otro rechazó es fallo definitivo', () {
      final e = _http(400, {'error': 'El préstamo ya está en estado RECHAZADO.'});
      expect(clasificarErrorSync('APROBAR_PRESTAMO', e), ResultadoSync.fallido);
    });

    test('RECHAZAR ya rechazado → éxito; ya aprobado → fallido', () {
      expect(
        clasificarErrorSync('RECHAZAR_PRESTAMO',
            _http(400, {'error': 'El préstamo ya está en estado RECHAZADO.'})),
        ResultadoSync.exito,
      );
      expect(
        clasificarErrorSync('RECHAZAR_PRESTAMO',
            _http(400, {'error': 'El préstamo ya está en estado ACTIVO.'})),
        ResultadoSync.fallido,
      );
    });

    test('4xx de validación no se reintenta', () {
      for (final s in [400, 403, 404, 409, 422]) {
        expect(clasificarErrorSync('PRESTAMO', _http(s, {'detail': 'x'})),
            ResultadoSync.fallido, reason: 'status $s');
      }
    });

    test('401 / 408 / 429 / 5xx se reintentan', () {
      for (final s in [401, 408, 429, 500, 502, 503, 530]) {
        expect(clasificarErrorSync('PRESTAMO', _http(s)), ResultadoSync.reintentar,
            reason: 'status $s');
      }
    });

    test('426 (app obsoleta) detiene la cola sin gastar intentos', () {
      expect(clasificarErrorSync('PRESTAMO', _http(426)), ResultadoSync.detener);
    });

    test('sin red detiene; timeouts de respuesta se reintentan', () {
      expect(clasificarErrorSync('PRESTAMO', _red(DioExceptionType.connectionError)),
          ResultadoSync.detener);
      expect(clasificarErrorSync('PRESTAMO', _red(DioExceptionType.connectionTimeout)),
          ResultadoSync.detener);
      expect(clasificarErrorSync('PRESTAMO', _red(DioExceptionType.receiveTimeout)),
          ResultadoSync.reintentar);
      expect(clasificarErrorSync('PRESTAMO', TimeoutException('x')),
          ResultadoSync.reintentar);
    });

    test('errores no HTTP (operación desconocida, parseo) son definitivos', () {
      expect(clasificarErrorSync('XYZ', Exception('Operación desconocida')),
          ResultadoSync.fallido);
    });
  });
}
