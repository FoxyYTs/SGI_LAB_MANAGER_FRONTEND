import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../core/theme/colors.dart';
import '../core/permissions.dart';
import 'dashboard_screen.dart';
import 'inventario_screen.dart';
import 'movimientos_screen.dart';
import 'configuracion_screen.dart';

class _TabDef {
  final IconData icon;
  final String   label;
  final Widget   content;
  const _TabDef(this.icon, this.label, this.content);
}

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  List<_TabDef> _tabs(AuthProvider auth) => [
    const _TabDef(Icons.home_outlined,       'Inicio',         DashboardContent()),
    if (auth.can(Perm.inventarioVer))
      const _TabDef(Icons.inventory_2_outlined, 'Inventario',  InventarioContent()),
    if (auth.can(Perm.prestamosVer))
      const _TabDef(Icons.swap_horiz_outlined,  'Movimientos', MovimientosContent()),
    if (auth.can(Perm.configuracionGestion))
      const _TabDef(Icons.settings_outlined,    'Configuración', ConfiguracionScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final tabs = _tabs(auth);

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: kBackground,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 2,
          shadowColor: Colors.black26,
          automaticallyImplyLeading: false,
          title: const Text(
            'LAB MANAGER',
            style: TextStyle(fontWeight: FontWeight.bold, color: kPrimary, fontSize: 20),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(auth.username ?? '',
                    style: const TextStyle(color: kTextMuted, fontSize: 14)),
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
              label: const Text('Cerrar sesión', style: TextStyle(color: kTextMuted)),
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            labelColor: kPrimary,
            unselectedLabelColor: kTextMuted,
            indicatorColor: kPrimary,
            indicatorWeight: 3,
            tabs: tabs.map((t) => Tab(icon: Icon(t.icon), text: t.label)).toList(),
          ),
        ),
        body: TabBarView(
          children: tabs.map((t) => t.content).toList(),
        ),
      ),
    );
  }
}
