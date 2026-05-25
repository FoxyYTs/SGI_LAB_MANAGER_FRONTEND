import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
import 'core/theme/colors.dart';
import 'core/sync/sync_service.dart';
import 'core/database/local_db.dart';

/// Punto de entrada de la aplicación SGI LAB MANAGER.
///
/// Inicializa SQLite (solo en plataformas nativas) antes de levantar los
/// providers y la MaterialApp. Las rutas públicas (/solicitud, /registro-horas,
/// etc.) son accesibles sin autenticación desde los formularios QR.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) await LocalDb.instance;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => InventarioProvider()),
        ChangeNotifierProvider.value(value: SyncService.instance),
      ],
      child: const MyApp(),
    ),
  );
}

/// Widget raíz de la aplicación. Configura el tema global y el router de rutas.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SGI LAB Manager',
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
      home: const LoginScreen(),
      routes: {
        '/dashboard': (context) => const MainShell(),
        '/solicitud':          (context) => const SolicitudPrestamoScreen(),
        '/registro-horas':    (context) => const RegistroHorasScreen(),
        '/registro-practica': (context) => const RegistroPracticaScreen(),
        '/reporte-rotura':    (context) => const ReporteRoturaScreen(),
        '/registro': (context) => const RegistroScreen(),
        '/recuperar-pass': (context) => const RecuperarPassScreen(),
        '/restablecer-pass': (context) => const RestablecerPassScreen(),
        '/permisos': (context) => const PermisosScreen(),
        '/insumo-form': (context) => const InsumoFormScreen(),
        '/mi-perfil': (context) => const MiPerfilScreen(),
      },
    );
  }
}
