import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
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
          labelColor: kPrimary,
          unselectedLabelColor: kTextMuted,
          indicatorColor: kPrimary,
          tabs: const [
            Tab(icon: Icon(Icons.place_outlined),        text: 'Ubicaciones'),
            Tab(icon: Icon(Icons.straighten_outlined),   text: 'Unidades'),
            Tab(icon: Icon(Icons.school_outlined),        text: 'Programas'),
            Tab(icon: Icon(Icons.person_pin_outlined),    text: 'Docentes'),
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
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      final dio  = ApiClient.instance.authenticatedDio(auth.token);
      final resp = await dio.get(widget.endpoint);
      setState(() {
        final d  = resp.data;
        _items   = List<Map<String, dynamic>>.from(d is List ? d : (d['results'] ?? []));
        _loading = false;
      });
    } catch (e) {
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
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
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
          leading: const CircleAvatar(
            backgroundColor: Color(0x1A007BFF),
            child: Icon(Icons.place_outlined, color: kPrimary, size: 20),
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
          leading: const CircleAvatar(
            backgroundColor: Color(0x1A007BFF),
            child: Icon(Icons.straighten_outlined, color: kPrimary, size: 20),
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
          leading: const CircleAvatar(
            backgroundColor: Color(0x1A007BFF),
            child: Icon(Icons.school_outlined, color: kPrimary, size: 20),
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
            leading: const CircleAvatar(
              backgroundColor: Color(0x1A007BFF),
              child: Icon(Icons.person_pin_outlined, color: kPrimary, size: 20),
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
