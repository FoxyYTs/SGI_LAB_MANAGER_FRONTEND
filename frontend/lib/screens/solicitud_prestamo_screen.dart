import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/inventario_provider.dart';

class SolicitudPrestamoScreen extends StatefulWidget {
  const SolicitudPrestamoScreen({super.key});

  @override
  State<SolicitudPrestamoScreen> createState() => _SolicitudPrestamoScreenState();
}

class _SolicitudPrestamoScreenState extends State<SolicitudPrestamoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _documentoController = TextEditingController();
  String? _insumoSeleccionado;

  @override
  Widget build(BuildContext context) {
    final inventario = Provider.of<InventarioProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Solicitud de Préstamo"),
        backgroundColor: Colors.green[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Text(
                "Completa tus datos para solicitar el material",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: "Nombre Completo",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) => value!.isEmpty ? "Campo requerido" : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _documentoController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Cédula o Carnet",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
                validator: (value) => value!.isEmpty ? "Campo requerido" : null,
              ),
              const SizedBox(height: 15),
              
              // Selector de Insumos (Dropdown)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: "Insumo a solicitar",
                  border: OutlineInputBorder(),
                ),
                items: inventario.insumos.map((insumo) {
                  return DropdownMenuItem(
                    value: insumo.id,
                    child: Text(insumo.nombre),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _insumoSeleccionado = value),
                validator: (value) => value == null ? "Selecciona un insumo" : null,
              ),
              
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _enviarSolicitud,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.green[800],
                ),
                child: const Text("Enviar Solicitud", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _enviarSolicitud() {
    if (_formKey.currentState!.validate()) {
      // Aquí conectaremos con el POST de Django que creamos en 'operaciones'
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Solicitud enviada. Espera la aprobación del monitor.")),
      );
    }
  }
}