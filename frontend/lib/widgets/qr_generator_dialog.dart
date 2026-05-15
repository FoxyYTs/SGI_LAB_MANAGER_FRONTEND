import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'dart:html' as html;

class QrGeneratorDialog extends StatelessWidget {
  const QrGeneratorDialog({super.key});

  @override
  Widget build(BuildContext context) {
    const String urlSolicitud = "http://10.51.1.226:8080/#/solicitud"; 

    return AlertDialog(
      title: const Text("Generar QR de Préstamo"),
      content: SizedBox( // Usamos SizedBox para dar dimensiones explícitas
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
            // Envolvemos el QR en un Container con tamaño fijo para evitar el error intrínseco
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
          onPressed: () {
            final barcode = Barcode.qrCode();
            final svgString = barcode.toSvg(
                'http://10.51.1.226:8080/#/solicitud',
                width: 200,
                height: 200,
            );

            // 2. Creamos un "ancla" en el navegador para descargar el archivo
            final bytes = Uri.dataFromString(svgString, mimeType: 'image/svg+xml').toString();
            final anchor = html.AnchorElement(href: bytes)
                ..setAttribute("download", "qr_prestamo_sgi.svg")
                ..click();
                
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Descargando SVG...")),
            );
          },
          icon: const Icon(Icons.save),
          label: const Text("Guardar"),
        ),
      ],
    );
  }
}