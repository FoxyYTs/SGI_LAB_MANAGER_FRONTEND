import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../core/theme/colors.dart';
import '../core/permissions.dart';
import '../core/sync/sync_service.dart';
import '../services/monitor_reminder_service.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';
import 'about_screen.dart';
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
  final _configKey   = GlobalKey<ConfiguracionScreenState>();
  bool _reminderIniciado = false;
  bool _updateChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _actualizarReminder();
      _verificarActualizacion();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _actualizarReminder();
  }

  Future<void> _verificarActualizacion() async {
    if (_updateChecked || !mounted) return;
    _updateChecked = true;
    final info = await UpdateService.verificarActualizacion();
    if (info != null && mounted) {
      await mostrarDialogoActualizacion(context, info);
    }
  }

  void _actualizarReminder() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (auth.rol == 'MONITOR' && !_reminderIniciado) {
      _reminderIniciado = true;
      MonitorReminderService.iniciar(context, auth);
    } else if (auth.rol != 'MONITOR' && _reminderIniciado) {
      _reminderIniciado = false;
      MonitorReminderService.detener();
    }
  }

  @override
  void dispose() {
    MonitorReminderService.detener();
    super.dispose();
  }

  List<_TabDef> _tabs(AuthProvider auth) => [
    _TabDef(Icons.home_outlined,            'Inicio',        DashboardContent(onNavigateTo: (i) => setState(() => _idx = i))),
    if (auth.can(Perm.inventarioVer))
      const _TabDef(Icons.inventory_2_outlined,   'Inventario',    InventarioContent()),
    if (auth.can(Perm.prestamosVer))
      const _TabDef(Icons.swap_horiz_outlined,    'Movimientos',   MovimientosContent()),
    if (auth.can(Perm.bitacoraVer))
      const _TabDef(Icons.history_outlined,       'Bitácora',      BitacoraContent()),
    if (auth.can(Perm.academicoVer))
      const _TabDef(Icons.calendar_month_outlined,'Horario',       HorarioScreen()),
    if (auth.can(Perm.informesVer))
      const _TabDef(Icons.picture_as_pdf_outlined,'Informes',      InformesContent()),
    if (auth.can(Perm.configuracionGestion))
      _TabDef(Icons.settings_outlined, 'Configuración', ConfiguracionScreen(key: _configKey)),
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
    final size   = MediaQuery.of(context).size;
    final width  = size.width;
    // En landscape en teléfono (pantalla < 900px, ancho > alto) usamos layout mobile
    final isLandscapePhone = width < 900 && width > size.height;

    if (width < 700 || isLandscapePhone) return _buildMobile(context, auth, sync, tabs, idx);
    return _buildDesktop(context, auth, sync, tabs);
  }

  // ── Desktop: sidebar lateral + topbar (estilo Stitch) ───────────────────────

  static const _kSidebarBg     = Color(0xFFEBF5FE);
  static const _kSidebarBorder = Color(0xFFA1B4C5);
  static const _kOnSurface     = Color(0xFF223542);
  static const _kActiveItemBg  = Color(0xFFD4E8FF);

  Widget _buildDesktop(
    BuildContext context,
    AuthProvider auth,
    SyncService sync,
    List<_TabDef> tabs,
  ) {
    final idx = _idx.clamp(0, tabs.length - 1);
    return Scaffold(
      backgroundColor: kBackground,
      body: Row(children: [
        _buildSidebar(context, auth, sync, tabs, idx),
        Expanded(
          child: Column(children: [
            _buildDesktopTopBar(context, auth, sync),
            Expanded(
              child: IndexedStack(
                index: idx,
                children: tabs.map((t) => t.content).toList(),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildSidebar(BuildContext context, AuthProvider auth, SyncService sync,
      List<_TabDef> tabs, int idx) {
    return Container(
      width: 256,
      decoration: const BoxDecoration(
        color: _kSidebarBg,
        border: Border(right: BorderSide(color: _kSidebarBorder)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Cabecera
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 22, 20, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Laboratorio PCJIC',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _kOnSurface)),
            SizedBox(height: 2),
            Text('Rionegro, Antioquia',
                style: TextStyle(fontSize: 12, color: kTextMuted)),
          ]),
        ),
        const Divider(height: 1, color: _kSidebarBorder),
        const SizedBox(height: 6),

        // Banner offline
        if (!sync.online)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFB71C1C).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFB71C1C).withValues(alpha: 0.35)),
            ),
            child: const Row(children: [
              Icon(Icons.wifi_off, size: 13, color: Color(0xFFB71C1C)),
              SizedBox(width: 6),
              Text('Sin conexión',
                  style: TextStyle(fontSize: 11, color: Color(0xFFB71C1C), fontWeight: FontWeight.bold)),
            ]),
          ),

        // Nav items
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: tabs.asMap().entries.map((e) {
              final isActive = idx == e.key;
              if (e.value.label == 'Configuración') {
                return _buildSidebarConfig(context, e.key, idx, isActive);
              }
              return _buildSidebarItem(e.value.icon, e.value.label, e.key, isActive);
            }).toList(),
          ),
        ),

        // Sync pending
        if (sync.online && sync.pending > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: kSemaforoAmarillo.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                sync.syncing
                    ? const SizedBox(width: 12, height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: kWarning))
                    : const Icon(Icons.sync, size: 13, color: kWarning),
                const SizedBox(width: 6),
                Text('${sync.pending} pendiente${sync.pending > 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 11, color: kWarning, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),

        // Logout
        const Divider(height: 1, color: _kSidebarBorder),
        _buildSidebarLogout(context, auth),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _buildSidebarItem(IconData icon, String label, int itemIdx, bool isActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _idx = itemIdx),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? _kActiveItemBg : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Icon(icon, size: 20, color: isActive ? kPrimary : kTextMuted),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive ? kPrimary : _kOnSurface,
            )),
          ]),
        ),
      ),
    );
  }

  Widget _buildSidebarConfig(BuildContext context, int mainIdx, int currentIdx, bool isActive) {
    const subs = [
      ('Ubicaciones', Icons.place_outlined,     0),
      ('Unidades',    Icons.straighten_outlined, 1),
      ('Programas',   Icons.school_outlined,     2),
      ('Docentes',    Icons.person_pin_outlined,  3),
      ('Guías',       Icons.menu_book_outlined,   4),
      ('Áreas',       Icons.category_outlined,    5),
      ('Asignaturas', Icons.science_outlined,     6),
      ('Laboratorio', Icons.business_outlined,    7),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: EdgeInsets.zero,
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Icon(Icons.settings_outlined, size: 20,
              color: isActive ? kPrimary : kTextMuted),
          title: Text('Configuración', style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive ? kPrimary : _kOnSurface,
          )),
          backgroundColor: isActive ? _kActiveItemBg : Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
          initiallyExpanded: isActive,
          onExpansionChanged: (_) {
            if (!isActive) setState(() => _idx = mainIdx);
          },
          children: subs.map((s) => ListTile(
            contentPadding: const EdgeInsets.only(left: 52, right: 12),
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: Icon(s.$2, size: 16, color: kPrimary),
            title: Text(s.$1, style: const TextStyle(fontSize: 13)),
            onTap: () {
              setState(() => _idx = mainIdx);
              _configKey.currentState?.jumpToTab(s.$3);
            },
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildSidebarLogout(BuildContext context, AuthProvider auth) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          await auth.logout();
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/');
        },
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Icon(Icons.logout, size: 20, color: kTextMuted),
            SizedBox(width: 12),
            Text('Cerrar Sesión', style: TextStyle(fontSize: 14, color: kTextMuted)),
          ]),
        ),
      ),
    );
  }

  Widget _buildDesktopTopBar(BuildContext context, AuthProvider auth, SyncService sync) {
    final initial = (auth.username ?? 'U').substring(0, 1).toUpperCase();
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _kSidebarBorder)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Row(children: [
        const Text('SGI LAB MANAGER',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15,
                letterSpacing: 0.8, color: _kOnSurface)),
        const Spacer(),
        // Botón Acerca de
        IconButton(
          tooltip: 'Acerca de',
          icon: const Icon(Icons.info_outline, size: 20, color: kTextMuted),
          onPressed: () => showSgiAboutDialog(context),
        ),
        const SizedBox(width: 4),
        // Usuario + avatar
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/mi-perfil'),
          child: Row(children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(auth.username ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold,
                        fontSize: 13, color: _kOnSurface)),
                if (auth.rol != null)
                  Text(auth.rol!,
                      style: const TextStyle(fontSize: 10, color: kTextMuted)),
              ],
            ),
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 18,
              backgroundColor: kPrimary.withValues(alpha: 0.15),
              backgroundImage: auth.fotoUrl != null
                  ? NetworkImage(auth.fotoUrl!)
                  : null,
              child: auth.fotoUrl == null
                  ? Text(initial,
                      style: const TextStyle(color: kPrimary,
                          fontWeight: FontWeight.bold, fontSize: 14))
                  : null,
            ),
          ]),
        ),
      ]),
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
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white, size: 20),
            tooltip: 'Acerca de',
            onPressed: () => showSgiAboutDialog(context),
          ),
          _syncIndicator(sync),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _buildDrawer(context, auth, tabs, idx),
      body: Column(children: [
        // ── Banner offline persistente ────────────────────────────────
        if (!sync.online)
          Material(
            color: const Color(0xFFB71C1C),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(children: [
                const Icon(Icons.wifi_off, color: Colors.white, size: 15),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Sin conexión — mostrando datos guardados',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ]),
            ),
          )
        else if (sync.pending > 0)
          Material(
            color: const Color(0xFFF57F17),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(children: [
                sync.syncing
                    ? const SizedBox(
                        width: 13, height: 13,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.sync, color: Colors.white, size: 15),
                const SizedBox(width: 8),
                Text(
                  sync.syncing
                      ? 'Sincronizando ${sync.pending} operación(es)...'
                      : '${sync.pending} operación(es) pendiente(s) de sincronizar',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ]),
            ),
          ),
        // ── Contenido principal ──────────────────────────────────────
        Expanded(
          child: IndexedStack(
            index: idx,
            children: tabs.map((t) => t.content).toList(),
          ),
        ),
      ]),
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
                ...tabs.asMap().entries.map((e) {
                  if (e.value.label == 'Configuración') {
                    return _buildConfigExpansionTile(context, e.key, idx);
                  }
                  return ListTile(
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
                  );
                }),
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
                    if (!mounted) return;
                    Navigator.pushReplacementNamed(context, '/');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigExpansionTile(BuildContext context, int tabKey, int currentIdx) {
    final isSelected = currentIdx == tabKey;
    return ExpansionTile(
      leading: Icon(Icons.settings_outlined,
          color: isSelected ? kPrimary : kTextMuted, size: 22),
      title: Text(
        'Configuración',
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? kPrimary : Colors.black87,
        ),
      ),
      initiallyExpanded: isSelected,
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: EdgeInsets.zero,
      onExpansionChanged: (_) {
        if (!isSelected) setState(() => _idx = tabKey);
      },
      children: [
        _configSubItem(context, 'Ubicaciones', Icons.place_outlined,       0, tabKey),
        _configSubItem(context, 'Unidades',    Icons.straighten_outlined,  1, tabKey),
        _configSubItem(context, 'Programas',   Icons.school_outlined,      2, tabKey),
        _configSubItem(context, 'Docentes',    Icons.person_pin_outlined,  3, tabKey),
        _configSubItem(context, 'Guías',       Icons.menu_book_outlined,   4, tabKey),
        _configSubItem(context, 'Áreas',       Icons.category_outlined,    5, tabKey),
        _configSubItem(context, 'Asignaturas', Icons.science_outlined,     6, tabKey),
        _configSubItem(context, 'Laboratorio', Icons.business_outlined,    7, tabKey),
      ],
    );
  }

  Widget _configSubItem(
      BuildContext context, String label, IconData icon, int subIdx, int mainTabKey) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 56, right: 16),
      leading: Icon(icon, color: kPrimary, size: 18),
      title: Text(label, style: const TextStyle(fontSize: 13)),
      dense: true,
      visualDensity: VisualDensity.compact,
      onTap: () {
        setState(() => _idx = mainTabKey);
        _configKey.currentState?.jumpToTab(subIdx);
        Navigator.pop(context);
      },
    );
  }
}
