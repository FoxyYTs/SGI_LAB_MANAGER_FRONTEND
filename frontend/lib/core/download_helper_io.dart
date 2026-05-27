import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

Future<String?> saveAndOpenFile(List<int> bytes, String filename) async {
  final file = File('${Directory.systemTemp.path}/$filename');
  await file.writeAsBytes(bytes);
  final uri = Uri.file(file.path);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
    return null;
  }
  return 'Guardado en: ${file.path}';
}
