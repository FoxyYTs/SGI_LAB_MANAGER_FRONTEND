import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/theme/colors.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _identificacionCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();

  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscurePass2 = true;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _identificacionCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _handleRegistro() async {
    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final identificacion = _identificacionCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;
    final password2 = _pass2Ctrl.text;

    if ([firstName, lastName, identificacion, username, email, password, password2]
        .any((s) => s.isEmpty)) {
      _showError('Todos los campos son obligatorios.');
      return;
    }

    if (password != password2) {
      _showError('Las contraseñas no coinciden.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ApiClient.instance.dio.post(
        'usuarios/registro/',
        data: {
          'first_name': firstName,
          'last_name': lastName,
          'identificacion': identificacion,
          'username': username,
          'email': email,
          'password': password,
          'password2': password2,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cuenta creada exitosamente. Ya puedes iniciar sesión.'),
            backgroundColor: kSuccess,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      String msg = 'Error al crear la cuenta.';
      try {
        final data = (e as dynamic).response?.data;
        if (data is Map) msg = data['error'] ?? msg;
      } catch (_) {}
      if (mounted) _showError(msg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: kDanger),
    );
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
            colors: [Color(0xFF002D72), Color(0xFF0056B3), Color(0xFF007BFF)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                elevation: 12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Cabecera
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
                          Icon(Icons.person_add, color: Colors.white, size: 28),
                          SizedBox(width: 10),
                          Text(
                            'Crear Cuenta',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Formulario
                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _field(
                                  controller: _firstNameCtrl,
                                  label: 'Nombres',
                                  icon: Icons.badge_outlined,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _field(
                                  controller: _lastNameCtrl,
                                  label: 'Apellidos',
                                  icon: Icons.badge_outlined,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _field(
                            controller: _identificacionCtrl,
                            label: 'Cédula / NIT',
                            icon: Icons.credit_card,
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 14),
                          _field(
                            controller: _usernameCtrl,
                            label: 'Usuario',
                            icon: Icons.person,
                          ),
                          const SizedBox(height: 14),
                          _field(
                            controller: _emailCtrl,
                            label: 'Correo electrónico',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 14),
                          _passField(
                            controller: _passCtrl,
                            label: 'Contraseña',
                            obscure: _obscurePass,
                            onToggle: () => setState(() => _obscurePass = !_obscurePass),
                          ),
                          const SizedBox(height: 14),
                          _passField(
                            controller: _pass2Ctrl,
                            label: 'Confirmar contraseña',
                            obscure: _obscurePass2,
                            onToggle: () => setState(() => _obscurePass2 = !_obscurePass2),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: _isLoading
                                ? const Center(child: CircularProgressIndicator(color: kPrimary))
                                : ElevatedButton.icon(
                                    onPressed: _handleRegistro,
                                    icon: const Icon(Icons.check),
                                    label: const Text('Registrarme', style: TextStyle(fontSize: 16)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: kSuccess,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              '¿Ya tienes cuenta? Inicia sesión',
                              style: TextStyle(color: kPrimary),
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

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: kPrimary),
        border: const OutlineInputBorder(),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: kPrimary, width: 2),
        ),
      ),
    );
  }

  Widget _passField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline, color: kPrimary),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
          onPressed: onToggle,
        ),
        border: const OutlineInputBorder(),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: kPrimary, width: 2),
        ),
      ),
    );
  }
}
