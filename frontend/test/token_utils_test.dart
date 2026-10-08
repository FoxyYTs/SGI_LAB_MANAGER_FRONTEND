import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/token_utils.dart';

String _jwt(Map<String, dynamic> payload) {
  String b64(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${b64({'alg': 'HS256'})}.${b64(payload)}.firma';
}

void main() {
  group('esRechazoDeRefresh', () {
    test('401 del endpoint de refresh cierra sesión', () {
      expect(esRechazoDeRefresh(401, {'code': 'token_not_valid'}), isTrue);
      expect(esRechazoDeRefresh(401, null), isTrue);
    });

    test('400 de simplejwt (token_not_valid o campo refresh) cierra sesión', () {
      expect(esRechazoDeRefresh(400, {'code': 'token_not_valid'}), isTrue);
      expect(esRechazoDeRefresh(400, {'refresh': ['Este campo es requerido.']}), isTrue);
    });

    test('400 genérico (p. ej. de un proxy) no cierra sesión', () {
      expect(esRechazoDeRefresh(400, '<html>Bad Request</html>'), isFalse);
      expect(esRechazoDeRefresh(400, {'detail': 'otra cosa'}), isFalse);
    });

    test('errores transitorios no cierran sesión', () {
      for (final s in [null, 403, 404, 408, 426, 429, 500, 502, 503, 504, 521, 530]) {
        expect(esRechazoDeRefresh(s, null), isFalse, reason: 'status $s');
      }
    });
  });

  group('jwtExpiraPronto', () {
    final ahora = DateTime.utc(2026, 10, 7, 12);
    int seg(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

    test('lee exp del payload', () {
      final t = _jwt({'exp': seg(ahora)});
      expect(jwtExpiracion(t), ahora);
    });

    test('vigente con más margen que el pedido', () {
      final t = _jwt({'exp': seg(ahora.add(const Duration(hours: 1)))});
      expect(jwtExpiraPronto(t, ahora: ahora), isFalse);
    });

    test('caducado o a punto de caducar', () {
      expect(jwtExpiraPronto(_jwt({'exp': seg(ahora.subtract(const Duration(minutes: 1)))}), ahora: ahora), isTrue);
      expect(jwtExpiraPronto(_jwt({'exp': seg(ahora.add(const Duration(seconds: 30)))}), ahora: ahora), isTrue);
    });

    test('token ilegible → no se considera caducado', () {
      expect(jwtExpiracion('no-es-un-jwt'), isNull);
      expect(jwtExpiraPronto('no-es-un-jwt', ahora: ahora), isFalse);
      expect(jwtExpiraPronto(_jwt({'sub': 1}), ahora: ahora), isFalse);
    });
  });
}
