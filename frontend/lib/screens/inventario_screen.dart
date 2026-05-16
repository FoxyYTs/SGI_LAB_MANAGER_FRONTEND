import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/inventario_provider.dart';
import '../models/insumo_model.dart';
import '../core/theme/colors.dart';

class InventarioContent extends StatefulWidget {
  const InventarioContent({super.key});

  @override
  State<InventarioContent> createState() => _InventarioContentState();
}

class _InventarioContentState extends State<InventarioContent> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        Provider.of<InventarioProvider>(context, listen: false).fetchInsumos());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _semaforoColor(String semaforo) => switch (semaforo) {
    "ROJO" => kSemaforoRojo,
    "AMARILLO" => kSemaforoAmarillo,
    _ => kSemaforoVerde,
  };

  @override
  Widget build(BuildContext context) {
    return Consumer<InventarioProvider>(
      builder: (context, provider, _) {
        if (provider.cargando) {
          return const Center(child: CircularProgressIndicator(color: kPrimary));
        }

        final List<Insumo> filtrados = provider.insumos.where((i) =>
          i.nombre.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          i.tipo.toLowerCase().contains(_searchQuery.toLowerCase())
        ).toList();

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado + buscador
              Row(
                children: [
                  const Text(
                    "Implementos",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: "Buscar insumo...",
                        prefixIcon: const Icon(Icons.search, color: kPrimary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: kPrimary),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => provider.fetchInsumos(),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text("Actualizar"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tabla
              Expanded(
                child: filtrados.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 64, color: kTextMuted),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isEmpty
                                  ? "No hay insumos registrados"
                                  : "Sin resultados para \"$_searchQuery\"",
                              style: const TextStyle(color: kTextMuted),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SingleChildScrollView(
                            child: Table(
                              columnWidths: const {
                                0: FlexColumnWidth(3),
                                1: FlexColumnWidth(1.5),
                                2: FlexColumnWidth(1.5),
                                3: FlexColumnWidth(1.2),
                                4: FlexColumnWidth(1.2),
                                5: FixedColumnWidth(80),
                              },
                              border: TableBorder(
                                horizontalInside: const BorderSide(color: Color(0xFFDEE2E6)),
                              ),
                              children: [
                                // Encabezado azul
                                TableRow(
                                  decoration: const BoxDecoration(color: kPrimary),
                                  children: ["Nombre", "Tipo", "Ubicación", "Stock", "Stock Mín.", "Estado"]
                                      .map((h) => Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                            child: Text(
                                              h,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ))
                                      .toList(),
                                ),
                                // Filas de datos
                                ...filtrados.asMap().entries.map((entry) {
                                  final i = entry.key;
                                  final insumo = entry.value;
                                  final rowColor = i.isOdd ? const Color(0xFFF8F9FA) : Colors.white;
                                  return TableRow(
                                    decoration: BoxDecoration(color: rowColor),
                                    children: [
                                      _cell(insumo.nombre, bold: true),
                                      _cell(insumo.tipo),
                                      _cell(insumo.ubicacion),
                                      _cell(insumo.stockActual.toStringAsFixed(0)),
                                      _cell(insumo.stockMinimo.toStringAsFixed(0)),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        child: Center(
                                          child: Container(
                                            width: 16,
                                            height: 16,
                                            decoration: BoxDecoration(
                                              color: _semaforoColor(insumo.semaforo),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),

              // Leyenda semáforo
              if (filtrados.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    _leyenda(kSemaforoVerde, "En stock"),
                    const SizedBox(width: 16),
                    _leyenda(kSemaforoAmarillo, "Stock bajo"),
                    const SizedBox(width: 16),
                    _leyenda(kSemaforoRojo, "Crítico"),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _cell(String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        style: TextStyle(fontWeight: bold ? FontWeight.w600 : FontWeight.normal),
      ),
    );
  }

  Widget _leyenda(Color color, String label) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: kTextMuted)),
      ],
    );
  }
}
