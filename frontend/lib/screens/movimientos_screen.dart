import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/inventario_provider.dart';
import '../providers/auth_provider.dart';
import '../core/theme/colors.dart';

class MovimientosContent extends StatefulWidget {
  const MovimientosContent({super.key});

  @override
  State<MovimientosContent> createState() => _MovimientosContentState();
}

class _MovimientosContentState extends State<MovimientosContent> {
  bool _mostrarFormulario = false;
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _documentoController = TextEditingController();
  final _cantidadController = TextEditingController();
  String? _insumoSeleccionado;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      Provider.of<InventarioProvider>(context, listen: false).fetchInsumos(auth.token);
    });
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _documentoController.dispose();
    _cantidadController.dispose();
    super.dispose();
  }

  void _enviarSolicitud() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Préstamo registrado. Esperando aprobación."),
          backgroundColor: kSuccess,
        ),
      );
      setState(() {
        _mostrarFormulario = false;
        _nombreController.clear();
        _documentoController.clear();
        _cantidadController.clear();
        _insumoSeleccionado = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventario = Provider.of<InventarioProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Botón para mostrar/ocultar formulario — igual al "collapse" de Bootstrap
          ElevatedButton.icon(
            onPressed: () => setState(() => _mostrarFormulario = !_mostrarFormulario),
            icon: Icon(_mostrarFormulario ? Icons.remove : Icons.add, size: 18),
            label: Text(_mostrarFormulario ? "Ocultar formulario" : "Registrar Préstamo"),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),

          // Formulario colapsable
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _mostrarFormulario
                ? Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Registro de Préstamo",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _nombreController,
                                  decoration: const InputDecoration(
                                    labelText: "Nombre de quien recibe",
                                    prefixIcon: Icon(Icons.person, color: kPrimary),
                                    border: OutlineInputBorder(),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: kPrimary),
                                    ),
                                  ),
                                  validator: (v) => v!.isEmpty ? "Campo requerido" : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _documentoController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: "Identificación de quien recibe",
                                    prefixIcon: Icon(Icons.badge, color: kPrimary),
                                    border: OutlineInputBorder(),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: kPrimary),
                                    ),
                                  ),
                                  validator: (v) => v!.isEmpty ? "Campo requerido" : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  decoration: const InputDecoration(
                                    labelText: "Implemento",
                                    border: OutlineInputBorder(),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: kPrimary),
                                    ),
                                  ),
                                  value: _insumoSeleccionado,
                                  items: inventario.insumos.map((i) => DropdownMenuItem(
                                    value: i.id,
                                    child: Text(i.nombre),
                                  )).toList(),
                                  onChanged: (v) => setState(() => _insumoSeleccionado = v),
                                  validator: (v) => v == null ? "Selecciona un implemento" : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _cantidadController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: "Cantidad",
                                    prefixIcon: Icon(Icons.numbers, color: kPrimary),
                                    border: OutlineInputBorder(),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: kPrimary),
                                    ),
                                  ),
                                  validator: (v) => v!.isEmpty ? "Campo requerido" : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _enviarSolicitud,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                            ),
                            child: const Text("Registrar"),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 24),

          // Tabla de movimientos activos
          const Text(
            "Listado de Movimientos",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Table(
                border: TableBorder(
                  horizontalInside: const BorderSide(color: Color(0xFFDEE2E6)),
                ),
                columnWidths: const {
                  0: FlexColumnWidth(2.5),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(2),
                  3: FlexColumnWidth(2),
                  4: FlexColumnWidth(1.5),
                  5: FixedColumnWidth(130),
                },
                children: [
                  TableRow(
                    decoration: const BoxDecoration(color: kPrimary),
                    children: [
                      "Implemento", "Cantidad", "Fecha y hora",
                      "Nombre de quien recibe", "Entregado por", "Devolución"
                    ].map((h) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Text(h, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    )).toList(),
                  ),
                  // Fila de ejemplo mientras se conecta con el backend
                  TableRow(
                    children: [
                      _cell("Sin datos"),
                      _cell("—"),
                      _cell("—"),
                      _cell("—"),
                      _cell("—"),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: ElevatedButton(
                          onPressed: null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          child: const Text("Devolver", style: TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(text),
    );
  }
}
