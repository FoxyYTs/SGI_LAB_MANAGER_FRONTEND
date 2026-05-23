import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api/api_client.dart';
import '../core/theme/colors.dart';
import '../providers/auth_provider.dart';
import '../widgets/qr_generator_dialog.dart';

class DashboardContent extends StatefulWidget {
  const DashboardContent({super.key});
  @override State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  Map<String, dynamic>? _data;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_cargar);
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final auth = context.read<AuthProvider>();
    final dio  = ApiClient.instance.authenticatedDio(auth.token);
    try {
      final r = await dio.get('academico/dashboard/');
      setState(() { _data = Map<String, dynamic>.from(r.data); _cargando = false; });
    } catch (_) {
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Jumbotron ──────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hola, ${auth.username ?? 'bienvenido'}',
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w300),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'SGI LAB MANAGER — Laboratorio Integrado',
                        style: TextStyle(fontSize: 14, color: kTextMuted),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const QrGeneratorDialog(),
                  ),
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Códigos QR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Tarjetas de estadísticas ────────────────────────────────────
          if (_cargando)
            const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: kPrimary),
            ))
          else if (_data != null) ...[
            Row(children: [
              _statCard(
                icon: Icons.inventory_2_outlined,
                label: 'Total insumos',
                value: '${_data!['total_insumos'] ?? 0}',
                color: kPrimary,
              ),
              const SizedBox(width: 14),
              _statCard(
                icon: Icons.warning_amber_rounded,
                label: 'Stock crítico',
                value: '${_data!['stock_critico'] ?? 0}',
                color: kSemaforoRojo,
              ),
              const SizedBox(width: 14),
              _statCard(
                icon: Icons.info_outline,
                label: 'Stock bajo',
                value: '${_data!['stock_bajo'] ?? 0}',
                color: kSemaforoAmarillo,
              ),
              const SizedBox(width: 14),
              _statCard(
                icon: Icons.swap_horiz_outlined,
                label: 'Préstamos activos',
                value: '${_data!['prestamos_activos'] ?? 0}',
                color: kSuccess,
              ),
              const SizedBox(width: 14),
              _statCard(
                icon: Icons.hourglass_top_outlined,
                label: 'Por aprobar',
                value: '${_data!['prestamos_pendientes'] ?? 0}',
                color: kWarning,
              ),
            ]),

            const SizedBox(height: 24),

            // ── Insumos en stock crítico ──────────────────────────────────
            if ((_data!['lista_criticos'] as List?)?.isNotEmpty == true) ...[
              Row(children: [
                const Icon(Icons.warning_amber_rounded, color: kSemaforoRojo, size: 20),
                const SizedBox(width: 8),
                const Text('Insumos en stock crítico',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _cargar,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Actualizar'),
                ),
              ]),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(3),
                      1: FixedColumnWidth(110),
                      2: FixedColumnWidth(110),
                    },
                    border: const TableBorder(
                        horizontalInside: BorderSide(color: Color(0xFFDEE2E6))),
                    children: [
                      _headerRow(['Insumo', 'Stock actual', 'Mínimo']),
                      ...(_data!['lista_criticos'] as List).asMap().entries.map((e) {
                        final idx  = e.key;
                        final ins  = e.value as Map<String, dynamic>;
                        final stock    = double.tryParse(ins['stock_actual'].toString()) ?? 0;
                        final stockMin = double.tryParse(ins['stock_minimo'].toString()) ?? 0;
                        return TableRow(
                          decoration: BoxDecoration(
                              color: idx.isOdd ? const Color(0xFFF8F9FA) : Colors.white),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(children: [
                                Container(width: 8, height: 8,
                                    decoration: const BoxDecoration(
                                        color: kSemaforoRojo, shape: BoxShape.circle)),
                                const SizedBox(width: 8),
                                Expanded(child: Text(ins['nombre_insumo']?.toString() ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.w500))),
                              ]),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Text(stock.toStringAsFixed(1),
                                  style: const TextStyle(color: kSemaforoRojo, fontWeight: FontWeight.bold)),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Text(stockMin.toStringAsFixed(1),
                                  style: const TextStyle(color: kTextMuted)),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ] else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check_circle_outline, size: 48, color: kSuccess),
                    const SizedBox(height: 10),
                    const Text('Todo el inventario tiene stock suficiente',
                        style: TextStyle(color: kTextMuted)),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _cargar,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Actualizar'),
                    ),
                  ]),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: kTextMuted, fontSize: 11)),
      ]),
    ),
  );

  TableRow _headerRow(List<String> cols) => TableRow(
    decoration: const BoxDecoration(color: kPrimary),
    children: cols.map((h) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(h,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
    )).toList(),
  );
}
