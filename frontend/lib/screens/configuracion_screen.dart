import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api/api_client.dart';
import '../core/theme/colors.dart';
import '../core/permissions.dart';
import '../providers/auth_provider.dart';

// ─────────────────────────────────────────
// Shell de Configuración
// ─────────────────────────────────────────
class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => ConfiguracionScreenState();
}

class ConfiguracionScreenState extends State<ConfiguracionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  void jumpToTab(int index) {
    if (!mounted) return;
    _tab.animateTo(index.clamp(0, 7));
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 8, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        title: const Text('Configuración',
            style: TextStyle(color: kPrimary, fontWeight: FontWeight.bold)),
        elevation: 1,
        actions: [
          if (auth.can(Perm.configuracionRoles))
            TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/permisos'),
              icon: const Icon(Icons.manage_accounts, color: kPrimary),
              label: const Text('Permisos de roles',
                  style: TextStyle(color: kPrimary)),
            ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: kPrimary,
          unselectedLabelColor: kTextMuted,
          indicatorColor: kPrimary,
          tabs: const [
            Tab(icon: Icon(Icons.place_outlined),        text: 'Ubicaciones'),
            Tab(icon: Icon(Icons.straighten_outlined),   text: 'Unidades'),
            Tab(icon: Icon(Icons.school_outlined),        text: 'Programas'),
            Tab(icon: Icon(Icons.person_pin_outlined),    text: 'Docentes'),
            Tab(icon: Icon(Icons.menu_book_outlined),     text: 'Guías'),
            Tab(icon: Icon(Icons.category_outlined),      text: 'Áreas'),
            Tab(icon: Icon(Icons.science_outlined),       text: 'Asignaturas'),
            Tab(icon: Icon(Icons.business_outlined),      text: 'Laboratorio'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _UbicacionesTab(),
          _UnidadesTab(),
          _ProgramasTab(),
          _DocentesTab(),
          _GuiasTab(),
          _AreasTab(),
          _AsignaturasTab(),
          const _LabConfigTab(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Widget reutilizable de lista CRUD
// ─────────────────────────────────────────
class _CrudList extends StatefulWidget {
  final String                          endpoint;
  final String                          titulo;
  final Widget Function(Map, VoidCallback onEdit, VoidCallback onDelete) itemBuilder;
  final Future<void> Function(Map<String, dynamic>? item, BuildContext ctx,
      Future<void> Function(Map<String, dynamic>) onSave) formDialog;

  const _CrudList({
    required this.endpoint,
    required this.titulo,
    required this.itemBuilder,
    required this.formDialog,
  });

  @override
  State<_CrudList> createState() => _CrudListState();
}

class _CrudListState extends State<_CrudList> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      final dio  = ApiClient.instance.authenticatedDio(auth.token);
      final resp = await dio.get(widget.endpoint);
      if (!mounted) return;
      setState(() {
        final d  = resp.data;
        _items   = List<Map<String, dynamic>>.from(d is List ? d : (d['results'] ?? []));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save(Map<String, dynamic> data, {String? id}) async {
    final auth = context.read<AuthProvider>();
    final dio  = ApiClient.instance.authenticatedDio(auth.token);
    if (id != null) {
      await dio.patch('${widget.endpoint}$id/', data: data);
    } else {
      await dio.post(widget.endpoint, data: data);
    }
    await _fetch();
  }

  Future<void> _delete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: const Text('¿Estás seguro de que quieres eliminar este elemento?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar', style: TextStyle(color: kDanger))),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final dio  = ApiClient.instance.authenticatedDio(auth.token);
    await dio.delete('${widget.endpoint}$id/');
    await _fetch();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: kPrimary));

    return Scaffold(
      backgroundColor: kBackground,
      body: _items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.inbox_outlined, size: 56, color: kTextMuted),
                  const SizedBox(height: 8),
                  Text('Sin ${widget.titulo.toLowerCase()} registradas',
                      style: const TextStyle(color: kTextMuted)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (ctx, i) {
                final item = _items[i];
                final id   = item['id'].toString();
                return widget.itemBuilder(
                  item,
                  () => widget.formDialog(item, context,
                      (data) => _save(data, id: id)),
                  () => _delete(id),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kPrimary,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => widget.formDialog(null, context, (data) => _save(data)),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Tab: Ubicaciones
// ─────────────────────────────────────────
class _UbicacionesTab extends StatelessWidget {
  const _UbicacionesTab();

  Future<void> _dialog(Map? item, BuildContext ctx,
      Future<void> Function(Map<String, dynamic>) onSave) async {
    final codigoCtrl = TextEditingController(text: item?['codigo_ubicacion'] ?? '');
    final descCtrl   = TextEditingController(text: item?['descripcion_ubicacion'] ?? '');
    await showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(item == null ? 'Nueva ubicación' : 'Editar ubicación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codigoCtrl,
              decoration: const InputDecoration(
                labelText: 'Código *',
                hintText: 'Ej: LAB-01, ESTANTE-A',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await onSave({
                'codigo_ubicacion':      codigoCtrl.text.trim(),
                'descripcion_ubicacion': descCtrl.text.trim(),
              });
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    codigoCtrl.dispose();
    descCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _CrudList(
      endpoint: 'inventario/ubicaciones/',
      titulo: 'Ubicaciones',
      formDialog: _dialog,
      itemBuilder: (item, onEdit, onDelete) => Card(
        child: ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          leading: const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0x1A007BFF),
            child: Icon(Icons.place_outlined, color: kPrimary, size: 18),
          ),
          title: Text(item['codigo_ubicacion'],
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: item['descripcion_ubicacion'] != null &&
                  (item['descripcion_ubicacion'] as String).isNotEmpty
              ? Text(item['descripcion_ubicacion'])
              : null,
          trailing: _AccionesRow(onEdit: onEdit, onDelete: onDelete),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Tab: Unidades de Medida
// ─────────────────────────────────────────
class _UnidadesTab extends StatelessWidget {
  const _UnidadesTab();

  Future<void> _dialog(Map? item, BuildContext ctx,
      Future<void> Function(Map<String, dynamic>) onSave) async {
    final ctrl = TextEditingController(text: item?['nombre_unidad'] ?? '');
    await showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(item == null ? 'Nueva unidad de medida' : 'Editar unidad'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Nombre *',
            hintText: 'Ej: mL, g, unidad, L',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (_) {},
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await onSave({'nombre_unidad': ctrl.text.trim()});
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _CrudList(
      endpoint: 'inventario/unidades/',
      titulo: 'Unidades',
      formDialog: _dialog,
      itemBuilder: (item, onEdit, onDelete) => Card(
        child: ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          leading: const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0x1A007BFF),
            child: Icon(Icons.straighten_outlined, color: kPrimary, size: 18),
          ),
          title: Text(item['nombre_unidad'],
              style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: _AccionesRow(onEdit: onEdit, onDelete: onDelete),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Tab: Programas académicos
// ─────────────────────────────────────────
class _ProgramasTab extends StatelessWidget {
  const _ProgramasTab();

  Future<void> _dialog(Map? item, BuildContext ctx,
      Future<void> Function(Map<String, dynamic>) onSave) async {
    final ctrl = TextEditingController(text: item?['nombre'] ?? '');
    await showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(item == null ? 'Nuevo programa' : 'Editar programa'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Nombre del programa *',
            hintText: 'Ej: Ingeniería Informática',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await onSave({'nombre': ctrl.text.trim(), 'activo': true});
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _CrudList(
      endpoint: 'academico/programas/',
      titulo: 'Programas',
      formDialog: _dialog,
      itemBuilder: (item, onEdit, onDelete) => Card(
        child: ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          leading: const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0x1A007BFF),
            child: Icon(Icons.school_outlined, color: kPrimary, size: 18),
          ),
          title: Text(item['nombre'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: (item['activo'] == false)
              ? const Text('Inactivo', style: TextStyle(color: kDanger, fontSize: 12))
              : null,
          trailing: _AccionesRow(onEdit: onEdit, onDelete: onDelete),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Tab: Docentes  (N:M con Programas y Asignaturas)
// ─────────────────────────────────────────
class _DocentesTab extends StatefulWidget {
  const _DocentesTab();

  @override
  State<_DocentesTab> createState() => _DocentesTabState();
}

class _DocentesTabState extends State<_DocentesTab> {
  List<Map<String, dynamic>> _programas   = [];
  List<Map<String, dynamic>> _asignaturas = [];

  @override
  void initState() {
    super.initState();
    _cargarCatalogos();
  }

  Future<void> _cargarCatalogos() async {
    try {
      final auth = context.read<AuthProvider>();
      final dio  = ApiClient.instance.authenticatedDio(auth.token);
      final results = await Future.wait([
        dio.get('academico/programas/'),
        dio.get('academico/asignaturas/'),
      ]);
      if (mounted) {
        final dp = results[0].data;
        final da = results[1].data;
        setState(() {
          _programas   = List<Map<String, dynamic>>.from(dp is List ? dp : (dp['results'] ?? []));
          _asignaturas = List<Map<String, dynamic>>.from(da is List ? da : (da['results'] ?? []));
        });
      }
    } catch (_) {}
  }

  Future<void> _dialog(Map? item, BuildContext ctx,
      Future<void> Function(Map<String, dynamic>) onSave) async {
    final nomCtrl    = TextEditingController(text: item?['nombre_completo'] ?? '');
    final correoCtrl = TextEditingController(text: item?['correo'] ?? '');

    // Inicializar selecciones múltiples desde el item existente
    final selProgramas = <String>{
      ...((item?['programas'] as List? ?? []).map((e) => e.toString())),
    };
    final selAsignaturas = <String>{
      ...((item?['asignaturas'] as List? ?? []).map((e) => e.toString())),
    };

    await showDialog(
      context: ctx,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (sCtx, setSt) => AlertDialog(
          title: Text(item == null ? 'Nuevo docente' : 'Editar docente',
              style: const TextStyle(color: kPrimary, fontSize: 16)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nomCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: correoCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo institucional *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Programas (multi-select con chips) ──────────────
                  const Text('Programas',
                      style: TextStyle(color: kPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  _MultiSelectChips(
                    opciones: _programas,
                    idKey: 'id',
                    labelKey: 'nombre',
                    seleccionados: selProgramas,
                    onChanged: (ids) => setSt(() {
                      selProgramas.clear();
                      selProgramas.addAll(ids);
                    }),
                  ),
                  const SizedBox(height: 16),

                  // ── Asignaturas (multi-select con chips) ────────────
                  const Text('Asignaturas',
                      style: TextStyle(color: kPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  _MultiSelectChips(
                    opciones: _asignaturas,
                    idKey: 'id',
                    labelKey: 'nombre_asignatura',
                    seleccionados: selAsignaturas,
                    onChanged: (ids) => setSt(() {
                      selAsignaturas.clear();
                      selAsignaturas.addAll(ids);
                    }),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(dialogCtx);
                await onSave({
                  'nombre_completo': nomCtrl.text.trim(),
                  'correo':          correoCtrl.text.trim(),
                  'programas':       selProgramas.toList(),
                  'asignaturas':     selAsignaturas.toList(),
                  'activo':          true,
                });
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    nomCtrl.dispose();
    correoCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _CrudList(
      endpoint: 'academico/docentes/',
      titulo: 'Docentes',
      formDialog: _dialog,
      itemBuilder: (item, onEdit, onDelete) {
        final programasNombres = (item['programas_nombres'] as List? ?? [])
            .map((e) => e.toString()).join(', ');
        final asignaturasNombres = (item['asignaturas_nombres'] as List? ?? [])
            .map((e) => e.toString()).join(', ');
        return Card(
          child: ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            leading: const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0x1A007BFF),
              child: Icon(Icons.person_pin_outlined, color: kPrimary, size: 18),
            ),
            title: Text(item['nombre_completo'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['correo'] ?? '', style: const TextStyle(fontSize: 12)),
                if (programasNombres.isNotEmpty)
                  Text(programasNombres,
                      style: const TextStyle(fontSize: 11, color: kPrimary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                if (asignaturasNombres.isNotEmpty)
                  Text(asignaturasNombres,
                      style: const TextStyle(fontSize: 11, color: kTextMuted),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
            isThreeLine: programasNombres.isNotEmpty || asignaturasNombres.isNotEmpty,
            trailing: _AccionesRow(onEdit: onEdit, onDelete: onDelete),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────
// Tab: Guías de práctica
// ─────────────────────────────────────────
class _GuiasTab extends StatefulWidget {
  const _GuiasTab();

  @override
  State<_GuiasTab> createState() => _GuiasTabState();
}

class _GuiasTabState extends State<_GuiasTab> {
  List<Map<String, dynamic>> _asignaturas = [];
  List<Map<String, dynamic>> _insumos     = [];

  @override
  void initState() {
    super.initState();
    _cargarCatalogos();
  }

  Future<void> _cargarCatalogos() async {
    try {
      final auth    = context.read<AuthProvider>();
      final dio     = ApiClient.instance.authenticatedDio(auth.token);
      final results = await Future.wait([
        dio.get('academico/asignaturas/'),
        dio.get('inventario/lista/'),
      ]);
      if (mounted) {
        final da = results[0].data;
        final di = results[1].data;
        setState(() {
          _asignaturas = List<Map<String, dynamic>>.from(da is List ? da : (da['results'] ?? []));
          _insumos     = List<Map<String, dynamic>>.from(di is List ? di : (di['results'] ?? []));
        });
      }
    } catch (_) {}
  }

  Future<void> _dialog(Map? item, BuildContext ctx,
      Future<void> Function(Map<String, dynamic>) onSave) async {
    final nomCtrl = TextEditingController(text: item?['nombre_guia'] ?? '');
    final urlCtrl = TextEditingController(text: item?['url_guia'] ?? '');
    String? selAsignatura = item?['asignatura']?.toString();

    await showDialog(
      context: ctx,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (sCtx, setSt) => AlertDialog(
          title: Text(item == null ? 'Nueva guía de práctica' : 'Editar guía',
              style: const TextStyle(color: kPrimary, fontSize: 16)),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nomCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la guía *',
                      hintText: 'Ej: Práctica 1 — Titulación ácido-base',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: urlCtrl,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'URL (Google Drive / PDF)',
                      hintText: 'https://drive.google.com/...',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.link, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Asignatura *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: DropdownButton<String>(
                      value: selAsignatura,
                      isExpanded: true,
                      underline: const SizedBox(),
                      isDense: true,
                      items: _asignaturas.map((a) => DropdownMenuItem(
                        value: a['id'].toString(),
                        child: Text(a['nombre_asignatura'] ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14)),
                      )).toList(),
                      onChanged: (v) => setSt(() => selAsignatura = v),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(dialogCtx);
                await onSave({
                  'nombre_guia': nomCtrl.text.trim(),
                  'url_guia':    urlCtrl.text.trim(),
                  'asignatura':  selAsignatura,
                });
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    nomCtrl.dispose();
    urlCtrl.dispose();
  }

  Future<void> _showInsumoGuiaDialog(
      BuildContext ctx, String guiaId, String guiaNombre) async {
    final auth = context.read<AuthProvider>();
    final dio  = ApiClient.instance.authenticatedDio(auth.token);

    List<Map<String, dynamic>> items = [];
    try {
      final resp = await dio.get('academico/insumos-guia/',
          queryParameters: {'guia': guiaId});
      final d = resp.data;
      items = List<Map<String, dynamic>>.from(d is List ? d : (d['results'] ?? []));
    } catch (_) {}

    if (!mounted || !ctx.mounted) return;

    String? selInsumo;
    final   cantCtrl = TextEditingController();

    await showDialog(
      context: ctx,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (sCtx, setSt) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.science_outlined, color: kPrimary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(guiaNombre,
                    style: const TextStyle(color: kPrimary, fontSize: 15),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Lista de insumos requeridos ──────────────────────────
                const Text('Insumos requeridos',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kPrimary)),
                const SizedBox(height: 6),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Sin insumos requeridos',
                        style: TextStyle(color: kTextMuted, fontSize: 13)),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final ig = items[i];
                        return ListTile(
                          dense: true,
                          title: Text(ig['nombre_insumo'] ?? '',
                              style: const TextStyle(fontSize: 13)),
                          subtitle: Text(
                            '${ig['cantidad_necesaria']} ${ig['unidad'] ?? ''}  '
                            '(stock: ${ig['stock_disponible']})',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: kDanger, size: 18),
                            tooltip: 'Quitar',
                            onPressed: () async {
                              try {
                                await dio.delete('academico/insumos-guia/${ig['id']}/');
                                setSt(() => items.removeWhere((e) => e['id'] == ig['id']));
                              } catch (_) {}
                            },
                          ),
                        );
                      },
                    ),
                  ),

                const Divider(height: 24),

                // ── Agregar insumo ──────────────────────────────────────
                const Text('Agregar insumo',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kPrimary)),
                const SizedBox(height: 8),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Insumo',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  child: DropdownButton<String>(
                    value: selInsumo,
                    isExpanded: true,
                    underline: const SizedBox(),
                    isDense: true,
                    items: _insumos.map((ins) => DropdownMenuItem(
                      value: ins['id'].toString(),
                      child: Text(ins['nombre_insumo'] ?? '',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13)),
                    )).toList(),
                    onChanged: (v) => setSt(() => selInsumo = v),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: cantCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Cantidad necesaria',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary, foregroundColor: Colors.white),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Agregar'),
                    onPressed: selInsumo == null
                        ? null
                        : () async {
                            try {
                              final resp = await dio.post('academico/insumos-guia/', data: {
                                'guia':               guiaId,
                                'insumo':             selInsumo,
                                'cantidad_necesaria': double.tryParse(cantCtrl.text.trim()) ?? 0,
                              });
                              setSt(() {
                                items.add(Map<String, dynamic>.from(resp.data));
                                selInsumo = null;
                                cantCtrl.clear();
                              });
                            } catch (_) {}
                          },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cerrar')),
          ],
        ),
      ),
    );
    cantCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _CrudList(
      endpoint: 'academico/guias/',
      titulo: 'Guías',
      formDialog: _dialog,
      itemBuilder: (item, onEdit, onDelete) {
        final guiaId = item['id'].toString();
        final nombre = item['nombre_guia'] ?? '';
        final asig   = item['nombre_asignatura'] ?? '';
        final url    = (item['url_guia'] ?? '').toString();
        return Card(
          child: ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            leading: const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0x1A007BFF),
              child: Icon(Icons.menu_book_outlined, color: kPrimary, size: 18),
            ),
            title: Text(nombre,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(asig,
                style: const TextStyle(fontSize: 12, color: kTextMuted)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (url.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.open_in_new, size: 18, color: kTextMuted),
                    tooltip: 'Abrir guía',
                    onPressed: () async {
                      final uri = Uri.tryParse(url);
                      if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.science_outlined, size: 20, color: kPrimary),
                  tooltip: 'Insumos requeridos',
                  onPressed: () => _showInsumoGuiaDialog(context, guiaId, nombre),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20, color: kPrimary),
                  tooltip: 'Editar',
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: kDanger),
                  tooltip: 'Eliminar',
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────
// Tab: Áreas de asignatura
// ─────────────────────────────────────────
class _AreasTab extends StatelessWidget {
  const _AreasTab();

  Future<void> _dialog(Map? item, BuildContext ctx,
      Future<void> Function(Map<String, dynamic>) onSave) async {
    final ctrl = TextEditingController(text: item?['nombre_area'] ?? '');
    await showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(item == null ? 'Nueva área' : 'Editar área'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Nombre del área *',
            hintText: 'Ej: Química Orgánica, Biología Celular',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await onSave({'nombre_area': ctrl.text.trim()});
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _CrudList(
      endpoint: 'academico/areas/',
      titulo: 'Áreas',
      formDialog: _dialog,
      itemBuilder: (item, onEdit, onDelete) => Card(
        child: ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          leading: const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0x1A007BFF),
            child: Icon(Icons.category_outlined, color: kPrimary, size: 18),
          ),
          title: Text(item['nombre_area'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: () {
            final total = item['total_asignaturas'];
            if (total == null) return null;
            return Text('$total asignatura${total == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 12, color: kTextMuted));
          }(),
          trailing: _AccionesRow(onEdit: onEdit, onDelete: onDelete),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Tab: Asignaturas
// ─────────────────────────────────────────
class _AsignaturasTab extends StatefulWidget {
  const _AsignaturasTab();

  @override
  State<_AsignaturasTab> createState() => _AsignaturasTabState();
}

class _AsignaturasTabState extends State<_AsignaturasTab> {
  List<Map<String, dynamic>> _areas = [];

  @override
  void initState() {
    super.initState();
    _cargarAreas();
  }

  Future<void> _cargarAreas() async {
    try {
      final auth = context.read<AuthProvider>();
      final dio  = ApiClient.instance.authenticatedDio(auth.token);
      final resp = await dio.get('academico/areas/');
      if (mounted) {
        final d = resp.data;
        setState(() {
          _areas = List<Map<String, dynamic>>.from(d is List ? d : (d['results'] ?? []));
        });
      }
    } catch (_) {}
  }

  Future<void> _dialog(Map? item, BuildContext ctx,
      Future<void> Function(Map<String, dynamic>) onSave) async {
    final ctrl = TextEditingController(text: item?['nombre_asignatura'] ?? '');
    String? selArea = item?['area']?.toString();

    await showDialog(
      context: ctx,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (sCtx, setSt) => AlertDialog(
          title: Text(item == null ? 'Nueva asignatura' : 'Editar asignatura',
              style: const TextStyle(color: kPrimary, fontSize: 16)),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la asignatura *',
                    hintText: 'Ej: Química General I',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Área *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  child: DropdownButton<String>(
                    value: selArea,
                    isExpanded: true,
                    underline: const SizedBox(),
                    isDense: true,
                    hint: const Text('Selecciona un área',
                        style: TextStyle(fontSize: 14, color: kTextMuted)),
                    items: _areas.map((a) => DropdownMenuItem(
                      value: a['id'].toString(),
                      child: Text(a['nombre_area'] ?? '',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14)),
                    )).toList(),
                    onChanged: (v) => setSt(() => selArea = v),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(dialogCtx);
                await onSave({
                  'nombre_asignatura': ctrl.text.trim(),
                  'area':              selArea,
                });
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _CrudList(
      endpoint: 'academico/asignaturas/',
      titulo: 'Asignaturas',
      formDialog: _dialog,
      itemBuilder: (item, onEdit, onDelete) => Card(
        child: ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          leading: const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0x1A007BFF),
            child: Icon(Icons.science_outlined, color: kPrimary, size: 18),
          ),
          title: Text(item['nombre_asignatura'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: () {
            final area  = item['nombre_area'] ?? '';
            final guias = item['total_guias'];
            if (area.isEmpty) return null;
            return Text(
              guias != null ? '$area · $guias guía${guias == 1 ? '' : 's'}' : area,
              style: const TextStyle(fontSize: 12, color: kTextMuted),
            );
          }(),
          trailing: _AccionesRow(onEdit: onEdit, onDelete: onDelete),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Widget de selección múltiple con chips
// ─────────────────────────────────────────
class _MultiSelectChips extends StatelessWidget {
  final List<Map<String, dynamic>> opciones;
  final String idKey;
  final String labelKey;
  final Set<String> seleccionados;
  final void Function(Set<String>) onChanged;

  const _MultiSelectChips({
    required this.opciones,
    required this.idKey,
    required this.labelKey,
    required this.seleccionados,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (opciones.isEmpty) {
      return const Text('Sin opciones disponibles',
          style: TextStyle(color: kTextMuted, fontSize: 12));
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: opciones.map((op) {
        final id      = op[idKey].toString();
        final label   = op[labelKey]?.toString() ?? id;
        final activo  = seleccionados.contains(id);
        return FilterChip(
          label: Text(label, style: TextStyle(
              fontSize: 12,
              color: activo ? Colors.white : Colors.black87)),
          selected: activo,
          onSelected: (_) {
            final nuevo = Set<String>.from(seleccionados);
            if (activo) { nuevo.remove(id); } else { nuevo.add(id); }
            onChanged(nuevo);
          },
          selectedColor: kPrimary,
          checkmarkColor: Colors.white,
          backgroundColor: const Color(0xFFF0F0F0),
          side: BorderSide(color: activo ? kPrimary : const Color(0xFFCCCCCC)),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────
// Widget de acciones (editar / eliminar)
// ─────────────────────────────────────────
class _AccionesRow extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _AccionesRow({required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, color: kPrimary, size: 20),
          tooltip: 'Editar',
          onPressed: onEdit,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: kDanger, size: 20),
          tooltip: 'Eliminar',
          onPressed: onDelete,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// Tab: Configuración del Laboratorio
// ─────────────────────────────────────────
class _LabConfigTab extends StatefulWidget {
  const _LabConfigTab();

  @override
  State<_LabConfigTab> createState() => _LabConfigTabState();
}

class _LabConfigTabState extends State<_LabConfigTab> {
  final _formKey = GlobalKey<FormState>();
  bool _loading   = true;
  bool _guardando = false;
  String? _error;

  final _c = <String, TextEditingController>{
    'nombre_laboratorio':          TextEditingController(),
    'direccion_laboratorio':       TextEditingController(),
    'telefono_emergencia':         TextEditingController(),
    'nombre_proveedor_defecto':    TextEditingController(),
    'direccion_proveedor_defecto': TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    for (final c in _c.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final auth = context.read<AuthProvider>();
      final dio  = ApiClient.instance.authenticatedDio(auth.token);
      final r    = await dio.get('inventario/configuracion-global/');
      final d    = Map<String, dynamic>.from(r.data);
      for (final k in _c.keys) {
        _c[k]!.text = d[k]?.toString() ?? '';
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Error cargando la configuración.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    if (!auth.can(Perm.configuracionGestion)) return;
    setState(() => _guardando = true);
    try {
      final dio = ApiClient.instance.authenticatedDio(auth.token);
      final payload = {for (final k in _c.keys) k: _c[k]!.text.trim()};
      await dio.patch('inventario/configuracion-global/', data: payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuración guardada.'),
            backgroundColor: kSuccess),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al guardar.'),
            backgroundColor: kDanger),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  InputDecoration _deco(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    border: const OutlineInputBorder(),
    focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: kPrimary)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );

  @override
  Widget build(BuildContext context) {
    final auth    = context.watch<AuthProvider>();
    final puedeEditar = auth.can(Perm.configuracionGestion);

    if (_loading) { return const Center(child: CircularProgressIndicator(color: kPrimary)); }
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, style: const TextStyle(color: kDanger)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _cargar, child: const Text('Reintentar')),
        ]),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Datos del laboratorio',
                  style: TextStyle(fontWeight: FontWeight.bold,
                      color: kPrimary, fontSize: 15)),
              const SizedBox(height: 16),

              TextFormField(
                controller: _c['nombre_laboratorio'],
                enabled: puedeEditar,
                decoration: _deco('Nombre del laboratorio'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _c['direccion_laboratorio'],
                enabled: puedeEditar,
                decoration: _deco('Dirección'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _c['telefono_emergencia'],
                enabled: puedeEditar,
                decoration: _deco('Teléfono de emergencias',
                    hint: 'Ej: 119 — Bomberos Rionegro'),
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 24),
              const Text('Proveedor por defecto (etiquetas SGA)',
                  style: TextStyle(fontWeight: FontWeight.bold,
                      color: kPrimary, fontSize: 15)),
              const SizedBox(height: 16),

              TextFormField(
                controller: _c['nombre_proveedor_defecto'],
                enabled: puedeEditar,
                decoration: _deco('Nombre del proveedor'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _c['direccion_proveedor_defecto'],
                enabled: puedeEditar,
                decoration: _deco('Dirección del proveedor'),
                maxLines: 2,
              ),

              if (puedeEditar) ...[
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _guardando ? null : _guardar,
                    icon: _guardando
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_outlined),
                    label: const Text('Guardar configuración'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kSemaforoAmarillo.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: kSemaforoAmarillo.withValues(alpha: 0.4)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.lock_outline, color: kSemaforoAmarillo, size: 16),
                    SizedBox(width: 8),
                    Text('Solo administradores y laboratoristas pueden editar.',
                        style: TextStyle(
                            fontSize: 12, color: kSemaforoAmarillo)),
                  ]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
