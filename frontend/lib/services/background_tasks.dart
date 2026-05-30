import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'dart:ui';

// URL del servidor compilada en el APK (--dart-define=SERVER_URL=...)
const _kServerUrl = String.fromEnvironment(
  'SERVER_URL',
  defaultValue: 'http://localhost:8000',
);

// Nombres de tarea
const kTaskStock         = 'sgi_stock_check';
const kTaskSchedule      = 'sgi_schedule_check';
const kTaskServerMonitor = 'sgi_server_monitor';

// Clave SharedPreferences para el estado del servidor
const _kServerStatusKey = 'server_monitor_status'; // 'online' | 'offline'

// ── Punto de entrada del hilo de fondo ────────────────────────────────────────
// @pragma necesario para que el compilador no elimine esta función.
@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((taskName, _) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      DartPluginRegistrant.ensureInitialized();

      const storage = FlutterSecureStorage();
      final token    = await storage.read(key: 'token');
      final rol      = await storage.read(key: 'rol') ?? '';
      final username = await storage.read(key: 'username') ?? '';

      if (token == null) return true; // Sin sesión → no hacer nada

      switch (taskName) {
        case kTaskStock:
          await _checkStock(token);
        case kTaskSchedule:
          await _checkSchedule(token, rol, username);
        case kTaskServerMonitor:
          await _checkServer();
      }
    } catch (_) {
      // Las notificaciones son no-críticas; ignoramos cualquier error
    }
    return true;
  });
}

// ── Registro de tareas periódicas ─────────────────────────────────────────────

/// Registra todas las tareas periódicas. Llamar tras iniciar sesión.
Future<void> registerBackgroundTasks() async {
  // Stock crítico: cada 6 horas
  await Workmanager().registerPeriodicTask(
    kTaskStock,
    kTaskStock,
    frequency: const Duration(hours: 6),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingWorkPolicy.keep,
    backoffPolicy: BackoffPolicy.linear,
    backoffPolicyDelay: const Duration(minutes: 30),
  );

  // Horario + turno monitor: cada 15 minutos (mínimo de Android)
  await Workmanager().registerPeriodicTask(
    kTaskSchedule,
    kTaskSchedule,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );

  // Monitor de disponibilidad del servidor: cada 15 minutos.
  // Sin restricción de red — necesita correr incluso sin conexión para
  // detectar cuando el servidor está caído.
  await Workmanager().registerPeriodicTask(
    kTaskServerMonitor,
    kTaskServerMonitor,
    frequency: const Duration(minutes: 15),
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );
}

/// Cancela todas las tareas periódicas. Llamar al cerrar sesión.
Future<void> cancelBackgroundTasks() async {
  await Workmanager().cancelByUniqueName(kTaskStock);
  await Workmanager().cancelByUniqueName(kTaskSchedule);
  await Workmanager().cancelByUniqueName(kTaskServerMonitor);
}

// ── Lógica de Stock Crítico ───────────────────────────────────────────────────

Future<void> _checkStock(String token) async {
  final prefs = await SharedPreferences.getInstance();
  final today = _dateKey();
  final prefKey = 'notif_stock_$today';

  // Solo una notificación por día de stock crítico
  if (prefs.getBool(prefKey) == true) return;

  final dio = _dio(token);
  final resp = await dio.get('academico/dashboard/');
  final stockCritico = (resp.data['stock_critico'] as int?) ?? 0;

  if (stockCritico > 0) {
    await _show(
      id: 1001,
      title: '⚠️ Stock crítico en el laboratorio',
      body: '$stockCritico insumo${stockCritico > 1 ? 's' : ''} '
          '${stockCritico > 1 ? 'están' : 'está'} por debajo del mínimo.',
    );
    await prefs.setBool(prefKey, true);
  }
}

// ── Lógica de Horario ─────────────────────────────────────────────────────────

Future<void> _checkSchedule(String token, String rol, String username) async {
  final now = DateTime.now();
  // Solo actuar en ventana de 40–54 min (15 min antes del próximo bloque)
  if (now.minute < 40 || now.minute > 54) return;

  final prefs   = await SharedPreferences.getInstance();
  final dateKey = _dateKey();
  final dayWeek = now.weekday - 1; // 0=Lun, 5=Sáb
  final hora    = now.hour;        // bloque actual

  // 1. Monitor / LAB: 15 min antes de que TERMINE su bloque
  if (rol == 'MONITOR' || rol == 'LAB') {
    final prefKey = 'notif_monitor_${dateKey}_$hora';
    if (prefs.getBool(prefKey) != true) {
      final bloques = await _getHorarioEncargado(token);
      final miBloque = bloques.where((b) {
        final bDia  = _int(b['dia_semana']);
        final bHora = _int(b['hora']);
        // El serializer HorarioEncargadoSerializer expone 'username' en el root,
        // no 'usuario_username'. b['usuario'] es el ID (int), no un objeto.
        final bUser = (b['username'] as String?) ?? '';
        return bDia == dayWeek && bHora == hora && bUser == username;
      });

      if (miBloque.isNotEmpty) {
        await _show(
          id: 1002,
          title: '⏰ Tu turno termina en ~15 minutos',
          body: '¿Ya registraste tus horas de hoy?',
        );
        await prefs.setBool(prefKey, true);
      }
    }
  }

  // 2. Recordatorio de práctica: 15 min antes de que EMPIECE el próximo bloque
  final nextHora = hora + 1;
  if (nextHora <= 21) {
    final prefKey = 'notif_horario_${dateKey}_$nextHora';
    if (prefs.getBool(prefKey) != true) {
      final bloques = await _getHorarioAsignatura(token);
      final bloque = bloques.cast<Map?>().firstWhere(
        (b) => _int(b!['dia_semana']) == dayWeek && _int(b['hora']) == nextHora,
        orElse: () => null,
      );

      if (bloque != null) {
        final nombre = bloque['nombre_asignatura'] as String?
            ?? (bloque['asignatura'] is Map
                ? bloque['asignatura']['nombre'] as String?
                : null)
            ?? 'Práctica';
        await _show(
          id: 1003,
          title: '📅 Práctica en ~15 minutos',
          body: '$nombre comienza a las '
              '${nextHora.toString().padLeft(2, '0')}:00',
        );
        await prefs.setBool(prefKey, true);
      }
    }
  }
}

// ── Monitor de disponibilidad del servidor ────────────────────────────────────

Future<void> _checkServer() async {
  final prefs = await SharedPreferences.getInstance();
  final estadoAnterior = prefs.getString(_kServerStatusKey); // 'online' | 'offline' | null

  bool ahoraOnline;
  try {
    final dio = Dio(BaseOptions(
      baseUrl: '${_kServerUrl.endsWith('/') ? _kServerUrl.substring(0, _kServerUrl.length - 1) : _kServerUrl}/api/',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
    final resp = await dio.get('academico/dashboard/');
    ahoraOnline = resp.statusCode != null && resp.statusCode! < 500;
  } catch (_) {
    ahoraOnline = false;
  }

  final estadoActual = ahoraOnline ? 'online' : 'offline';

  // Solo notificar cuando el estado cambia
  if (estadoAnterior == estadoActual) return;

  await prefs.setString(_kServerStatusKey, estadoActual);

  final ahora = DateTime.now();
  final horaStr =
      '${ahora.day.toString().padLeft(2, '0')}/${ahora.month.toString().padLeft(2, '0')}/${ahora.year} '
      '${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')}';

  if (ahoraOnline) {
    // Servidor recuperado
    await _show(
      id: 1005,
      title: '✅ Servidor en línea',
      body: 'El servidor volvió a estar disponible — $horaStr',
      channelId: 'sgi_server_channel',
      channelName: 'Estado del servidor',
    );
  } else {
    // Servidor caído
    await _show(
      id: 1004,
      title: '🔴 Servidor sin conexión',
      body: 'No se pudo contactar al servidor desde las $horaStr',
      channelId: 'sgi_server_channel',
      channelName: 'Estado del servidor',
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Future<List> _getHorarioEncargado(String token) async {
  try {
    final r = await _dio(token).get('academico/horario-encargado/');
    return r.data is List ? r.data as List : [];
  } catch (_) {
    return [];
  }
}

Future<List> _getHorarioAsignatura(String token) async {
  try {
    final r = await _dio(token).get('academico/horario-asignatura/');
    return r.data is List ? r.data as List : [];
  } catch (_) {
    return [];
  }
}

Dio _dio(String token) => Dio(BaseOptions(
  baseUrl: '${_kServerUrl.endsWith('/') ? _kServerUrl.substring(0, _kServerUrl.length - 1) : _kServerUrl}/api/',
  connectTimeout: const Duration(seconds: 15),
  receiveTimeout: const Duration(seconds: 15),
  headers: {'Authorization': 'Bearer $token'},
));

Future<void> _show({
  required int id,
  required String title,
  required String body,
  String channelId   = 'sgi_lab_channel',
  String channelName = 'SGI LAB MANAGER',
}) async {
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );
  await plugin.show(
    id,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'Alertas de inventario, horarios y estado del servidor',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );
}

String _dateKey() {
  final n = DateTime.now();
  return '${n.year}${n.month.toString().padLeft(2, '0')}${n.day.toString().padLeft(2, '0')}';
}

int _int(dynamic v) => v is int ? v : int.tryParse(v.toString()) ?? -1;
