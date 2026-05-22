import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../utils/qr_saver.dart';

class QrGeneratorDialog extends StatelessWidget {
  const QrGeneratorDialog({super.key});

  @override
  Widget build(BuildContext context) {
    const String urlSolicitud = "http://192.168.0.4:8080/#/solicitud";

    return AlertDialog(
      title: const Text("Generar QR de Préstamo"),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Este código dirigirá a los estudiantes al formulario de solicitud.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Container(
              width: 250,
              height: 250,
              alignment: Alignment.center,
              child: QrImageView(
                data: urlSolicitud,
                version: QrVersions.auto,
                size: 250.0,
                gapless: false,
                foregroundColor: const Color(0xFF00843D),
              ),
            ),
            const SizedBox(height: 20),
            const SelectableText(
              urlSolicitud,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cerrar"),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            final svgString = Barcode.qrCode().toSvg(
              urlSolicitud,
              width: 200,
              height: 200,
            );
            await guardarQrComoSvg(svgString);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("QR guardado como qr_prestamo_sgi.svg")),
              );
            }
          },
          icon: const Icon(Icons.save),
          label: const Text("Guardar"),
        ),
      ],
    );
  }
}
