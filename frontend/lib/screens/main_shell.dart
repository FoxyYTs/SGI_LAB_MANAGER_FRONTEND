import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../core/theme/colors.dart';
import '../core/permissions.dart';
import '../core/sync/sync_service.dart';
import 'dashboard_screen.dart';
import 'inventario_screen.dart';
import 'movimientos_screen.dart';
import 'bitacora_screen.dart';
import 'horario_screen.dart';
import 'configuracion_screen.dart';
import 'informes_screen.dart';

class _TabDef {
  final IconData icon;
  final String   label;
  final Widget   content;
  const _TabDef(this.icon, this.label, this.content);
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _idx = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  List<_TabDef> _tabs(AuthProvider auth) => [
    const _TabDef(Icons.home_outlined,            'Inicio',        DashboardContent()),
    if (auth.can(Perm.inventarioVer))
      const _TabDef(Icons.inventory_2_outlined,   'Inventario',    InventarioContent()),
    if (auth.can(Perm.prestamosVer))
      const _TabDef(Icons.swap_horiz_outlined,    'Movimientos',   MovimientosContent()),
    if (auth.can(Perm.bitacoraVer))
      const _TabDef(Icons.history_outlined,       'Bitácora',      BitacoraContent()),
    if (auth.can(Perm.academicoVer))
      const _TabDef(Icons.calendar_month_outlined,'Horario',       HorarioScreen()),
    if (auth.can(Perm.bitacoraVer))
      const _TabDef(Icons.picture_as_pdf_outlined,'Informes',      InformesContent()),
    if (auth.can(Perm.configuracionGestion))
      const _TabDef(Icons.settings_outlined,      'Configuración', ConfiguracionScreen()),
  ];

  Widget _syncIndicator(SyncService sync) {
    if (!sync.online) {
      return const Chip(
        label: Text('Sin red', style: TextStyle(color: Colors.white, fontSize: 11)),
        backgroundColor: kDanger,
        padding: EdgeInsets.zero,
      );
    }
    if (sync.pending > 0) {
      return Chip(
        avatar: sync.syncing
            ? const SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.sync, size: 14, color: Colors.white),
        label: Text(
          '${sync.pending} pendiente${sync.pending > 1 ? 's' : ''}',
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
        backgroundColor: kSemaforoAmarillo,
        padding: EdgeInsets.zero,
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final auth  = context.watch<AuthProvider>();
    final sync  = context.watch<SyncService>();
    final tabs  = _tabs(auth);
    final idx   = _idx.clamp(0, tabs.length - 1);
    final width = MediaQuery.of(context).size.width;

    if (width < 700) return _buildMobile(context, auth, sync, tabs, idx);
    return _buildDesktop(context, auth, sync, tabs);
  }

  // ── Desktop: compact horizontal tab bar ─────────────────────────────────────

  Widget _buildDesktop(
    BuildContext context,
    AuthProvider auth,
    SyncService sync,
    List<_TabDef> tabs,
  ) {
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: kBackground,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 2,
          shadowColor: Colors.black26,
          toolbarHeight: 46,
          automaticallyImplyLeading: false,
          title: const Text(
            'LAB MANAGER',
            style: TextStyle(fontWeight: FontWeight.bold, color: kPrimary, fontSize: 17),
          ),
          actions: [
            _syncIndicator(sync),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  auth.username ?? '',
                  style: const TextStyle(color: kTextMuted, fontSize: 13),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Mi Perfil',
              icon: const Icon(Icons.account_circle_outlined,
                  size: 20, color: kTextMuted),
              onPressed: () => Navigator.pushNamed(context, '/mi-perfil'),
            ),
            TextButton.icon(
              onPressed: () async {
                await auth.logout();
                if (context.mounted) Navigator.pushReplacementNamed(context, '/');
              },
              icon: const Icon(Icons.logout, size: 15, color: kTextMuted),
              label: const Text('Salir', style: TextStyle(color: kTextMuted, fontSize: 13)),
            ),
            const SizedBox(width: 4),
          ],
          bottom: TabBar(
            labelColor: kPrimary,
            unselectedLabelColor: kTextMuted,
            indicatorColor: kPrimary,
            indicatorWeight: 2,
            labelPadding: const EdgeInsets.symmetric(horizontal: 14),
            tabs: tabs.map((t) => Tab(
              height: 36,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(t.icon, size: 15),
                  const SizedBox(width: 5),
                  Text(t.label,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            )).toList(),
          ),
        ),
        body: TabBarView(
          children: tabs.map((t) => t.content).toList(),
        ),
      ),
    );
  }

  // ── Mobile: drawer navigation ────────────────────────────────────────────────

  Widget _buildMobile(
    BuildContext context,
    AuthProvider auth,
    SyncService sync,
    List<_TabDef> tabs,
    int idx,
  ) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(
          tabs[idx].label,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          _syncIndicator(sync),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _buildDrawer(context, auth, tabs, idx),
      body: IndexedStack(
        index: idx,
        children: tabs.map((t) => t.content).toList(),
      ),
    );
  }

  Widget _buildDrawer(
    BuildContext context,
    AuthProvider auth,
    List<_TabDef> tabs,
    int idx,
  ) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: kPrimary),
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person, color: Colors.white, size: 24),
                  ),
                  const Spacer(),
                  Text(
                    auth.username ?? '',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'SGI LAB MANAGER',
                    style: TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ...tabs.asMap().entries.map((e) => ListTile(
                  leading: Icon(
                    e.value.icon,
                    color: idx == e.key ? kPrimary : kTextMuted,
                    size: 22,
                  ),
                  title: Text(
                    e.value.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          idx == e.key ? FontWeight.bold : FontWeight.normal,
                      color: idx == e.key ? kPrimary : Colors.black87,
                    ),
                  ),
                  selected: idx == e.key,
                  selectedTileColor: kPrimary.withValues(alpha: 0.08),
                  onTap: () {
                    setState(() => _idx = e.key);
                    Navigator.pop(context);
                  },
                )),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.account_circle_outlined,
                      color: kPrimary, size: 22),
                  title: const Text('Mi Perfil',
                      style: TextStyle(fontSize: 14, color: kPrimary)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/mi-perfil');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: kTextMuted, size: 22),
                  title: const Text('Cerrar sesión',
                      style: TextStyle(fontSize: 14, color: Colors.black54)),
                  onTap: () async {
                    Navigator.pop(context);
                    await auth.logout();
                    if (mounted) Navigator.pushReplacementNamed(context, '/');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
