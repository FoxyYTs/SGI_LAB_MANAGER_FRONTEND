import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/theme/colors.dart';

class RestablecerPassScreen extends StatefulWidget {
  const RestablecerPassScreen({super.key});

  @override
  State<RestablecerPassScreen> createState() => _RestablecerPassScreenState();
}

class _RestablecerPassScreenState extends State<RestablecerPassScreen> {
  final _emailCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();

  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscurePass2 = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _tokenCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _handleRestablecer() async {
    final email = _emailCtrl.text.trim();
    final token = _tokenCtrl.text.trim();
    final password = _passCtrl.text;
    final password2 = _pass2Ctrl.text;

    if ([email, token, password, password2].any((s) => s.isEmpty)) {
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
        'usuarios/restablecer-password/',
        data: {
          'email': email,
          'token': token,
          'nueva_password': password,
          'nueva_password2': password2,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contraseña restablecida. Ya puedes iniciar sesión.'),
            backgroundColor: kSuccess,
          ),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } catch (e) {
      String msg = 'Error al restablecer la contraseña.';
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
              constraints: const BoxConstraints(maxWidth: 420),
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
                          Icon(Icons.vpn_key, color: Colors.white, size: 28),
                          SizedBox(width: 10),
                          Text(
                            'Nueva Contraseña',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        children: [
                          const Text(
                            'Ingresa el código que recibiste en tu correo y establece tu nueva contraseña.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: kTextMuted, height: 1.5),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Correo electrónico',
                              prefixIcon: Icon(Icons.email_outlined, color: kPrimary),
                              border: OutlineInputBorder(),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: kPrimary, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _tokenCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Código de recuperación',
                              prefixIcon: Icon(Icons.tag, color: kPrimary),
                              border: OutlineInputBorder(),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: kPrimary, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _passCtrl,
                            obscureText: _obscurePass,
                            decoration: InputDecoration(
                              labelText: 'Nueva contraseña',
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
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _pass2Ctrl,
                            obscureText: _obscurePass2,
                            decoration: InputDecoration(
                              labelText: 'Confirmar contraseña',
                              prefixIcon: const Icon(Icons.lock_outline, color: kPrimary),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePass2 ? Icons.visibility : Icons.visibility_off),
                                onPressed: () => setState(() => _obscurePass2 = !_obscurePass2),
                              ),
                              border: const OutlineInputBorder(),
                              focusedBorder: const OutlineInputBorder(
                                borderSide: BorderSide(color: kPrimary, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: _isLoading
                                ? const Center(child: CircularProgressIndicator(color: kPrimary))
                                : ElevatedButton.icon(
                                    onPressed: _handleRestablecer,
                                    icon: const Icon(Icons.check_circle_outline),
                                    label: const Text(
                                      'Cambiar contraseña',
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
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Volver',
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
}
