import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Versión actual compilada en la app. Debe coincidir con pubspec.yaml.
/// Inyectada en build: --dart-define=APP_VERSION=1.0.0
const kAppVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

const _kGithubRepo = 'FoxyYTs/SGI_LAB_MANAGER_FRONTEND';

class UpdateInfo {
  final String version;
  final String downloadUrl;
  const UpdateInfo({required this.version, required this.downloadUrl});
}

class UpdateService {
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Accept': 'application/vnd.github.v3+json'},
  ));

  /// Consulta la GitHub Releases API. Devuelve null si no hay actualización
  /// o si ocurre cualquier error (sin lanzar excepciones).
  static Future<UpdateInfo?> verificarActualizacion() async {
    if (kIsWeb) return null;
    if (!Platform.isLinux && !Platform.isWindows) return null;

    try {
      final resp = await _dio.get(
        'https://api.github.com/repos/$_kGithubRepo/releases/latest',
      );
      final data = resp.data as Map<String, dynamic>;
      final tag = ((data['tag_name'] as String?) ?? '').replaceAll('v', '');

      if (!_esVersionNueva(tag, kAppVersion)) return null;

      final assets = (data['assets'] as List<dynamic>?) ?? [];
      String? url;
      for (final a in assets) {
        final name = (a['name'] as String?) ?? '';
        if (Platform.isLinux  && name.contains('linux')   && name.endsWith('.tar.gz')) {
          url = a['browser_download_url'] as String?;
          break;
        }
        if (Platform.isWindows && name.contains('windows') && name.endsWith('.zip')) {
          url = a['browser_download_url'] as String?;
          break;
        }
      }
      if (url == null) return null;

      return UpdateInfo(version: tag, downloadUrl: url);
    } catch (_) {
      return null;
    }
  }

  /// Descarga e instala la actualización. Llama [onProgress] con 0.0–1.0.
  /// Al terminar lanza el script de reemplazo y cierra la app.
  static Future<void> descargarEInstalar(
    UpdateInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    if (Platform.isLinux)   await _instalarLinux(info, onProgress: onProgress);
    if (Platform.isWindows) await _instalarWindows(info, onProgress: onProgress);
  }

  // ── Linux ─────────────────────────────────────────────────────────────────

  static Future<void> _instalarLinux(
    UpdateInfo info, {
    void Function(double)? onProgress,
  }) async {
    final tmp         = Directory.systemTemp.path;
    final archivePath = p.join(tmp, 'sgi-update-v${info.version}.tar.gz');
    final extractDir  = p.join(tmp, 'sgi-update-extracted');
    final installDir  = p.dirname(Platform.resolvedExecutable);
    final executable  = Platform.resolvedExecutable;

    await _descargar(info.downloadUrl, archivePath, onProgress);

    final dir = Directory(extractDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync();

    final tar = await Process.run(
      'tar', ['-xzf', archivePath, '-C', extractDir, '--strip-components=1'],
    );
    if (tar.exitCode != 0) throw Exception('Error al extraer: ${tar.stderr}');

    final scriptPath = p.join(tmp, 'sgi-update.sh');
    await File(scriptPath).writeAsString('''#!/bin/bash
sleep 2
cp -rf "$extractDir"/. "$installDir"/
rm -rf "$extractDir" "$archivePath"
exec "$executable"
''');
    await Process.run('chmod', ['+x', scriptPath]);
    await Process.start('/bin/bash', [scriptPath], mode: ProcessStartMode.detached);
    exit(0);
  }

  // ── Windows ───────────────────────────────────────────────────────────────

  static Future<void> _instalarWindows(
    UpdateInfo info, {
    void Function(double)? onProgress,
  }) async {
    final tmp         = Directory.systemTemp.path;
    final archivePath = p.join(tmp, 'sgi-update-v${info.version}.zip');
    final extractDir  = p.join(tmp, 'sgi-update-extracted');
    final installDir  = p.dirname(Platform.resolvedExecutable);
    final exeName     = p.basename(Platform.resolvedExecutable);  // frontend.exe
    final procName    = p.basenameWithoutExtension(exeName);       // frontend

    await _descargar(info.downloadUrl, archivePath, onProgress);

    // Extraer con PowerShell (disponible en Windows 10+)
    final dir = Directory(extractDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    final ps = await Process.run('powershell', [
      '-NoProfile', '-NonInteractive', '-Command',
      'Expand-Archive -Path "$archivePath" -DestinationPath "$extractDir" -Force',
    ]);
    if (ps.exitCode != 0) throw Exception('Error al extraer: ${ps.stderr}');

    // Script PowerShell: espera que el proceso termine, copia y relanza
    final scriptPath = p.join(tmp, 'sgi-update.ps1');
    await File(scriptPath).writeAsString(r'''
param($installDir, $extractDir, $archive, $exeName, $procName)

$maxWait = 30; $elapsed = 0
while ((Get-Process -Name $procName -ErrorAction SilentlyContinue) -and $elapsed -lt $maxWait) {
    Start-Sleep -Seconds 1; $elapsed++
}
Start-Sleep -Seconds 1

Copy-Item -Path "$extractDir\*" -Destination $installDir -Recurse -Force
Remove-Item -Path $extractDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path $archive    -Force          -ErrorAction SilentlyContinue
Start-Process "$installDir\$exeName"
''');

    await Process.start(
      'powershell',
      [
        '-NoProfile', '-NonInteractive', '-WindowStyle', 'Hidden',
        '-File', scriptPath,
        '-installDir', installDir,
        '-extractDir', extractDir,
        '-archive',    archivePath,
        '-exeName',    exeName,
        '-procName',   procName,
      ],
      mode: ProcessStartMode.detached,
    );
    exit(0);
  }

  // ── Utilidades ────────────────────────────────────────────────────────────

  static Future<void> _descargar(
    String url,
    String destPath,
    void Function(double)? onProgress,
  ) async {
    await _dio.download(
      url,
      destPath,
      onReceiveProgress: (recibido, total) {
        if (total > 0) onProgress?.call(recibido / total);
      },
    );
  }

  static bool _esVersionNueva(String latest, String current) {
    List<int> parse(String v) =>
        v.split('.').map((x) => int.tryParse(x) ?? 0).toList();
    final l = parse(latest);
    final c = parse(current);
    for (int i = 0; i < 3; i++) {
      final lv = i < l.length ? l[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    return false;
  }
}
