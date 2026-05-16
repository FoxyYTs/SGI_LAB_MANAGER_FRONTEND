import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/theme/colors.dart';

class RecuperarPassScreen extends StatefulWidget {
  const RecuperarPassScreen({super.key});

  @override
  State<RecuperarPassScreen> createState() => _RecuperarPassScreenState();
}

class _RecuperarPassScreenState extends State<RecuperarPassScreen> {
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;
  bool _enviado = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleEnviar() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa tu correo electrónico.'), backgroundColor: kDanger),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ApiClient.instance.dio.post(
        'usuarios/recuperar-password/',
        data: {'email': email},
      );
      if (mounted) setState(() => _enviado = true);
    } catch (_) {
      // El backend devuelve 200 incluso si el correo no existe (por seguridad)
      if (mounted) setState(() => _enviado = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
            colors: [Color(0xFF002D72), Color(0xFF0056B3), Color(0xFF007BFF)],
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
                          Icon(Icons.lock_reset, color: Colors.white, size: 28),
                          SizedBox(width: 10),
                          Text(
                            'Recuperar Contraseña',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: _enviado ? _buildConfirmacion() : _buildFormulario(),
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

  Widget _buildFormulario() {
    return Column(
      children: [
        const Text(
          'Ingresa tu correo electrónico y te enviaremos un código para restablecer tu contraseña.',
          textAlign: TextAlign.center,
          style: TextStyle(color: kTextMuted, height: 1.5),
        ),
        const SizedBox(height: 24),
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
          onSubmitted: (_) => _handleEnviar(),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: kPrimary))
              : ElevatedButton.icon(
                  onPressed: _handleEnviar,
                  icon: const Icon(Icons.send),
                  label: const Text('Enviar código', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Volver al inicio de sesión', style: TextStyle(color: kPrimary)),
        ),
      ],
    );
  }

  Widget _buildConfirmacion() {
    return Column(
      children: [
        const Icon(Icons.mark_email_read_outlined, size: 64, color: kSuccess),
        const SizedBox(height: 16),
        const Text(
          'Si el correo está registrado, recibirás un enlace en tu bandeja de entrada.',
          textAlign: TextAlign.center,
          style: TextStyle(height: 1.5),
        ),
        const SizedBox(height: 12),
        const Text(
          'Abre el correo y haz clic en el botón "Restablecer contraseña".\nEl enlace es válido por 1 hora.',
          textAlign: TextAlign.center,
          style: TextStyle(color: kTextMuted, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 28),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Volver al inicio de sesión', style: TextStyle(color: kPrimary)),
        ),
      ],
    );
  }
}
