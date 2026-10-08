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

// ── Rangos de horas (asignar varios días, editar bloque, "Mi semana") ────────
//
// Convención (igual que el backend): un rango va de `inicio` a `fin` con
// `fin` EXCLUSIVO — "8–11" son los bloques de 8, 9 y 10. Rango válido del
// laboratorio: 6 ≤ inicio < fin ≤ 22 (el último bloque es 21:00–22:00).

const kHoraMinLab = 6;
const kHoraFinMaxLab = 22;
const kNombresDia = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];
const kInicialesDia = ['L', 'M', 'X', 'J', 'V', 'S'];
const kDiasCortos = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];

/// Hora en formato 12 h corto: 8 → "8 AM", 12 → "12 PM", 14 → "2 PM".
String horaAmPm(int hora) {
  if (hora == 12) return '12 PM';
  if (hora == 24) return '12 AM';
  if (hora > 12) return '${hora - 12} PM';
  return '$hora AM';
}

/// Rango de horas de un día (fin exclusivo).
class RangoHoras {
  final int dia;
  final int inicio;
  final int fin;
  const RangoHoras(this.dia, this.inicio, this.fin);

  int get duracion => fin - inicio;
  List<int> get horas => [for (int h = inicio; h < fin; h++) h];
  bool contiene(int hora) => hora >= inicio && hora < fin;

  /// "8 AM – 11 AM".
  String get texto => '${horaAmPm(inicio)} – ${horaAmPm(fin)}';

  /// "Lunes 8 AM – 11 AM".
  String get textoConDia =>
      '${dia >= 0 && dia < kNombresDia.length ? kNombresDia[dia] : 'Día $dia'} $texto';

  @override
  bool operator ==(Object other) =>
      other is RangoHoras && other.dia == dia && other.inicio == inicio && other.fin == fin;

  @override
  int get hashCode => Object.hash(dia, inicio, fin);

  @override
  String toString() => 'RangoHoras($dia, $inicio–$fin)';
}

class RangosHorario {
  /// Fusiona bloques sueltos (día, hora) en rangos consecutivos, ordenados
  /// por día y hora. Ignora duplicados.
  static List<RangoHoras> fusionar(Iterable<({int dia, int hora})> bloques) {
    final porDia = <int, Set<int>>{};
    for (final b in bloques) {
      porDia.putIfAbsent(b.dia, () => <int>{}).add(b.hora);
    }
    final dias = porDia.keys.toList()..sort();
    final result = <RangoHoras>[];
    for (final d in dias) {
      final horas = porDia[d]!.toList()..sort();
      int ini = horas.first, prev = horas.first;
      for (final h in horas.skip(1)) {
        if (h == prev + 1) { prev = h; continue; }
        result.add(RangoHoras(d, ini, prev + 1));
        ini = prev = h;
      }
      result.add(RangoHoras(d, ini, prev + 1));
    }
    return result;
  }

  /// Igual que [fusionar], a partir de filas del API ({dia_semana, hora}).
  static List<RangoHoras> desdeFilas(Iterable<Map<String, dynamic>> filas) => fusionar([
        for (final f in filas)
          if (f['dia_semana'] is int && f['hora'] is int)
            (dia: f['dia_semana'] as int, hora: f['hora'] as int),
      ]);

  /// Rango consecutivo que contiene `hora` dentro de `horasDelDia` (las
  /// horas que una persona tiene ese día). null si `hora` no está.
  static RangoHoras? rangoQueContiene(Set<int> horasDelDia, int dia, int hora) {
    if (!horasDelDia.contains(hora)) return null;
    int ini = hora, fin = hora + 1;
    while (horasDelDia.contains(ini - 1)) { ini--; }
    while (horasDelDia.contains(fin)) { fin++; }
    return RangoHoras(dia, ini, fin);
  }

  /// Mensaje de error del rango o null si es válido.
  static String? validar(int? inicio, int? fin) {
    if (inicio == null || fin == null) return 'Elige la hora de inicio y la de fin';
    if (inicio < kHoraMinLab || inicio >= kHoraFinMaxLab) {
      return 'La hora de inicio debe estar entre ${horaAmPm(kHoraMinLab)} y ${horaAmPm(kHoraFinMaxLab - 1)}';
    }
    if (fin > kHoraFinMaxLab) return 'La hora de fin no puede pasar de ${horaAmPm(kHoraFinMaxLab)}';
    if (fin <= inicio) return 'La hora de fin debe ser posterior a la de inicio';
    return null;
  }

  /// Opciones válidas de hora de fin para un inicio dado.
  static List<int> finesPosibles(int inicio) =>
      [for (int h = inicio + 1; h <= kHoraFinMaxLab; h++) h];

  /// Opciones de hora de inicio.
  static List<int> get iniciosPosibles =>
      [for (int h = kHoraMinLab; h < kHoraFinMaxLab; h++) h];

  /// Bloques de 1 h que se intentarán crear (antes de descontar los que ya
  /// existen).
  static int bloquesACrear(Iterable<int> dias, int inicio, int fin) =>
      fin > inicio ? dias.toSet().length * (fin - inicio) : 0;

  /// Días en texto corto ordenado: {0, 2, 4} → "L, X, V".
  static String diasCortos(Iterable<int> dias) {
    final orden = dias.toSet().toList()..sort();
    return orden.where((d) => d >= 0 && d < kInicialesDia.length)
        .map((d) => kInicialesDia[d]).join(', ');
  }

  /// Ajusta el fin si deja de ser válido al cambiar el inicio (conserva la
  /// duración cuando cabe).
  static int ajustarFin(int nuevoInicio, int inicioAnterior, int finAnterior) {
    final dur = (finAnterior - inicioAnterior).clamp(1, kHoraFinMaxLab - kHoraMinLab);
    final fin = nuevoInicio + dur;
    return fin > kHoraFinMaxLab ? kHoraFinMaxLab : fin;
  }

  // ── Rangos distintos por día (diálogo "Varios días") ──────────────────────

  /// Une los rangos que se solapan o se tocan dentro de cada día y los
  /// ordena por día y hora. Recorta lo que quede fuera del horario del
  /// laboratorio y descarta rangos vacíos o con día inválido.
  /// Ej.: L 8–11 + L 10–13 + L 13–14 → L 8–14.
  static List<RangoHoras> normalizar(Iterable<RangoHoras> rangos) => fusionar([
        for (final r in rangos)
          if (r.dia >= 0 && r.dia < kNombresDia.length)
            for (int h = r.inicio < kHoraMinLab ? kHoraMinLab : r.inicio;
                h < (r.fin > kHoraFinMaxLab ? kHoraFinMaxLab : r.fin);
                h++)
              (dia: r.dia, hora: h),
      ]);

  /// Horas (bloques de 1 h) distintas que cubren los rangos; las horas que
  /// se solapan cuentan una sola vez.
  static int totalHoras(Iterable<RangoHoras> rangos) =>
      normalizar(rangos).fold(0, (n, r) => n + r.duracion);

  /// Días distintos con al menos una hora.
  static Set<int> diasCon(Iterable<RangoHoras> rangos) =>
      {for (final r in normalizar(rangos)) r.dia};

  /// "Total: 13 h en 4 días" (vacío → "Total: 0 h").
  static String resumenTotal(Iterable<RangoHoras> rangos) {
    final h = totalHoras(rangos);
    final d = diasCon(rangos).length;
    if (h == 0) return 'Total: 0 h';
    return 'Total: $h h en $d día${d == 1 ? '' : 's'}';
  }

  /// Cuerpo `bloques` de asignar-bloques: [{dia, hora_inicio, hora_fin}]
  /// ya normalizado (sin solapes).
  static List<Map<String, int>> aBloquesJson(Iterable<RangoHoras> rangos) => [
        for (final r in normalizar(rangos))
          {'dia': r.dia, 'hora_inicio': r.inicio, 'hora_fin': r.fin},
      ];

  /// Texto corto por día: "L 8 AM – 11 AM · X 8 AM – 10 AM, 11 AM – 1 PM".
  static String describirPorDia(Iterable<RangoHoras> rangos) {
    final porDia = <int, List<RangoHoras>>{};
    for (final r in normalizar(rangos)) {
      porDia.putIfAbsent(r.dia, () => []).add(r);
    }
    return porDia.entries
        .map((e) => '${kInicialesDia[e.key]} ${e.value.map((r) => r.texto).join(', ')}')
        .join(' · ');
  }

  /// Rango que se propone al pulsar "+ rango" en un día que ya tiene
  /// `delDia`: 1 h dejando una hora libre tras el último rango (caso típico
  /// "8–10 y 11–13"); si no cabe después, antes del primero; si el día está
  /// vacío, `porDefecto`.
  static RangoHoras sugerirRangoNuevo(int dia, List<RangoHoras> delDia, RangoHoras porDefecto) {
    if (delDia.isEmpty) return RangoHoras(dia, porDefecto.inicio, porDefecto.fin);
    final ultimoFin = delDia.map((r) => r.fin).reduce((a, b) => a > b ? a : b);
    final primerInicio = delDia.map((r) => r.inicio).reduce((a, b) => a < b ? a : b);
    if (ultimoFin + 2 <= kHoraFinMaxLab) return RangoHoras(dia, ultimoFin + 1, ultimoFin + 2);
    if (ultimoFin + 1 <= kHoraFinMaxLab) return RangoHoras(dia, ultimoFin, ultimoFin + 1);
    if (primerInicio - 2 >= kHoraMinLab) return RangoHoras(dia, primerInicio - 2, primerInicio - 1);
    return RangoHoras(dia, kHoraMinLab, kHoraMinLab + 1);
  }

  /// Líneas legibles de los choques que devuelve el backend en un 409.
  static List<String> describirChoques(dynamic choques) {
    if (choques is! List) return const [];
    final out = <String>[];
    for (final c in choques) {
      if (c is! Map) continue;
      final d = c['dia_semana'], h = c['hora'];
      final cuando = (d is int && h is int && d >= 0 && d < kNombresDia.length)
          ? '${kNombresDia[d]} ${horaAmPm(h)}'
          : (c['bloque']?.toString() ?? '');
      final quien = c['ocupado_por']?.toString() ?? '';
      final extra = [c['docente'], c['grupo']]
          .where((v) => v != null && v.toString().trim().isNotEmpty)
          .join(' · ');
      out.add([cuando, quien, if (extra.isNotEmpty) '($extra)']
          .where((s) => s.isNotEmpty).join(' — '));
    }
    return out;
  }
}

/// Resumen de "Mi semana" (GET academico/mi-semana/) ya normalizado.
class MiSemana {
  final int? usuario;
  final String nombre;
  final DateTime? semanaInicio;
  final List<RangoHoras> rangos;
  final List<Map<String, dynamic>> enCasa;
  final List<Map<String, dynamic>> registros;
  final SeguimientoFila horas;
  final bool completada;

  const MiSemana({
    required this.usuario,
    required this.nombre,
    required this.semanaInicio,
    required this.rangos,
    required this.enCasa,
    required this.registros,
    required this.horas,
    required this.completada,
  });

  factory MiSemana.desdeJson(Map<String, dynamic> m) => MiSemana(
        usuario: m['usuario'] is int ? m['usuario'] as int : null,
        nombre: m['nombre_completo']?.toString() ?? '',
        semanaInicio: DateTime.tryParse('${m['semana_inicio'] ?? ''}'),
        rangos: RangosHorario.desdeFilas(ApiListas.listaDe(m['bloques'])),
        enCasa: ApiListas.listaDe(m['en_casa']),
        registros: ApiListas.listaDe(m['registros']),
        horas: SeguimientoFila.desdeJson(m),
        completada: m['completada'] == true,
      );

  /// Rangos agrupados por día (solo los días con bloques), en orden.
  Map<int, List<RangoHoras>> get rangosPorDia {
    final out = <int, List<RangoHoras>>{};
    for (final r in rangos) {
      out.putIfAbsent(r.dia, () => []).add(r);
    }
    return out;
  }

  /// Filas compactas para la tarjeta del dashboard: una por día, con los
  /// rangos en formato 24 h corto ("8–9 · 15–18") y las horas del día.
  /// Se limita a [maxDias] filas y [maxRangos] rangos por fila para que la
  /// tarjeta no crezca sin control; lo que sobra se informa en
  /// [ResumenSemana.diasOcultos] y en el sufijo "+N" de cada fila.
  ResumenSemana resumen({int maxDias = 4, int maxRangos = 3}) {
    final dias = rangosPorDia.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final filas = <FilaResumenDia>[];
    for (final e in dias.take(maxDias)) {
      final rs = [...e.value]..sort((a, b) => a.inicio.compareTo(b.inicio));
      final visibles = rs.take(maxRangos).map((r) => '${r.inicio}–${r.fin}').join(' · ');
      final extra = rs.length - maxRangos;
      filas.add(FilaResumenDia(
        dia: kDiasCortos[e.key],
        rangos: extra > 0 ? '$visibles +$extra' : visibles,
        horas: rs.fold<int>(0, (t, r) => t + r.duracion),
      ));
    }
    return ResumenSemana(filas, dias.length - filas.length);
  }
}

/// Una fila de [MiSemana.resumen].
class FilaResumenDia {
  final String dia;
  final String rangos;
  final int horas;
  const FilaResumenDia({required this.dia, required this.rangos, required this.horas});
}

/// Resultado de [MiSemana.resumen]: filas visibles y días que no caben.
class ResumenSemana {
  final List<FilaResumenDia> filas;
  final int diasOcultos;
  const ResumenSemana(this.filas, this.diasOcultos);
}
