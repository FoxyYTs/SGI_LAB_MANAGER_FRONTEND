import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'dart:ui';
import '../core/api/token_utils.dart';

// URL del servidor compilada en el APK (--dart-define=SERVER_URL=...)
const _kServerUrl = String.fromEnvironment(
  'SERVER_URL',
  defaultValue: 'http://localhost:8000',
);

// Nombres de tarea
const kTaskStock    = 'sgi_stock_check';
const kTaskSchedule = 'sgi_schedule_check';

// ── Punto de entrada del hilo de fondo ────────────────────────────────────────
// @pragma necesario para que el compilador no elimine esta función.
@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((taskName, _) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      DartPluginRegistrant.ensureInitialized();

      const storage = FlutterSecureStorage();
      // El access dura 2 h: sin refrescar, la tarea solo funcionaba si la app
      // se había abierto hacía poco (después, 401 silencioso).
      final token = await _tokenVigente(storage);
      final username = await storage.read(key: 'username') ?? '';
      // hace_turnos_monitor (no rol=='MONITOR'/'LAB'): un ADMIN/LAB que
      // también cubre turnos debe recibir el mismo recordatorio.
      final haceTurnosMonitor =
          (await storage.read(key: 'hace_turnos_monitor')) == 'true';

      if (token == null) return true; // Sin sesión (o no renovable) → no hacer nada

      switch (taskName) {
        case kTaskStock:
          await _checkStock(token);
        case kTaskSchedule:
          await _checkSchedule(token, haceTurnosMonitor, username);
      }
    } catch (e) {
      // Las notificaciones son no-críticas: no reintentar, pero dejar rastro.
      debugPrint('[Workmanager] Tarea $taskName falló: $e');
    }
    return true;
  });
}

// ── Token en el isolate de fondo ──────────────────────────────────────────────

/// Devuelve un access token utilizable para la tarea, refrescándolo si ya
/// caducó (o caduca en < 2 min). `null` si no hay sesión o no se pudo renovar.
///
/// Convivencia con el isolate principal (ROTATE_REFRESH_TOKENS +
/// BLACKLIST_AFTER_ROTATION): ambos pueden rotar el refresh token guardado.
/// - Solo se refresca si el access está caducado, no en cada ejecución.
/// - Lo rotado se persiste (primero el refresh) y solo si el storage aún tiene
///   el refresh que se usó: si entretanto hubo logout o la app lo rotó, no se
///   pisa nada.
/// - Si el servidor rechaza el refresh se relee el storage: si la app lo rotó a
///   la vez, se usan sus tokens. Nunca se borra la sesión desde aquí: si de
///   verdad expiró, la app lo detecta al abrirse.
/// El isolate principal hace lo simétrico (ApiClient adopta tokens rotados
/// por este isolate antes de dar la sesión por perdida).
Future<String?> _tokenVigente(FlutterSecureStorage storage) async {
  final access = await storage.read(key: 'token');
  if (access == null) return null;
  if (!jwtExpiraPronto(access)) return access;

  final refresh = await storage.read(key: 'refresh_token');
  if (refresh == null) return null;

  try {
    final resp = await _dioBase().post('token/refresh/', data: {'refresh': refresh});
    final nuevoAccess  = resp.data['access']  as String;
    final nuevoRefresh = resp.data['refresh'] as String?;
    if (await storage.read(key: 'refresh_token') != refresh) {
      // Logout o rotación desde la app mientras tanto: no pisar su estado.
      debugPrint('[Workmanager] La sesión cambió durante el refresco; se descarta.');
      return null;
    }
    if (nuevoRefresh != null) {
      await storage.write(key: 'refresh_token', value: nuevoRefresh);
    }
    await storage.write(key: 'token', value: nuevoAccess);
    return nuevoAccess;
  } on DioException catch (e) {
    final status = e.response?.statusCode;
    if (esRechazoDeRefresh(status, e.response?.data)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      final guardado = await storage.read(key: 'refresh_token');
      if (guardado != null && guardado != refresh) {
        final accessGuardado = await storage.read(key: 'token');
        if (accessGuardado != null && !jwtExpiraPronto(accessGuardado)) {
          return accessGuardado;
        }
      }
      debugPrint('[Workmanager] Refresh rechazado (HTTP $status); se omite la tarea.');
    } else {
      debugPrint('[Workmanager] Refresh falló (${e.type.name} ${status ?? ''}); se omite la tarea.');
    }
    return null;
  }
}

Dio _dioBase() => Dio(BaseOptions(
  baseUrl: '${_kServerUrl.endsWith('/') ? _kServerUrl.substring(0, _kServerUrl.length - 1) : _kServerUrl}/api/',
  connectTimeout: const Duration(seconds: 15),
  receiveTimeout: const Duration(seconds: 15),
));

// ── Registro de tareas periódicas ─────────────────────────────────────────────

/// Registra todas las tareas periódicas. Llamar tras iniciar sesión.
Future<void> registerBackgroundTasks() async {
  // Stock crítico: cada 6 horas
  await Workmanager().registerPeriodicTask(
    kTaskStock,
    kTaskStock,
    frequency: const Duration(hours: 6),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    backoffPolicy: BackoffPolicy.linear,
    backoffPolicyDelay: const Duration(minutes: 30),
  );

  // Horario + turno monitor: cada 15 minutos (mínimo de Android)
  await Workmanager().registerPeriodicTask(
    kTaskSchedule,
    kTaskSchedule,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );

}

/// Cancela todas las tareas periódicas. Llamar al cerrar sesión.
Future<void> cancelBackgroundTasks() async {
  await Workmanager().cancelByUniqueName(kTaskStock);
  await Workmanager().cancelByUniqueName(kTaskSchedule);
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

Future<void> _checkSchedule(String token, bool haceTurnosMonitor, String username) async {
  final now = DateTime.now();
  // Solo actuar en ventana de 40–54 min (15 min antes del próximo bloque)
  if (now.minute < 40 || now.minute > 54) return;

  final prefs   = await SharedPreferences.getInstance();
  final dateKey = _dateKey();
  final dayWeek = now.weekday - 1; // 0=Lun, 5=Sáb
  final hora    = now.hour;        // bloque actual

  // 1. Quien cumple turnos: 15 min antes de que TERMINE su bloque
  if (haceTurnosMonitor) {
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
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );
  await plugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(
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
