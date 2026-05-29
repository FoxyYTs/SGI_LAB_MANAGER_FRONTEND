import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../utils/qr_saver.dart';
import '../core/theme/colors.dart';

const _kFrontendUrl = String.fromEnvironment('FRONTEND_URL', defaultValue: '');

class QrGeneratorDialog extends StatefulWidget {
  const QrGeneratorDialog({super.key});

  @override
  State<QrGeneratorDialog> createState() => _QrGeneratorDialogState();
}

class _QrGeneratorDialogState extends State<QrGeneratorDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  static const _forms = [
    _QrForm(
      title:    'Solicitud de Préstamo',
      route:    '/solicitud',
      icon:     Icons.handshake_outlined,
      color:    kPrimary,
      desc:     'Formulario para que estudiantes soliciten materiales.',
      fileName: 'qr_prestamo_sgi.svg',
    ),
    _QrForm(
      title:    'Registro de Horas',
      route:    '/registro-horas',
      icon:     Icons.access_time_outlined,
      color:    kSuccess,
      desc:     'Check-in / check-out de monitores y laboratoristas.',
      fileName: 'qr_horas_sgi.svg',
    ),
    _QrForm(
      title:       'Registro de Práctica',
      route:       '/registro-practica',
      externalUrl: 'https://forms.gle/HQsUXGpVa6u2dJVR7',
      icon:        Icons.science_outlined,
      color:       Color(0xFF7B61FF),
      desc:        'Registro de prácticas por docentes (Google Forms).',
      fileName:    'qr_practica_sgi.svg',
    ),
    _QrForm(
      title:    'Reporte de Rotura',
      route:    '/reporte-rotura',
      icon:     Icons.report_outlined,
      color:    kDanger,
      desc:     'Estudiantes reportan implementos rotos o perdidos.',
      fileName: 'qr_rotura_sgi.svg',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _forms.length, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  static String _buildUrl(String route) {
    if (kIsWeb) {
      return '${Uri.base.origin}/#$route';
    }
    if (_kFrontendUrl.isNotEmpty) {
      final base = _kFrontendUrl.endsWith('/')
          ? _kFrontendUrl.substring(0, _kFrontendUrl.length - 1)
          : _kFrontendUrl;
      return '$base/#$route';
    }
    return 'http://localhost:8080/#$route';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              decoration: const BoxDecoration(
                color: kPrimary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: TabBar(
                controller: _tab,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                indicatorColor: Colors.white,
                dividerColor: Colors.transparent,
                tabs: _forms.map((f) => Tab(
                  icon: Icon(f.icon, size: 18),
                  text: f.title,
                )).toList(),
              ),
            ),

            // Content
            SizedBox(
              height: 400,
              child: TabBarView(
                controller: _tab,
                children: _forms.map((f) {
                  final url = f.externalUrl ?? _buildUrl(f.route);
                  return _QrTab(form: f, url: url);
                }).toList(),
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final f = _forms[_tab.index];
                      final url = f.externalUrl ?? _buildUrl(f.route);
                      final svgString = Barcode.qrCode().toSvg(url, width: 200, height: 200);
                      await guardarQrComoSvg(svgString, fileName: f.fileName);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('QR guardado como ${f.fileName}')),
                        );
                      }
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Guardar QR'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrTab extends StatelessWidget {
  final _QrForm form;
  final String url;

  const _QrTab({required this.form, required this.url});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            form.desc,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: form.color.withValues(alpha: 0.3), width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: QrImageView(
              data: url,
              version: QrVersions.auto,
              size: 200.0,
              gapless: false,
              eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: form.color),
              dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: form.color),
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            url,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _QrForm {
  final String title;
  final String route;
  final String? externalUrl;
  final IconData icon;
  final Color color;
  final String desc;
  final String fileName;

  const _QrForm({
    required this.title,
    required this.route,
    this.externalUrl,
    required this.icon,
    required this.color,
    required this.desc,
    required this.fileName,
  });
}
