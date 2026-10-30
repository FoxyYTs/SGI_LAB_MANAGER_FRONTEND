import 'package:flutter/material.dart';
import '../core/theme/colors.dart';
import '../core/theme/app_theme.dart';

class PoliticaPrivacidadScreen extends StatelessWidget {
  const PoliticaPrivacidadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Política de Privacidad'),
        backgroundColor: context.sgi.brandBar,
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
        _Meta('Última actualización: 30 de octubre de 2026'),
        SizedBox(height: 16),

        _Section('1. Responsable del tratamiento'),
        _Body(
          'El responsable del tratamiento de los datos personales recopilados a '
          'través de esta aplicación es el Politécnico Colombiano Jaime Isaza '
          'Cadavid (PCJIC), sede regional Rionegro, Antioquia, de conformidad con '
          'la Ley 1581 de 2012 y el Decreto 1377 de 2013.\n\n'
          'José Andrés Daza Gallego, desarrollador y administrador técnico del '
          'sistema, actúa como encargado del tratamiento por cuenta del PCJIC.',
        ),

        _Section('2. Datos que recopilamos'),
        _Body(
          '• Nombre completo, nombre de usuario y correo electrónico.\n'
          '• Número de identificación, teléfono y programa académico.\n'
          '• Foto de perfil (opcional).\n'
          '• Contraseña, almacenada con hash seguro.\n'
          '• Registros de uso: préstamos, movimientos de inventario, horas de '
          'monitor y prácticas de laboratorio.\n\n'
          'En el módulo de impresiones 3D el personal registra además datos de '
          'personas externas: nombre, y de forma opcional documento y correo o '
          'teléfono (solo con autorización expresa del cliente, guardada con su '
          'fecha), junto con los datos del trabajo y del pago.',
        ),

        _Section('3. Finalidad del tratamiento'),
        _Body(
          '• Gestionar el acceso al sistema del laboratorio.\n'
          '• Registrar inventario, préstamos y prácticas académicas.\n'
          '• Controlar horarios de encargados y horas de monitoría.\n'
          '• Enviar notificaciones operativas del laboratorio.\n'
          '• Cotizar y registrar el cobro de impresiones 3D.\n\n'
          'Los datos no se usan con fines comerciales ni publicitarios. Los de '
          'clientes de impresiones 3D se conservan mientras sirvan de soporte del '
          'cobro.',
        ),

        _Section('4. Almacenamiento y seguridad'),
        _Body(
          'Los datos se almacenan en servidores bajo control institucional en '
          'Colombia, con comunicaciones cifradas (HTTPS/TLS), contraseñas con hash '
          'seguro y copias de seguridad cifradas. En el teléfono, la sesión se '
          'guarda en almacenamiento seguro cifrado y los datos de la app no se '
          'incluyen en copias de seguridad ni en transferencias a otro dispositivo.',
        ),

        _Section('5. Compartición de datos'),
        _Body(
          'Los datos no se venden ni se comparten con terceros para fines propios '
          'de ellos. La aplicación usa como encargados del tratamiento a Google '
          'Firebase Cloud Messaging (notificaciones; recibe un identificador del '
          'dispositivo) y Google Analytics (estadísticas de uso de la versión web, '
          'sin nombres, correos ni documentos). Estos servicios pueden procesar '
          'datos fuera de Colombia (transferencia internacional). Fuera de esto, '
          'los datos solo se entregan por obligación legal.',
        ),

        _Section('6. Derechos del titular'),
        _Body(
          'De acuerdo con la Ley 1581 de 2012, usted puede conocer, actualizar, '
          'rectificar y solicitar la supresión de sus datos, revocar la '
          'autorización y presentar quejas ante la Superintendencia de Industria '
          'y Comercio (SIC).\n\n'
          'Para ejercer estos derechos escriba a foxy200442@gmail.com.',
        ),

        _Section('7. Vigencia'),
        _Body(
          'Esta versión rige desde el 30 de octubre de 2026. Los cambios sustanciales se '
          'notifican en la aplicación y se publican en '
          'sgilabmanager.foxyyts.qzz.io/politica-privacidad.',
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
        style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface, height: 1.6),
      );
}
