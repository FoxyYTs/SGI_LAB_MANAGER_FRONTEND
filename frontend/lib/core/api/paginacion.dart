import 'package:dio/dio.dart';

/// Utilidades para leer listados del backend que pueden venir como lista
/// plana (`[...]`, catálogos con `pagination_class = None`) o paginados por
/// DRF (`{count, next, previous, results: [...]}`, PAGE_SIZE=50).
///
/// Antes cada pantalla hacía `data is List ? data : data['results']` y
/// nunca seguía `next`, así que solo veía los primeros 50 registros.
/// Este archivo es Dart puro (solo Dio) para poder usarse también desde el
/// isolate de tareas en segundo plano.

/// Extrae los elementos de una respuesta, sea lista plana o paginada.
/// Cualquier otra forma (null, error, mapa sin `results`) devuelve `[]`.
List<Map<String, dynamic>> listaDeRespuesta(dynamic data) {
  final List raw;
  if (data is List) {
    raw = data;
  } else if (data is Map && data['results'] is List) {
    raw = data['results'] as List;
  } else {
    return [];
  }
  return raw
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

/// `true` si la respuesta es paginada y existe una página siguiente.
bool hayPaginaSiguiente(dynamic data) => data is Map && data['next'] != null;

/// Resultado de pedir UNA página de un listado paginado.
class PaginaResultado {
  final List<Map<String, dynamic>> items;
  final bool hayMas;
  final int? total;
  const PaginaResultado(this.items, {required this.hayMas, this.total});
}

/// Pide la página [pagina] (1-based) de [path].
///
/// Usa el parámetro `page` en lugar de la URL absoluta de `next`: detrás
/// del proxy (Cloudflare → nginx) DRF puede construir `next` con otro
/// esquema/host, y así siempre se respeta el `baseUrl` del cliente.
Future<PaginaResultado> obtenerPagina(
  Dio dio,
  String path, {
  Map<String, dynamic>? queryParameters,
  int pagina = 1,
}) async {
  final r = await dio.get(path, queryParameters: {
    ...?queryParameters,
    if (pagina > 1) 'page': pagina,
  });
  final data = r.data;
  return PaginaResultado(
    listaDeRespuesta(data),
    hayMas: hayPaginaSiguiente(data),
    total: data is Map ? (data['count'] as num?)?.toInt() : null,
  );
}

/// Devuelve TODOS los elementos de [path], recorriendo las páginas si la
/// respuesta es paginada. Si es una lista plana hace una sola petición.
///
/// [maxPaginas] es un tope de seguridad (evita un bucle infinito si el
/// servidor respondiera mal); con 50 por página, 200 páginas = 10.000.
Future<List<Map<String, dynamic>>> obtenerTodas(
  Dio dio,
  String path, {
  Map<String, dynamic>? queryParameters,
  int maxPaginas = 200,
}) async {
  final todos = <Map<String, dynamic>>[];
  for (var pagina = 1; pagina <= maxPaginas; pagina++) {
    final res = await obtenerPagina(dio, path,
        queryParameters: queryParameters, pagina: pagina);
    todos.addAll(res.items);
    if (!res.hayMas) break;
  }
  return todos;
}
