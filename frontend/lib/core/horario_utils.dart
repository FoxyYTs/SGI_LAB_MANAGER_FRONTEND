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
