import 'package:flutter/material.dart';
import '../core/theme/colors.dart';
import '../services/update_service.dart';

/// Muestra el diálogo de actualización disponible.
/// Retorna true si el usuario aceptó instalar.
Future<void> mostrarDialogoActualizacion(
  BuildContext context,
  UpdateInfo info,
) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UpdateDialog(info: info),
  );
}

class _UpdateDialog extends StatefulWidget {
  final UpdateInfo info;
  const _UpdateDialog({required this.info});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  _Step _paso = _Step.confirmar;
  double _progreso = 0;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          const Icon(Icons.system_update_outlined, color: kPrimary),
          const SizedBox(width: 10),
          const Text('Actualización disponible'),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: _buildContent(),
      ),
      actions: _buildActions(),
    );
  }

  Widget _buildContent() {
    switch (_paso) {
      case _Step.confirmar:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'La versión ${widget.info.version} ya está disponible.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Versión actual: $kAppVersion',
              style: const TextStyle(fontSize: 12, color: kTextMuted),
            ),
            const SizedBox(height: 12),
            const Text(
              'La aplicación se descargará, reemplazará y reiniciará automáticamente.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        );

      case _Step.descargando:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Descargando actualización…', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _progreso > 0 ? _progreso : null,
              backgroundColor: const Color(0xFFE9ECEF),
              color: kPrimary,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 8),
            Text(
              _progreso > 0 ? '${(_progreso * 100).toStringAsFixed(0)} %' : 'Conectando…',
              style: const TextStyle(fontSize: 12, color: kTextMuted),
            ),
          ],
        );

      case _Step.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: kDanger, size: 40),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Error desconocido al descargar la actualización.',
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
          ],
        );
    }
  }

  List<Widget> _buildActions() {
    switch (_paso) {
      case _Step.confirmar:
        return [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Más tarde', style: TextStyle(color: kTextMuted)),
          ),
          ElevatedButton.icon(
            onPressed: _iniciarDescarga,
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Actualizar ahora'),
          ),
        ];
      case _Step.descargando:
        return [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              'No cierres la aplicación…',
              style: TextStyle(fontSize: 12, color: kTextMuted),
            ),
          ),
        ];
      case _Step.error:
        return [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: _iniciarDescarga,
            child: const Text('Reintentar'),
          ),
        ];
    }
  }

  Future<void> _iniciarDescarga() async {
    setState(() {
      _paso = _Step.descargando;
      _progreso = 0;
      _error = null;
    });
    try {
      await UpdateService.descargarEInstalar(
        widget.info,
        onProgress: (p) => setState(() => _progreso = p),
      );
      // descargarEInstalar llama exit(0) — no llega aquí
    } catch (e) {
      setState(() {
        _paso = _Step.error;
        _error = e.toString();
      });
    }
  }
}

enum _Step { confirmar, descargando, error }
