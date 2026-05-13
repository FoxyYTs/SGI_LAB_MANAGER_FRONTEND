import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
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
        '/dashboard': (context) => const Scaffold(
          body: Center(child: Text("¡Login exitoso! Bienvenido al Dashboard")),
        ),
      },
    );
  }
}