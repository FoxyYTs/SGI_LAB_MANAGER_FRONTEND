import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/horario_utils.dart';

void main() {
  // Horas reducidas para tests más legibles: índice 0=7h, 1=8h, 2=9h, 3=10h
  const h = [7, 8, 9, 10];

  Map<String, dynamic> _asg(String asig, String doc, String grupo) =>
      {'asignatura': asig, 'docente': doc, 'grupo': grupo};

  Map<String, dynamic> _enc(int uid, String username) =>
      {'usuario': uid, 'username': username, 'nombre_completo': username};

  // ── bloquesAsg ────────────────────────────────────────────────────────────

  group('HorarioUtils.bloquesAsg()', () {
    test('null porHora devuelve lista vacía', () {
      expect(HorarioUtils.bloquesAsg(null, h), isEmpty);
    });

    test('hora vacía se omite y no genera bloque', () {
      final porHora = {7: <Map<String, dynamic>>[]};
      expect(HorarioUtils.bloquesAsg(porHora, h), isEmpty);
    });

    test('bloque simple sin fusión (una sola hora)', () {
      final item = _asg('Física', 'Dr. López', 'A');
      final porHora = {7: [item]};
      final bloques = HorarioUtils.bloquesAsg(porHora, h);
      expect(bloques.length, 1);
      expect(bloques.first.idx, 0);
      expect(bloques.first.dur, 1);
      expect(bloques.first.items.first, item);
    });

    test('fusiona dos horas consecutivas con la misma clase', () {
      final item = _asg('Cálculo', 'Dra. Mora', 'B');
      final porHora = {7: [item], 8: [item]};
      final bloques = HorarioUtils.bloquesAsg(porHora, h);
      expect(bloques.length, 1);
      expect(bloques.first.dur, 2);
    });

    test('no fusiona horas con clases distintas', () {
      final a = _asg('Cálculo', 'Dra. Mora', 'B');
      final b = _asg('Física', 'Dr. López', 'A');
      final porHora = {7: [a], 8: [b]};
      final bloques = HorarioUtils.bloquesAsg(porHora, h);
      expect(bloques.length, 2);
      expect(bloques[0].dur, 1);
      expect(bloques[1].dur, 1);
    });

    test('hora intermedia vacía rompe la fusión', () {
      final item = _asg('Cálculo', 'Dra. Mora', 'B');
      final porHora = {7: [item], 9: [item]};
      final bloques = HorarioUtils.bloquesAsg(porHora, h);
      expect(bloques.length, 2);
      expect(bloques[0].idx, 0);
      expect(bloques[1].idx, 2);
    });

    test('fusiona tres horas consecutivas con la misma clase', () {
      final item = _asg('Redes', 'Ing. Pérez', 'C');
      final porHora = {7: [item], 8: [item], 9: [item]};
      final bloques = HorarioUtils.bloquesAsg(porHora, h);
      expect(bloques.length, 1);
      expect(bloques.first.dur, 3);
    });
  });

  // ── bloquesEnc ────────────────────────────────────────────────────────────

  group('HorarioUtils.bloquesEnc()', () {
    test('porHora vacío devuelve lista vacía', () {
      expect(HorarioUtils.bloquesEnc({}, h), isEmpty);
    });

    test('un encargado en una hora genera un bloque de duración 1', () {
      final enc = _enc(1, 'user1');
      final porHora = {7: [enc]};
      final bloques = HorarioUtils.bloquesEnc(porHora, h);
      expect(bloques.length, 1);
      expect(bloques.first.idx, 0);
      expect(bloques.first.dur, 1);
    });

    test('fusiona horas consecutivas del mismo encargado', () {
      final enc = _enc(1, 'user1');
      final porHora = {7: [enc], 8: [enc]};
      final bloques = HorarioUtils.bloquesEnc(porHora, h);
      expect(bloques.length, 1);
      expect(bloques.first.dur, 2);
    });

    test('dos encargados distintos generan bloques separados', () {
      final enc1 = _enc(1, 'user1');
      final enc2 = _enc(2, 'user2');
      final porHora = {7: [enc1, enc2]};
      final bloques = HorarioUtils.bloquesEnc(porHora, h);
      expect(bloques.length, 2);
    });
  });

  // ── rankEnBloque ──────────────────────────────────────────────────────────

  group('HorarioUtils.rankEnBloque()', () {
    test('encargado sin solapantes tiene rank 0', () {
      final b = (idx: 0, dur: 1, enc: _enc(1, 'user1'));
      expect(HorarioUtils.rankEnBloque(b, [b]), 0);
    });

    test('encargado con uid menor tiene rank 0 cuando hay solapante con uid mayor', () {
      final b1 = (idx: 0, dur: 2, enc: _enc(1, 'user1'));
      final b2 = (idx: 0, dur: 2, enc: _enc(2, 'user2'));
      expect(HorarioUtils.rankEnBloque(b1, [b1, b2]), 0);
      expect(HorarioUtils.rankEnBloque(b2, [b1, b2]), 1);
    });

    test('encargados sin solapamiento temporal tienen rank 0 ambos', () {
      // b1: índices 0-1, b2: índices 2-3 → no se solapan
      final b1 = (idx: 0, dur: 2, enc: _enc(1, 'user1'));
      final b2 = (idx: 2, dur: 2, enc: _enc(2, 'user2'));
      expect(HorarioUtils.rankEnBloque(b1, [b1, b2]), 0);
      expect(HorarioUtils.rankEnBloque(b2, [b1, b2]), 0);
    });

    test('tres encargados solapados tienen ranks 0, 1, 2', () {
      final b1 = (idx: 0, dur: 3, enc: _enc(1, 'user1'));
      final b2 = (idx: 0, dur: 3, enc: _enc(2, 'user2'));
      final b3 = (idx: 0, dur: 3, enc: _enc(3, 'user3'));
      final todos = [b1, b2, b3];
      expect(HorarioUtils.rankEnBloque(b1, todos), 0);
      expect(HorarioUtils.rankEnBloque(b2, todos), 1);
      expect(HorarioUtils.rankEnBloque(b3, todos), 2);
    });
  });

  // ── ApiListas ─────────────────────────────────────────────────────────────

  group('ApiListas.listaDe()', () {
    test('acepta lista directa', () {
      expect(ApiListas.listaDe([{'id': 1}, {'id': 2}]).length, 2);
    });
    test('acepta respuesta paginada', () {
      expect(ApiListas.listaDe({'count': 1, 'next': null, 'results': [{'id': 1}]}),
          [{'id': 1}]);
    });
    test('formato inesperado devuelve vacío', () {
      expect(ApiListas.listaDe(null), isEmpty);
      expect(ApiListas.listaDe({'detail': 'x'}), isEmpty);
    });
  });

  group('ApiListas.todasLasPaginas()', () {
    test('sigue next hasta la última página', () async {
      final pedidas = <int>[];
      final todo = await ApiListas.todasLasPaginas((p) async {
        pedidas.add(p);
        return {
          'count': 5,
          'next': p < 3 ? 'http://x/?page=${p + 1}' : null,
          'results': [for (int i = 0; i < (p < 3 ? 2 : 1); i++) {'p': p, 'i': i}],
        };
      });
      expect(pedidas, [1, 2, 3]);
      expect(todo.length, 5);
    });
    test('endpoint sin paginar: una sola petición', () async {
      int llamadas = 0;
      final todo = await ApiListas.todasLasPaginas((p) async {
        llamadas++;
        return [{'id': 1}, {'id': 2}, {'id': 3}];
      });
      expect(llamadas, 1);
      expect(todo.length, 3);
    });
    test('respeta maxPaginas', () async {
      int llamadas = 0;
      await ApiListas.todasLasPaginas((p) async {
        llamadas++;
        return {'next': 'siempre', 'results': [{'p': p}]};
      }, maxPaginas: 4);
      expect(llamadas, 4);
    });
  });

  // ── SeguimientoFila ───────────────────────────────────────────────────────

  group('SeguimientoFila', () {
    test('usa la meta fija y el desglose del backend', () {
      final f = SeguimientoFila.desdeJson({
        'meta_semanal': 10, 'horas_esperadas': 10,
        'horas_presenciales': 6, 'horas_no_presenciales': 2,
        'horas_registradas': 7.5,
      });
      expect(f.meta, 10);
      expect(f.asignadas, 8);
      expect(f.sinAsignar, 2);
      expect(f.pendientes, 2.5);
      expect(f.cumple, isFalse);
      expect(f.progreso, closeTo(0.75, 1e-9));
    });
    test('no da negativos si se pasa de la meta', () {
      final f = SeguimientoFila.desdeJson({
        'meta_semanal': 10, 'horas_presenciales': 12,
        'horas_no_presenciales': 0, 'horas_registradas': 14,
      });
      expect(f.sinAsignar, 0);
      expect(f.pendientes, 0);
      expect(f.cumple, isTrue);
      expect(f.progreso, 1);
    });
    test('backend anterior: esperadas = presenciales', () {
      final f = SeguimientoFila.desdeJson({'horas_esperadas': 6, 'horas_registradas': 3});
      expect(f.meta, 6);
      expect(f.presenciales, 6);
      expect(f.noPresenciales, 0);
    });
    test('acepta números como texto (DecimalField)', () {
      final f = SeguimientoFila.desdeJson({'meta_semanal': '10.0', 'horas_registradas': '2.5'});
      expect(f.meta, 10);
      expect(f.registradas, 2.5);
    });
  });

  group('formatoHoras / parseHoras', () {
    test('formato', () {
      expect(formatoHoras(10), '10 h');
      expect(formatoHoras(2.5), '2.5 h');
    });
    test('acepta coma decimal', () {
      expect(parseHoras('2,5'), 2.5);
      expect(parseHoras(' 3 '), 3);
      expect(parseHoras('dos'), isNull);
    });
  });

  // ── Rangos de horas ───────────────────────────────────────────────────────

  group('RangosHorario.fusionar()', () {
    test('fusiona horas consecutivas por día y ordena', () {
      final r = RangosHorario.fusionar([
        (dia: 2, hora: 14),
        (dia: 0, hora: 9),
        (dia: 0, hora: 8),
        (dia: 0, hora: 10),
        (dia: 0, hora: 13),
        (dia: 2, hora: 15),
      ]);
      expect(r, [
        const RangoHoras(0, 8, 11),
        const RangoHoras(0, 13, 14),
        const RangoHoras(2, 14, 16),
      ]);
      expect(r.first.duracion, 3);
      expect(r.first.texto, '8 AM – 11 AM');
      expect(r.last.textoConDia, 'Miércoles 2 PM – 4 PM');
    });

    test('ignora duplicados y lista vacía', () {
      expect(RangosHorario.fusionar(const []), isEmpty);
      expect(RangosHorario.fusionar([(dia: 1, hora: 8), (dia: 1, hora: 8)]),
          [const RangoHoras(1, 8, 9)]);
    });

    test('desdeFilas lee filas del API y descarta las inválidas', () {
      final r = RangosHorario.desdeFilas([
        {'dia_semana': 5, 'hora': 21},
        {'dia_semana': 5, 'hora': 20},
        {'dia_semana': null, 'hora': 9},
      ]);
      expect(r, [const RangoHoras(5, 20, 22)]);
      expect(r.first.texto, '8 PM – 10 PM');
    });
  });

  group('RangosHorario.rangoQueContiene()', () {
    test('encuentra el bloque consecutivo alrededor de la hora', () {
      final horas = {8, 9, 10, 14};
      expect(RangosHorario.rangoQueContiene(horas, 0, 9), const RangoHoras(0, 8, 11));
      expect(RangosHorario.rangoQueContiene(horas, 0, 14), const RangoHoras(0, 14, 15));
      expect(RangosHorario.rangoQueContiene(horas, 0, 12), isNull);
    });
  });

  group('RangosHorario.validar() y opciones', () {
    test('valida inicio/fin con fin exclusivo', () {
      expect(RangosHorario.validar(8, 11), isNull);
      expect(RangosHorario.validar(6, 22), isNull);
      expect(RangosHorario.validar(null, 9), isNotNull);
      expect(RangosHorario.validar(9, 9), contains('posterior'));
      expect(RangosHorario.validar(10, 9), contains('posterior'));
      expect(RangosHorario.validar(5, 9), isNotNull);
      expect(RangosHorario.validar(21, 23), isNotNull);
      expect(RangosHorario.validar(22, 23), isNotNull);
    });

    test('opciones de inicio y fin', () {
      expect(RangosHorario.iniciosPosibles.first, 6);
      expect(RangosHorario.iniciosPosibles.last, 21);
      expect(RangosHorario.finesPosibles(20), [21, 22]);
      expect(RangosHorario.finesPosibles(21), [22]);
    });

    test('ajustarFin conserva la duración si cabe', () {
      expect(RangosHorario.ajustarFin(10, 8, 11), 13);
      expect(RangosHorario.ajustarFin(20, 8, 11), 22);
      expect(RangosHorario.ajustarFin(9, 8, 8), 10);
    });

    test('bloquesACrear y diasCortos', () {
      expect(RangosHorario.bloquesACrear([0, 2, 4], 8, 11), 9);
      expect(RangosHorario.bloquesACrear([0, 0], 8, 10), 2);
      expect(RangosHorario.bloquesACrear([0], 10, 8), 0);
      expect(RangosHorario.diasCortos([4, 0, 2]), 'L, X, V');
      expect(RangosHorario.diasCortos([5, 3]), 'J, S');
    });
  });

  group('RangosHorario: rangos distintos por día', () {
    // Caso real (u3): mié 8,9 y 11,12 · jue 16–19 · vie 18,19 · sáb 8–11.
    const u3 = [
      RangoHoras(2, 8, 10),
      RangoHoras(2, 11, 13),
      RangoHoras(3, 16, 20),
      RangoHoras(4, 18, 20),
      RangoHoras(5, 8, 12),
    ];

    test('normalizar fusiona solapes y contiguos, ordena y recorta', () {
      expect(RangosHorario.normalizar(const [
        RangoHoras(3, 14, 15),
        RangoHoras(0, 10, 13),
        RangoHoras(0, 8, 11),
        RangoHoras(0, 13, 14),
        RangoHoras(0, 8, 11),
      ]), const [RangoHoras(0, 8, 14), RangoHoras(3, 14, 15)]);
      expect(RangosHorario.normalizar(u3), u3);
      expect(RangosHorario.normalizar(const [
        RangoHoras(1, 4, 8), RangoHoras(1, 21, 24), RangoHoras(1, 9, 9), RangoHoras(6, 8, 9),
      ]), const [RangoHoras(1, 6, 8), RangoHoras(1, 21, 22)]);
      expect(RangosHorario.normalizar(const []), isEmpty);
    });

    test('totales y resumen cuentan una vez las horas solapadas', () {
      expect(RangosHorario.totalHoras(u3), 14);
      expect(RangosHorario.diasCon(u3), {2, 3, 4, 5});
      expect(RangosHorario.resumenTotal(u3), 'Total: 14 h en 4 días');
      expect(RangosHorario.resumenTotal(const [RangoHoras(0, 8, 11), RangoHoras(0, 9, 12)]),
          'Total: 4 h en 1 día');
      expect(RangosHorario.resumenTotal(const []), 'Total: 0 h');
    });

    test('aBloquesJson arma el cuerpo normalizado para el backend', () {
      expect(RangosHorario.aBloquesJson(const [
        RangoHoras(2, 11, 13), RangoHoras(2, 8, 10), RangoHoras(2, 9, 11),
      ]), [
        {'dia': 2, 'hora_inicio': 8, 'hora_fin': 13},
      ]);
      expect(RangosHorario.aBloquesJson(u3).length, 5);
    });

    test('describirPorDia agrupa los rangos de cada día', () {
      expect(RangosHorario.describirPorDia(u3.take(3)),
          'X 8 AM – 10 AM, 11 AM – 1 PM · J 4 PM – 8 PM');
    });

    test('sugerirRangoNuevo deja una hora libre y respeta los límites', () {
      const def = RangoHoras(0, 9, 12);
      expect(RangosHorario.sugerirRangoNuevo(2, const [], def), const RangoHoras(2, 9, 12));
      expect(RangosHorario.sugerirRangoNuevo(2, const [RangoHoras(2, 8, 10)], def),
          const RangoHoras(2, 11, 12));
      expect(RangosHorario.sugerirRangoNuevo(2, const [RangoHoras(2, 18, 21)], def),
          const RangoHoras(2, 21, 22));
      expect(RangosHorario.sugerirRangoNuevo(2, const [RangoHoras(2, 14, 22)], def),
          const RangoHoras(2, 12, 13));
      expect(RangosHorario.sugerirRangoNuevo(2, const [RangoHoras(2, 6, 22)], def),
          const RangoHoras(2, 6, 7));
    });
  });

  group('RangosHorario.describirChoques()', () {
    test('formatea los choques del 409', () {
      final l = RangosHorario.describirChoques([
        {'dia_semana': 3, 'hora': 15, 'ocupado_por': 'Química', 'docente': 'Dra. Y', 'grupo': 'G2'},
        {'dia_semana': 0, 'hora': 8, 'ocupado_por': 'Física', 'docente': '', 'grupo': ''},
      ]);
      expect(l, ['Jueves 3 PM — Química — (Dra. Y · G2)', 'Lunes 8 AM — Física']);
      expect(RangosHorario.describirChoques(null), isEmpty);
    });
  });

  group('horaAmPm()', () {
    test('formato 12 h', () {
      expect(horaAmPm(6), '6 AM');
      expect(horaAmPm(12), '12 PM');
      expect(horaAmPm(21), '9 PM');
      expect(horaAmPm(22), '10 PM');
    });
  });

  group('MiSemana.desdeJson()', () {
    test('agrupa bloques por día y lee horas', () {
      final s = MiSemana.desdeJson({
        'usuario': 7,
        'nombre_completo': 'Ana Ruiz',
        'semana_inicio': '2026-10-05',
        'meta_semanal': 10.0,
        'bloques': [
          {'dia_semana': 0, 'hora': 8},
          {'dia_semana': 0, 'hora': 9},
          {'dia_semana': 2, 'hora': 14},
        ],
        'en_casa': [
          {'id': 1, 'descripcion': 'Informe', 'duracion_horas': 2.5},
        ],
        'registros': [],
        'horas_presenciales': 3.0,
        'horas_no_presenciales': 2.5,
        'horas_registradas': 4.5,
        'completada': false,
      });
      expect(s.usuario, 7);
      expect(s.semanaInicio, DateTime(2026, 10, 5));
      expect(s.rangosPorDia.keys, [0, 2]);
      expect(s.rangosPorDia[0], [const RangoHoras(0, 8, 10)]);
      expect(s.enCasa.single['descripcion'], 'Informe');
      expect(s.horas.asignadas, 5.5);
      expect(s.horas.pendientes, 5.5);
      expect(s.horas.progreso, closeTo(0.45, 1e-9));
      expect(s.completada, isFalse);
    });
  });

  group('MiSemana.resumen', () {
    MiSemana semana(List<List<int>> bloques) => MiSemana.desdeJson({
          'bloques': [
            for (final b in bloques)
              for (int h = b[1]; h < b[2]; h++) {'dia_semana': b[0], 'hora': h}
          ],
        });

    test('una fila por día con rangos cortos y total de horas', () {
      final r = semana([[0, 8, 9], [0, 12, 13], [0, 15, 16], [1, 15, 18]]).resumen();
      expect(r.filas.map((f) => f.dia), ['Lun', 'Mar']);
      expect(r.filas[0].rangos, '8–9 · 12–13 · 15–16');
      expect(r.filas[0].horas, 3);
      expect(r.filas[1].rangos, '15–18');
      expect(r.diasOcultos, 0);
    });

    test('limita días y rangos por fila', () {
      final r = semana([
        [0, 8, 9], [0, 10, 11], [0, 12, 13], [0, 14, 15], [0, 16, 17],
        [1, 8, 9], [2, 8, 9], [3, 8, 9], [4, 8, 9], [5, 8, 9],
      ]).resumen(maxDias: 4, maxRangos: 3);
      expect(r.filas.length, 4);
      expect(r.filas[0].rangos, '8–9 · 10–11 · 12–13 +2');
      expect(r.filas[0].horas, 5);
      expect(r.diasOcultos, 2);
    });
  });
}
