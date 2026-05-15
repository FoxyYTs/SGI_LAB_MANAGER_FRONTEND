import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/inventario_provider.dart';

class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  @override
  void initState() {
    super.initState();
    // Cargamos los datos al entrar
    Future.microtask(() =>
        Provider.of<InventarioProvider>(context, listen: false).fetchInsumos());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Inventario de Laboratorio")),
      body: Consumer<InventarioProvider>(
        builder: (context, provider, child) {
          if (provider.insumos.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.builder(
            itemCount: provider.insumos.length,
            itemBuilder: (context, index) {
              final insumo = provider.insumos[index];
              return ListTile(
                title: Text(insumo.nombre),
                subtitle: Text("Stock: ${insumo.stockActual}"),
                trailing: Icon(Icons.circle, 
                  color: insumo.semaforo == "ROJO" ? Colors.red : Colors.green
                ),
              );
            },
          );
        },
      ),
    );
  }
}