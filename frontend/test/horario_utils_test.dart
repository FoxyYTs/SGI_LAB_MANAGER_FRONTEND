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
}
