import 'dart:io';

Future<void> guardarQrComoSvg(String svgString, {String fileName = 'qr_sgi.svg'}) async {
  final home = Platform.environment['HOME'] ?? '/tmp';
  final file = File('$home/$fileName');
  await file.writeAsString(svgString);
}
