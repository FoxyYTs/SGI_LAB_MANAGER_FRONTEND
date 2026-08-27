import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';
import 'providers/auth_provider.dart';
import 'providers/inventario_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/solicitud_prestamo_screen.dart';
import 'screens/registro_horas_screen.dart';
import 'screens/registro_practica_screen.dart';
import 'screens/reporte_rotura_screen.dart';
import 'screens/registro_screen.dart';
import 'screens/recuperar_pass_screen.dart';
import 'screens/restablecer_pass_screen.dart';
import 'screens/permisos_screen.dart';
import 'screens/insumo_form_screen.dart';
import 'screens/mi_perfil_screen.dart';
import 'screens/actualizacion_requerida_screen.dart';
import 'screens/politica_privacidad_screen.dart';
import 'core/theme/colors.dart';
import 'core/sync/sync_service.dart';
import 'core/database/local_db.dart';
import 'core/navigation_service.dart';
import 'core/log_service.dart';
import 'services/notification_service.dart';
import 'services/background_tasks.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar log en archivo si FILE_LOG=true.
  await LogService.init();
  LogService.log('main() iniciado');

  // Captura errores de widgets/frames de Flutter.
  FlutterError.onError = (details) {
    LogService.logError('FlutterError', details.exception, details.stack);
  };

  // Captura errores asíncronos no manejados (fuera del árbol de widgets).
  PlatformDispatcher.instance.onError = (error, stack) {
    LogService.logError('PlatformDispatcher', error, stack);
    return true; // true = el error fue manejado, no aborta la app
  };

  if (!kIsWeb) {
    try {
      LogService.log('Inicializando base de datos local...');
      await LocalDb.instance;
      LogService.log('Base de datos local OK');
    } catch (e, s) {
      LogService.logError('LocalDb.instance', e, s);
    }

    // Workmanager solo disponible en Android
    if (Platform.isAndroid) {
      await Workmanager().initialize(backgroundDispatcher);
      LogService.log('Workmanager inicializado');
    }
  }

  // Restaurar sesión guardada ANTES de levantar la UI.
  LogService.log('Cargando sesión guardada...');
  final auth = AuthProvider();
  await auth.cargarSesion();
  LogService.log('Sesión cargada — autenticado: ${auth.isAuthenticated}, rol: ${auth.rol}');

  // Inicializar conectividad aunque no haya sesión (para detectar online/offline en login).
  if (!kIsWeb && !auth.isAuthenticated) {
    await SyncService.instance.init(null);
  }

  // Notificaciones y tareas de fondo solo en Android
  if (!kIsWeb && auth.isAuthenticated && Platform.isAndroid) {
    await NotificationService.init();
    await NotificationService.requestPermission();
    await registerBackgroundTasks();
  }

  LogService.log('Iniciando UI...');
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(create: (_) => InventarioProvider()),
        ChangeNotifierProvider.value(value: SyncService.instance),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'SGI LAB MANAGER',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kPrimary),
        primaryColor: kPrimary,
        scaffoldBackgroundColor: kBackground,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 2,
          shadowColor: Colors.black26,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: kPrimary,
          unselectedLabelColor: kTextMuted,
          indicatorColor: kPrimary,
        ),
      ),
      // home: si el usuario ya está autenticado muestra el shell; si no, el login.
      home: const _AuthGate(),
      routes: {
        // ── Rutas protegidas (requieren sesión) ───────────────────────────────
        '/dashboard':   (ctx) => const _Guard(child: MainShell()),
        '/permisos':    (ctx) => const _Guard(child: PermisosScreen()),
        '/insumo-form': (ctx) => const _Guard(child: InsumoFormScreen()),
        '/mi-perfil':   (ctx) => const _Guard(child: MiPerfilScreen()),
        '/actualizacion-requerida': (ctx) => const ActualizacionRequeridaScreen(),
        '/politica-privacidad':    (ctx) => const PoliticaPrivacidadScreen(),
        // ── Rutas públicas (accesibles sin login) ─────────────────────────────
        '/solicitud':          (ctx) => const SolicitudPrestamoScreen(),
        '/registro-horas':     (ctx) => const RegistroHorasScreen(),
        '/registro-practica':  (ctx) => const RegistroPracticaScreen(),
        '/reporte-rotura':     (ctx) => const ReporteRoturaScreen(),
        '/registro':           (ctx) => const RegistroScreen(),
        '/recuperar-pass':     (ctx) => const RecuperarPassScreen(),
        '/restablecer-pass':   (ctx) => const RestablecerPassScreen(),
      },
    );
  }
}

/// Decide qué mostrar en la ruta raíz según el estado de autenticación.
/// Al ser reactivo (context.watch), cambia automáticamente cuando el usuario
/// inicia o cierra sesión.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isAuthenticated) return const MainShell();
    return const LoginScreen();
  }
}

/// Guard para rutas protegidas. Si el usuario no está autenticado lo redirige
/// al inicio (donde _AuthGate muestra el login).
class _Guard extends StatelessWidget {
  final Widget child;
  const _Guard({required this.child});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.pushReplacementNamed(context, '/');
      });
      // Spinner breve mientras se redirige
      return const Scaffold(
        backgroundColor: kBackground,
        body: Center(child: CircularProgressIndicator(color: kPrimary)),
      );
    }
    return child;
  }
}
