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
    Future.microtask(() =>
        Provider.of<InventarioProvider>(context, listen: false).fetchInsumos());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Inventario de Laboratorio")),
      body: Consumer<InventarioProvider>(
        builder: (context, provider, child) {
          if (provider.cargando) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.insumos.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text("No hay insumos registrados", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: provider.insumos.length,
            itemBuilder: (context, index) {
              final insumo = provider.insumos[index];
              final color = switch (insumo.semaforo) {
                "ROJO" => Colors.red,
                "AMARILLO" => Colors.orange,
                _ => Colors.green,
              };
              return ListTile(
                title: Text(insumo.nombre),
                subtitle: Text("${insumo.tipo} · Stock: ${insumo.stockActual}"),
                trailing: Icon(Icons.circle, color: color),
              );
            },
          );
        },
      ),
    );
  }
}
