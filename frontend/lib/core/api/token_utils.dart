import 'dart:convert';

/// Utilidades puras (sin Flutter ni plugins) para manejar los JWT de la sesión.
/// Se usan tanto en el isolate principal (ApiClient/AuthProvider) como en el
/// isolate de Workmanager (background_tasks.dart), por eso no dependen de nada
/// más que `dart:convert`.

/// Decide si un fallo del endpoint `token/refresh/` significa que la sesión
/// ya no es válida (refresh expirado, blacklisteado o ausente) y por tanto
/// hay que cerrar sesión.
///
/// Solo el propio servidor de autenticación puede decir eso:
/// - **401** → simplejwt rechazó el refresh (`token_not_valid`).
/// - **400** → solo si el cuerpo es el de simplejwt (`code: token_not_valid`)
///   o un error de validación sobre el campo `refresh`.
///
/// Cualquier otra cosa (sin respuesta por red/timeout, 5xx, 52x de Cloudflare,
/// 429, 426, un 400 de un proxy…) es transitoria: NO debe cerrar la sesión.
bool esRechazoDeRefresh(int? status, Object? data) {
  if (status == 401) return true;
  if (status == 400 && data is Map) {
    if (data['code'] == 'token_not_valid') return true;
    if (data.containsKey('refresh')) return true;
  }
  return false;
}

/// Fecha de expiración (`exp`, UTC) de un JWT, o `null` si no se puede leer.
/// No valida la firma: solo sirve para decidir si conviene refrescar antes.
DateTime? jwtExpiracion(String token) {
  try {
    final partes = token.split('.');
    if (partes.length != 3) return null;
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(partes[1])));
    final json = jsonDecode(payload);
    if (json is! Map) return null;
    final exp = json['exp'];
    if (exp is! num) return null;
    return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
  } catch (_) {
    return null;
  }
}

/// `true` si el JWT ya expiró o expira dentro de [margen].
/// Si no se puede leer `exp` devuelve `false` (se usa tal cual y, si el
/// servidor lo rechaza, el llamador se entera por el 401).
bool jwtExpiraPronto(
  String token, {
  DateTime? ahora,
  Duration margen = const Duration(minutes: 2),
}) {
  final exp = jwtExpiracion(token);
  if (exp == null) return false;
  final now = (ahora ?? DateTime.now()).toUtc();
  return !exp.isAfter(now.add(margen));
}
