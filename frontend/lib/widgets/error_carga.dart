import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../core/theme/colors.dart';

/// Mensaje legible para un fallo al cargar datos de un formulario público.
/// [que] describe lo que se intentaba cargar ("la lista de implementos").
String mensajeErrorCarga(Object e, String que) {
  if (e is DioException) {
    final code = e.response?.statusCode;
    if (code == 429) {
      return 'Demasiadas consultas desde esta red. Espera unos minutos e intenta de nuevo.';
    }
    if (code != null) return 'No se pudo cargar $que (error $code).';
    return 'No se pudo cargar $que. Revisa tu conexión a internet.';
  }
  return 'No se pudo cargar $que.';
}

/// Aviso de error de carga con botón "Reintentar" — los formularios QR
/// públicos antes tragaban el error en silencio y el usuario veía la
/// pantalla vacía o un botón que no hacía nada.
class ErrorCargaReintentar extends StatelessWidget {
  final String mensaje;
  final VoidCallback onReintentar;
  const ErrorCargaReintentar({
    super.key,
    required this.mensaje,
    required this.onReintentar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: kDanger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kDanger.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: kDanger, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(mensaje,
              style: const TextStyle(color: kDanger, fontSize: 13)),
        ),
        TextButton.icon(
          onPressed: onReintentar,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Reintentar'),
        ),
      ]),
    );
  }
}
