import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/inventario_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/solicitud_prestamo_screen.dart';
import 'screens/registro_screen.dart';
import 'screens/recuperar_pass_screen.dart';
import 'screens/restablecer_pass_screen.dart';
import 'core/theme/colors.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => InventarioProvider()),
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
        '/solicitud': (context) => const SolicitudPrestamoScreen(),
        '/registro': (context) => const RegistroScreen(),
        '/recuperar-pass': (context) => const RecuperarPassScreen(),
        '/restablecer-pass': (context) => const RestablecerPassScreen(),
      },
    );
  }
}
