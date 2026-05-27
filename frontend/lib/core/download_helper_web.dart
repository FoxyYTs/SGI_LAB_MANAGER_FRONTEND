import 'dart:typed_data';
import 'dart:js_interop';
import 'package:web/web.dart';

Future<String?> saveAndOpenFile(List<int> bytes, String filename) async {
  final jsArray = Uint8List.fromList(bytes).toJS;
  final blob = Blob(
    [jsArray].toJS,
    BlobPropertyBag(type: 'application/octet-stream'),
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
