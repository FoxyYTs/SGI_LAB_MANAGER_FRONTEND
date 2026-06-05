import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/colors.dart';
import '../services/update_service.dart' show kAppVersion;

void showSgiAboutDialog(BuildContext context) {
  showDialog(context: context, builder: (_) => const _AboutDialog());
}

class _AboutDialog extends StatelessWidget {
  const _AboutDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icono / logo
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.science_outlined, color: kPrimary, size: 38),
              ),
              const SizedBox(height: 16),

              // Nombre del proyecto
              const Text('SGI LAB MANAGER',
                  style: TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 18,
                      letterSpacing: 0.8, color: kPrimary)),
              const SizedBox(height: 4),
              Text('v$kAppVersion',
                  style: const TextStyle(fontSize: 13, color: kTextMuted)),
              const SizedBox(height: 20),

              // Descripción
              const Text(
                'Sistema de Gestión de Inventarios para Laboratorio Integrado.\n'
                'Desarrollado para el PCJIC Rionegro, Colombia.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: kTextMuted, height: 1.5),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // Autor
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.person_outline, size: 16, color: kTextMuted),
                const SizedBox(width: 6),
                const Text('Desarrollado por ', style: TextStyle(fontSize: 13, color: kTextMuted)),
                const Text('FoxyYTs',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kPrimary)),
              ]),
              const SizedBox(height: 20),

              // Botones de enlace
              _LinkButton(
                icon: Icons.code,
                label: 'Código fuente',
                sublabel: 'github.com/FoxyYTs/SGI_LAB_MANAGER_FRONTEND',
                url: 'https://github.com/FoxyYTs/SGI_LAB_MANAGER_FRONTEND',
              ),
              const SizedBox(height: 10),
              _LinkButton(
                icon: Icons.download_outlined,
                label: 'Última versión',
                sublabel: 'Descargar APK / ver releases',
                url: 'https://github.com/FoxyYTs/SGI_LAB_MANAGER_FRONTEND/releases/latest',
                filled: true,
              ),
              const SizedBox(height: 20),

              // Licencia
              const Text(
                'Proyecto de código abierto — MIT License',
                style: TextStyle(fontSize: 11, color: kTextMuted),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   sublabel;
  final String   url;
  final bool     filled;

  const _LinkButton({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.url,
    this.filled = false,
  });

  Future<void> _open() async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: filled
          ? ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: Icon(icon, size: 18),
              label: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(sublabel, style: const TextStyle(fontSize: 10, color: Colors.white70)),
                ],
              ),
              onPressed: _open,
            )
          : OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: kPrimary,
                side: const BorderSide(color: kPrimary),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: Icon(icon, size: 18),
              label: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(sublabel, style: const TextStyle(fontSize: 10, color: kTextMuted)),
                ],
              ),
              onPressed: _open,
            ),
    );
  }
}
