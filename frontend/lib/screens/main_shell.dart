import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../core/theme/colors.dart';
import 'dashboard_screen.dart';
import 'inventario_screen.dart';
import 'movimientos_screen.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: kBackground,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 2,
          shadowColor: Colors.black26,
          automaticallyImplyLeading: false,
          title: const Text(
            "LAB MANAGER",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: kPrimary,
              fontSize: 20,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  auth.username ?? '',
                  style: const TextStyle(color: kTextMuted, fontSize: 14),
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                await auth.logout();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/');
                }
              },
              icon: const Icon(Icons.logout, size: 18, color: kTextMuted),
              label: const Text("Cerrar sesión", style: TextStyle(color: kTextMuted)),
            ),
            const SizedBox(width: 8),
          ],
          bottom: const TabBar(
            labelColor: kPrimary,
            unselectedLabelColor: kTextMuted,
            indicatorColor: kPrimary,
            indicatorWeight: 3,
            tabs: [
              Tab(icon: Icon(Icons.home_outlined), text: "Inicio"),
              Tab(icon: Icon(Icons.inventory_2_outlined), text: "Inventario"),
              Tab(icon: Icon(Icons.swap_horiz_outlined), text: "Movimientos"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            DashboardContent(),
            InventarioContent(),
            MovimientosContent(),
          ],
        ),
      ),
    );
  }
}
