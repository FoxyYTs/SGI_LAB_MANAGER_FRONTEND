import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Gestiona la inicialización y disparo de notificaciones locales.
/// Funciona tanto en el hilo principal como en tareas de fondo (Workmanager).
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // IDs fijos por tipo de notificación
  static const int idStockCritico   = 1001;
  static const int idMonitorTurno   = 1002;
  static const int idHorarioProximo = 1003;

  static Future<void> init() async {
    if (_initialized || kIsWeb) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  /// Muestra una notificación. Inicializa el plugin si todavía no se hizo.
  static Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    await init();

    const androidDetails = AndroidNotificationDetails(
      'sgi_lab_channel',
      'SGI LAB MANAGER',
      channelDescription: 'Alertas de inventario y horarios del laboratorio',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: androidDetails),
    );
  }

  /// Solicita permiso de notificaciones en Android 13+ (API 33).
  static Future<void> requestPermission() async {
    if (kIsWeb) return;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }
}
