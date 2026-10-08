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
}
