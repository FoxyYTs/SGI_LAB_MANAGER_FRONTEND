import 'package:flutter/material.dart';
import '../core/theme/colors.dart';

class ActualizacionRequeridaScreen extends StatelessWidget {
  const ActualizacionRequeridaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: kDanger.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.system_update_outlined,
                      size: 64, color: kDanger),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Actualización requerida',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tu versión de la aplicación está desactualizada y ya no es compatible con el servidor.\n\n'
                  'Por favor instala la versión más reciente para continuar usando SGI LAB MANAGER.',
                  style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: null, // Habilitar cuando la app esté en tienda
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Descargar actualización',
                        style: TextStyle(fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Contacta al administrador si el problema persiste.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
