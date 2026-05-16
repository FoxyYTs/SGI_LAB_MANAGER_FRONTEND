import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../core/theme/colors.dart';

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
    setState(() => _isLoading = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.login(_userController.text.trim(), _passController.text);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuario o contraseña incorrectos'),
            backgroundColor: kDanger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
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
                    // Cabecera azul estilo Bootstrap card-header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: const BoxDecoration(
                        color: kPrimary,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock, color: Colors.white, size: 28),
                          SizedBox(width: 10),
                          Text(
                            "Iniciar Sesión",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
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
                                : ElevatedButton.icon(
                                    onPressed: _handleLogin,
                                    icon: const Icon(Icons.login),
                                    label: const Text(
                                      "Iniciar Sesión",
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: kSuccess,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
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
                          const Text(
                            "SGI LAB MANAGER",
                            style: TextStyle(
                              color: kTextMuted,
                              fontSize: 12,
                              letterSpacing: 1.2,
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
        ),
      ),
    );
  }
}
