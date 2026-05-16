import 'package:flutter/material.dart';
import '../core/theme/colors.dart';
import '../widgets/qr_generator_dialog.dart';

class DashboardContent extends StatelessWidget {
  const DashboardContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Jumbotron — estilo Bootstrap
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Bienvenido al SGI LAB MANAGER",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w300),
                ),
                const Divider(height: 32, thickness: 1),
                const Text(
                  "Sistema de Gestión de Inventario para el Laboratorio Integrado.",
                  style: TextStyle(fontSize: 16, color: kTextMuted),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => const QrGeneratorDialog(),
                        );
                      },
                      icon: const Icon(Icons.qr_code_2),
                      label: const Text("Generar QR de Préstamo"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Tarjetas de resumen
          Row(
            children: [
              _buildStatCard(
                icon: Icons.inventory_2,
                label: "Inventario",
                sublabel: "Gestiona los insumos",
                color: kPrimary,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                icon: Icons.swap_horiz,
                label: "Movimientos",
                sublabel: "Préstamos y devoluciones",
                color: kSuccess,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                icon: Icons.warning_amber_rounded,
                label: "Alertas de Stock",
                sublabel: "Insumos bajo mínimo",
                color: kDanger,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Sección noticias
          _buildSectionTitle("Noticias del Laboratorio"),
          const SizedBox(height: 12),
          _buildNewsCard(
            "Mantenimiento de Servidores",
            "Este sábado los servidores de renderizado estarán fuera de servicio.",
            Icons.notifications_active,
            kWarning,
          ),

          const SizedBox(height: 24),

          // Horarios de monitores
          _buildSectionTitle("Horarios de Monitores"),
          const SizedBox(height: 12),
          _buildScheduleTable(),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(sublabel, style: const TextStyle(color: kTextMuted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildNewsCard(String title, String content, IconData icon, Color iconColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(content),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Widget _buildScheduleTable() {
    final rows = [
      ["Lunes", "Juan Pérez"],
      ["Martes", "Ana Gómez"],
      ["Miércoles", "Carlos Ríos"],
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Table(
          border: TableBorder.symmetric(
            inside: const BorderSide(color: Color(0xFFDEE2E6)),
          ),
          children: [
            TableRow(
              decoration: const BoxDecoration(color: kPrimary),
              children: ["Día", "Monitor"].map((h) => Padding(
                padding: const EdgeInsets.all(12),
                child: Text(h, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )).toList(),
            ),
            ...rows.map((r) => TableRow(
              children: r.map((cell) => Padding(
                padding: const EdgeInsets.all(12),
                child: Text(cell),
              )).toList(),
            )),
          ],
        ),
      ),
    );
  }
}
