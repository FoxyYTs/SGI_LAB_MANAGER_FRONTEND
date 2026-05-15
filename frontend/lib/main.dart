import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/inventario_provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/inventario_screen.dart';
import 'screens/solicitud_prestamo_screen.dart';


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
        primarySwatch: Colors.green,
        useMaterial3: true, // Se ve mejor en sistemas modernos como Arch
      ),
      home: const LoginScreen(),
      routes: {
        '/dashboard': (context) => DashboardScreen(),
        '/inventario': (context) => InventarioScreen(),
        '/solicitud': (context) => SolicitudPrestamoScreen(),
      },
    );
  }
}