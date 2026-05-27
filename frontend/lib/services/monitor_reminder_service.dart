import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/theme/colors.dart';
import '../providers/auth_provider.dart';

/// Servicio de recordatorios para monitores.
///
/// Carga los bloques de horario del monitor autenticado y, al finalizar
/// cada bloque continuo, muestra un dialog dentro de la app.
/// El email lo gestiona el backend vía APScheduler.
class MonitorReminderService {
  MonitorReminderService._();

  static Timer? _timer;
  // dia (0=Lun) → lista ordenada de horas asignadas
  static final Map<int, List<int>> _horarioPorDia = {};
  static int? _ultimaHoraNotificada; // evita notificar varias veces en la misma hora
  static BuildContext? _ctx;

  // ── API pública ────────────────────────────────────────────────────────────

  static Future<void> iniciar(BuildContext context, AuthProvider auth) async {
    _ctx = context;
    await _cargarHorario(auth);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _verificar());
    _verificar(); // Revisión inmediata por si el monitor inicia sesión justo a la hora
  }

  static void detener() {
    _timer?.cancel();
    _timer = null;
    _horarioPorDia.clear();
    _ultimaHoraNotificada = null;
    _ctx = null;
  }

  // ── Lógica interna ─────────────────────────────────────────────────────────

  static Future<void> _cargarHorario(AuthProvider auth) async {
    try {
      final dio = ApiClient.instance.authenticatedDio(auth.token);
      final r   = await dio.get('academico/mis-horarios-encargado/');
      _horarioPorDia.clear();
      for (final bloque in r.data as List) {
        final dia  = bloque['dia_semana'] as int;
        final hora = bloque['hora'] as int;
        _horarioPorDia.putIfAbsent(dia, () => []).add(hora);
      }
      for (final horas in _horarioPorDia.values) {
        horas.sort();
      }
    } catch (_) {
      // Si falla la carga del horario simplemente no notifica
    }
  }

  static void _verificar() {
    final ctx = _ctx;
    if (ctx == null || !ctx.mounted) return;

    final ahora     = DateTime.now();
    final diaActual = ahora.weekday - 1; // 0=Lun … 5=Sáb
    final hora      = ahora.hour;
    final minuto    = ahora.minute;

    // Solo al inicio de cada hora (minuto 0)
    if (minuto != 0) return;
    // No notificar dos veces en la misma hora
    if (_ultimaHoraNotificada == hora) return;

    final horas = _horarioPorDia[diaActual] ?? [];
    if (_esFinDeBloque(horas, hora)) {
      _ultimaHoraNotificada = hora;
      _mostrarDialog(ctx);
    }
  }

  /// Devuelve true si `horaActual` marca el final de un bloque continuo.
  /// Ejemplo: horas=[8,9,10,14,15], horaActual=11 → true (fin del primer bloque).
  static bool _esFinDeBloque(List<int> horas, int horaActual) {
    return horas.contains(horaActual - 1) && !horas.contains(horaActual);
  }

  static void _mostrarDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.access_time_rounded, color: kPrimary, size: 22),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Recordatorio de horas',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ]),
        content: const Text(
          'Tu turno en el laboratorio ha finalizado.\n'
          '¿Deseas registrar tus horas de monitor ahora?',
          style: TextStyle(fontSize: 13),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Más tarde', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(ctx).pushNamed('/registro-horas');
            },
            icon: const Icon(Icons.edit_note_outlined, size: 16),
            label: const Text('Registrar ahora'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}
