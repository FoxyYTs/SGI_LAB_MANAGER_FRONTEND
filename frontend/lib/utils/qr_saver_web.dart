import 'package:web/web.dart' as web;

Future<void> guardarQrComoSvg(String svgString) async {
  final dataUri = Uri.dataFromString(svgString, mimeType: 'image/svg+xml').toString();
  web.HTMLAnchorElement()
    ..href = dataUri
    ..setAttribute('download', 'qr_prestamo_sgi.svg')
    ..click();
}
