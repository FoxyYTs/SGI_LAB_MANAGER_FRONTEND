import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

const kMimePdf = 'application/pdf';
const kMimeDocx =
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

/// Guarda [bytes] en un temporal y lo abre con la app del sistema. La app
/// que lo abre se elige por la extensión de [filename] (.pdf, .docx...);
/// [mimeType] se acepta por simetría con la versión web.
Future<String?> saveAndOpenFile(List<int> bytes, String filename,
    {String? mimeType}) async {
  final file = File('${Directory.systemTemp.path}/$filename');
  await file.writeAsBytes(bytes);
  final uri = Uri.file(file.path);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
    return null;
  }
  return 'Guardado en: ${file.path}';
}
