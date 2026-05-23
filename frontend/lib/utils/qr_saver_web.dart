import 'package:web/web.dart' as web;

Future<void> guardarQrComoSvg(String svgString, {String fileName = 'qr_sgi.svg'}) async {
  final dataUri = Uri.dataFromString(svgString, mimeType: 'image/svg+xml').toString();
  web.HTMLAnchorElement()
    ..href = dataUri
    ..setAttribute('download', fileName)
    ..click();
}
