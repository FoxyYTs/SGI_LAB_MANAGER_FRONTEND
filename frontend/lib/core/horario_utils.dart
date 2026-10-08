// Lógica de cálculo de bloques del horario semanal, independiente de widgets.
// Extraído de dashboard_screen.dart (DEF-013).

typedef BloqueAsg = ({int idx, int dur, List<Map<String, dynamic>> items});
typedef BloqueEnc = ({int idx, int dur, Map<String, dynamic> enc});

class HorarioUtils {
  static const horas = [7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20];

  // Fusiona horas consecutivas con el mismo contenido (asignatura/docente/grupo).
  static List<BloqueAsg> bloquesAsg(
    Map<int, List<Map<String, dynamic>>>? porHora, [
    List<int> horas = HorarioUtils.horas,
  ]) {
    final result = <BloqueAsg>[];
    int i = 0;
    while (i < horas.length) {
      final hora  = horas[i];
      final items = porHora?[hora] ?? [];
      if (items.isEmpty) { i++; continue; }
      String key(Map<String, dynamic> item) =>
          '${item['asignatura']}|${item['docente']}|${item['grupo']}';
      final keys = items.map(key).toSet();
      int dur = 1;
      while (i + dur < horas.length) {
        final next = porHora?[horas[i + dur]] ?? [];
        if (next.isNotEmpty &&
            next.map(key).toSet().containsAll(keys) &&
            keys.containsAll(next.map(key).toSet())) {
          dur++;
        } else {
          break;
        }
      }
      result.add((idx: i, dur: dur, items: items));
      i += dur;
    }
    return result;
  }

  // Genera bloques consecutivos por usuario de encargado.
  static List<BloqueEnc> bloquesEnc(
    Map<int, List<Map<String, dynamic>>> porHora, [
    List<int> horas = HorarioUtils.horas,
  ]) {
    final result = <BloqueEnc>[];
    final encMap = <int, Map<String, dynamic>>{};
    for (final items in porHora.values) {
      for (final item in items) {
        encMap[item['usuario'] as int? ?? 0] ??= item;
      }
    }
    for (final uid in encMap.keys) {
      int i = 0;
      while (i < horas.length) {
        final tiene = (porHora[horas[i]] ?? []).any((e) => e['usuario'] == uid);
        if (!tiene) { i++; continue; }
        int dur = 1;
        while (i + dur < horas.length &&
            (porHora[horas[i + dur]] ?? []).any((e) => e['usuario'] == uid)) {
          dur++;
        }
        result.add((idx: i, dur: dur, enc: encMap[uid]!));
        i += dur;
      }
    }
    return result;
  }

  // Calcula la posición horizontal (rank) de un bloque de encargado entre los
  // que se solapan con él. Determina el desplazamiento right de la franja visual.
  static int rankEnBloque(
    BloqueEnc target,
    List<BloqueEnc> todosBloquesEnc,
  ) {
    final uid = target.enc['usuario'] as int? ?? 0;
    final solapantes = todosBloquesEnc
        .where((b) {
          final bUid = b.enc['usuario'] as int? ?? 0;
          if (bUid == uid) return false;
          return b.idx < target.idx + target.dur && b.idx + b.dur > target.idx;
        })
        .map((b) => b.enc['usuario'] as int? ?? 0)
        .toSet()
        .toList()
      ..sort();
    final todos = ([uid, ...solapantes])..sort();
    return todos.indexOf(uid);
  }
}

// ── Respuestas de la API (lista o paginadas) ─────────────────────────────────
// El backend pagina por defecto (PAGE_SIZE=50) y devuelve {count, next,
// results}; algunos endpoints (horarios) devuelven la lista completa. Estas
// funciones aceptan ambos formatos para que ninguna pantalla de horarios lea
// solo la primera página.
// TODO(integración): unificar con el helper de paginación del lote A.

class ApiListas {
  /// Extrae la lista de una respuesta que puede ser `List` o `{results: [...]}`.
  static List<Map<String, dynamic>> listaDe(dynamic data) {
    final raw = data is List
        ? data
        : (data is Map ? (data['results'] ?? const []) : const []);
    return [
      for (final e in raw as List)
        if (e is Map) Map<String, dynamic>.from(e),
    ];
  }

  /// Pide todas las páginas (`?page=1,2,…`) hasta que `next` sea null.
  /// `pedir(pagina)` devuelve el `data` de la respuesta. Si la primera
  /// respuesta ya es una lista (endpoint sin paginar), se devuelve tal cual.
  /// `maxPaginas` evita un bucle infinito ante una respuesta inesperada.
  static Future<List<Map<String, dynamic>>> todasLasPaginas(
    Future<dynamic> Function(int pagina) pedir, {
    int maxPaginas = 40,
  }) async {
    final resultado = <Map<String, dynamic>>[];
    for (int pagina = 1; pagina <= maxPaginas; pagina++) {
      final data = await pedir(pagina);
      resultado.addAll(listaDe(data));
      if (data is! Map || data['next'] == null) break;
    }
    return resultado;
  }
}

// ── Seguimiento semanal de monitores ─────────────────────────────────────────

/// Fila del seguimiento semanal ya normalizada. Tolera un backend anterior
/// (sin meta fija ni desglose), en el que `horas_esperadas` eran solo las
/// horas presenciales del horario.
class SeguimientoFila {
  final double meta;
  final double presenciales;
  final double noPresenciales;
  final double registradas;

  const SeguimientoFila({
    required this.meta,
    required this.presenciales,
    required this.noPresenciales,
    required this.registradas,
  });

  static double _num(dynamic v) =>
      v is num ? v.toDouble() : (double.tryParse('${v ?? ''}') ?? 0);

  factory SeguimientoFila.desdeJson(Map<String, dynamic> m) {
    final esperadas = _num(m['horas_esperadas']);
    return SeguimientoFila(
      meta:           m.containsKey('meta_semanal') ? _num(m['meta_semanal']) : esperadas,
      presenciales:   m.containsKey('horas_presenciales') ? _num(m['horas_presenciales']) : esperadas,
      noPresenciales: _num(m['horas_no_presenciales']),
      registradas:    _num(m['horas_registradas']),
    );
  }

  double get asignadas  => presenciales + noPresenciales;
  double get sinAsignar => (meta - asignadas).clamp(0, double.infinity).toDouble();
  double get pendientes => (meta - registradas).clamp(0, double.infinity).toDouble();
  bool   get cumple     => registradas >= meta;
  /// Avance 0..1 de las horas registradas respecto a la meta.
  double get progreso   => meta <= 0 ? 1 : (registradas / meta).clamp(0, 1).toDouble();
}

/// Formato corto de horas: 10 → "10 h", 2.5 → "2.5 h".
String formatoHoras(double h) =>
    h == h.truncateToDouble() ? '${h.toInt()} h' : '${h.toStringAsFixed(1)} h';

/// Interpreta una cantidad de horas escrita por el usuario; acepta coma
/// decimal ("2,5"). Devuelve null si no es un número.
double? parseHoras(String texto) =>
    double.tryParse(texto.trim().replaceAll(',', '.'));
