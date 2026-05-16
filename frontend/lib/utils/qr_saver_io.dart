import 'dart:io';

Future<void> guardarQrComoSvg(String svgString) async {
  final home = Platform.environment['HOME'] ?? '/tmp';
  final file = File('$home/qr_prestamo_sgi.svg');
  await file.writeAsString(svgString);
}
