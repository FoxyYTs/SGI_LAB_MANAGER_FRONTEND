import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Obtenemos el ancho de la pantalla para decidir el diseño
    double screenWidth = MediaQuery.of(context).size.width;
    bool isDesktop = screenWidth > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text("SGI LAB - Panel Principal"),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        // Si es escritorio, ocultamos el botón de 3 rayas porque usaremos menú lateral fijo
        leading: isDesktop ? const Icon(Icons.biotech) : null,
      ),
      // Menú lateral (el de las 3 rayas)
      drawer: isDesktop ? null : _buildDrawer(context), 
      body: Row(
        children: [
          if (isDesktop) _buildSideMenu(context), // Menú fijo para PC
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("Noticias del Laboratorio"),
                  _buildNewsCard("Mantenimiento de Servidores", "Este sábado los servidores de renderizado estarán fuera de servicio."),
                  const SizedBox(height: 20),
                  _buildSectionTitle("Horarios de Monitores"),
                  _buildScheduleTable(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget para el menú lateral (Drawer/3 rayas)
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: _buildMenuContent(context),
    );
  }

  // Widget para el menú fijo en Escritorio
  Widget _buildSideMenu(BuildContext context) {
    return Container(
      width: 250,
      color: Colors.grey[200],
      child: _buildMenuContent(context),
    );
  }

  Widget _buildMenuContent(BuildContext context) {
    return Column(
      children: [
        const DrawerHeader(
          decoration: BoxDecoration(color: Colors.green),
          child: Center(child: Text("Menú SGI", style: TextStyle(color: Colors.white, fontSize: 20))),
        ),
        ListTile(
          leading: const Icon(Icons.inventory),
          title: const Text("Inventario"),
          onTap: () => Navigator.pushNamed(context, '/inventario'),
        ),
        ListTile(
          leading: const Icon(Icons.assignment),
          title: const Text("Préstamos"),
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold));
  }

  Widget _buildNewsCard(String title, String content) {
    return Card(
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(content),
        leading: const Icon(Icons.notifications_active, color: Colors.orange),
      ),
    );
  }

  Widget _buildScheduleTable() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Table(
          border: TableBorder.all(color: Colors.black12),
          children: const [
            TableRow(children: [
              Padding(padding: EdgeInsets.all(8), child: Text("Día", style: TextStyle(fontWeight: FontWeight.bold))),
              Padding(padding: EdgeInsets.all(8), child: Text("Monitor", style: TextStyle(fontWeight: FontWeight.bold))),
            ]),
            TableRow(children: [
              Padding(padding: EdgeInsets.all(8), child: Text("Lunes")),
              Padding(padding: EdgeInsets.all(8), child: Text("Juan Perez")),
            ]),
          ],
        ),
      ),
    );
  }
}