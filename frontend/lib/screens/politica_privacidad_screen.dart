import 'package:flutter/material.dart';
import '../core/theme/colors.dart';

class PoliticaPrivacidadScreen extends StatelessWidget {
  const PoliticaPrivacidadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Política de Privacidad'),
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: _PolicyContent(),
      ),
    );
  }
}

class _PolicyContent extends StatelessWidget {
  const _PolicyContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _Title('Política de Privacidad — SGI LAB MANAGER'),
        _Meta('Última actualización: agosto de 2026'),
        SizedBox(height: 16),

        _Section('1. Responsable del tratamiento'),
        _Body(
          'El Politécnico Colombiano Jaime Isaza Cadavid (PCJIC), sede regional '
          'Rionegro, Antioquia, es el responsable del tratamiento de los datos '
          'personales recopilados a través de esta aplicación, de conformidad con '
          'la Ley 1581 de 2012 y el Decreto 1377 de 2013.',
        ),

        _Section('2. Datos que recopilamos'),
        _Body(
          'La aplicación recopila y trata los siguientes datos personales:\n\n'
          '• Nombre de usuario y contraseña (almacenada con hash seguro).\n'
          '• Nombre completo y correo electrónico institucional.\n'
          '• Rol dentro del sistema (Administrador, Monitor, Docente, etc.).\n'
          '• Registros de actividad: movimientos de inventario, préstamos, '
          'prácticas de laboratorio y horas de monitoría.',
        ),

        _Section('3. Finalidad del tratamiento'),
        _Body(
          'Los datos son usados exclusivamente para:\n\n'
          '• Autenticar el acceso al sistema de gestión del laboratorio.\n'
          '• Registrar y controlar el inventario, préstamos de implementos '
          'y prácticas académicas.\n'
          '• Generar informes de uso del laboratorio para fines académicos '
          'e institucionales.',
        ),

        _Section('4. Almacenamiento y seguridad'),
        _Body(
          'Los datos se almacenan en servidores institucionales del PCJIC '
          'protegidos mediante HTTPS y cifrado en reposo. En el dispositivo '
          'móvil, las credenciales de sesión se guardan en almacenamiento '
          'seguro cifrado (flutter_secure_storage / EncryptedSharedPreferences). '
          'No compartimos datos con terceros fuera del PCJIC.',
        ),

        _Section('5. Derechos del titular'),
        _Body(
          'De acuerdo con la Ley 1581 de 2012, usted tiene derecho a:\n\n'
          '• Conocer, actualizar y rectificar sus datos personales.\n'
          '• Solicitar la supresión de sus datos cuando no sean necesarios.\n'
          '• Revocar la autorización de tratamiento en cualquier momento.\n\n'
          'Para ejercer estos derechos, comuníquese con la administración del '
          'laboratorio en las instalaciones del PCJIC Rionegro.',
        ),

        _Section('6. Vigencia'),
        _Body(
          'Esta política rige mientras la aplicación esté en operación. '
          'Cualquier cambio sustancial será notificado a los usuarios activos '
          'a través de la aplicación.',
        ),

        SizedBox(height: 24),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  final String text;
  const _Title(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 17, fontWeight: FontWeight.w800, color: kPrimary,
        ),
      );
}

class _Meta extends StatelessWidget {
  final String text;
  const _Meta(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(text, style: const TextStyle(fontSize: 12, color: kTextMuted)),
      );
}

class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700, color: kPrimary,
          ),
        ),
      );
}

class _Body extends StatelessWidget {
  final String text;
  const _Body(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.6),
      );
}
