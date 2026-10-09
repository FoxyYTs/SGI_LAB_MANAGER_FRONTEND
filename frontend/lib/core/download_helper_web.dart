import 'dart:typed_data';
import 'dart:js_interop';
import 'package:web/web.dart';

const kMimePdf = 'application/pdf';
const kMimeDocx =
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

/// Descarga [bytes] como [filename]. [mimeType] (p. ej. [kMimeDocx]) le dice
/// al navegador qué es el archivo; sin él se usa octet-stream como antes.
Future<String?> saveAndOpenFile(List<int> bytes, String filename,
    {String? mimeType}) async {
  final jsArray = Uint8List.fromList(bytes).toJS;
  final blob = Blob(
    [jsArray].toJS,
    BlobPropertyBag(type: mimeType ?? 'application/octet-stream'),
  );
  final url = URL.createObjectURL(blob);
  final anchor = document.createElement('a') as HTMLAnchorElement
    ..href = url
    ..download = filename;
  document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  URL.revokeObjectURL(url);
  return null;
}
