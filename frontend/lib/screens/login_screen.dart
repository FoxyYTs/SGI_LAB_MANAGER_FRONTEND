import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../core/theme/colors.dart';
import '../core/log_service.dart';
import '../core/api/api_client.dart';
import '../core/sync/sync_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePass = true;

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    // En móvil/desktop, bloquear login si no hay conexión a internet.
    if (!kIsWeb && !SyncService.instance.online) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.wifi_off, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Expanded(child: Text('Sin conexión a internet.\nEl inicio de sesión requiere conexión.')),
          ]),
          backgroundColor: kDanger,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final error = await auth.login(_userController.text.trim(), _passController.text);

    if (mounted) {
      setState(() => _isLoading = false);
      if (error == null) {
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: kDanger,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: LogService.enabled
          ? Container(
              color: LogService.devMode
                  ? const Color(0xFF8B0000)
                  : const Color(0xFFFF6B00),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                LogService.devMode
                    ? 'DEV MODE  ·  ${ApiClient.instance.baseUrl}'
                        '\nLog: ${LogService.logPath ?? "inicializando…"}'
                    : 'DIAGNÓSTICO  ·  Log: ${LogService.logPath ?? "inicializando…"}',
                style: const TextStyle(color: Colors.white, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            )
          : null,
      body: Column(children: [
        // Banner offline
        if (!kIsWeb)
          ListenableBuilder(
            listenable: SyncService.instance,
            builder: (_, __) => SyncService.instance.online
                ? const SizedBox.shrink()
                : Material(
                    color: const Color(0xFFB71C1C),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(children: const [
                          Icon(Icons.wifi_off, color: Colors.white, size: 16),
                          SizedBox(width: 8),
                          Expanded(child: Text(
                            'Sin conexión — el inicio de sesión no está disponible',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          )),
                        ]),
                      ),
                    ),
                  ),
          ),
        Expanded(child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF002D72),
              Color(0xFF0056B3),
              Color(0xFF007BFF),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Cabecera con ícono de laboratorio
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: const Column(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Color(0xFFE3F2FD),
                            child: Icon(Icons.science, color: kPrimary, size: 30),
                          ),
                          SizedBox(height: 12),
                          Text(
                            "SGI LAB MANAGER",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: kPrimary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Laboratorios de Ciencias Básicas",
                            style: TextStyle(fontSize: 12, color: kTextMuted),
                          ),
                        ],
                      ),
                    ),
                    // Cuerpo del formulario
                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        children: [
                          TextField(
                            controller: _userController,
                            decoration: InputDecoration(
                              labelText: 'Usuario',
                              prefixIcon: const Icon(Icons.person, color: kPrimary),
                              border: const OutlineInputBorder(),
                              focusedBorder: const OutlineInputBorder(
                                borderSide: BorderSide(color: kPrimary, width: 2),
                              ),
                            ),
                            onSubmitted: (_) => _handleLogin(),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passController,
                            obscureText: _obscurePass,
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: const Icon(Icons.lock_outline, color: kPrimary),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePass ? Icons.visibility : Icons.visibility_off),
                                onPressed: () => setState(() => _obscurePass = !_obscurePass),
                              ),
                              border: const OutlineInputBorder(),
                              focusedBorder: const OutlineInputBorder(
                                borderSide: BorderSide(color: kPrimary, width: 2),
                              ),
                            ),
                            onSubmitted: (_) => _handleLogin(),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: _isLoading
                                ? const Center(child: CircularProgressIndicator(color: kPrimary))
                                : ElevatedButton(
                                    onPressed: _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: kPrimary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: const Text(
                                      "Ingresar",
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pushNamed(context, '/recuperar-pass'),
                                child: const Text(
                                  'Olvidé mi contraseña',
                                  style: TextStyle(color: kPrimary, fontSize: 13),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pushNamed(context, '/registro'),
                                child: const Text(
                                  'Crear cuenta',
                                  style: TextStyle(color: kPrimary, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Divider(height: 1),
                          TextButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/politica-privacidad'),
                            child: const Text(
                              'Política de Privacidad',
                              style: TextStyle(color: kTextMuted, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ))),
      ]),
    );
  }
}
