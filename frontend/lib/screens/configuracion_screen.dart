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
    _tab = TabController(length: 3, vsync: this);
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
            Tab(icon: Icon(Icons.category_outlined),    text: 'Tipos'),
            Tab(icon: Icon(Icons.place_outlined),        text: 'Ubicaciones'),
            Tab(icon: Icon(Icons.straighten_outlined),   text: 'Unidades'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _TiposTab(),
          _UbicacionesTab(),
          _UnidadesTab(),
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
        _items   = List<Map<String, dynamic>>.from(resp.data['results'] ?? resp.data);
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
// Tab: Tipos de Insumo
// ─────────────────────────────────────────
class _TiposTab extends StatelessWidget {
  const _TiposTab();

  static const _opciones = ['Implemento', 'Vidriería', 'Químico', 'Equipo'];

  static const _iconos = {
    'Implemento': Icons.build_outlined,
    'Vidriería':  Icons.wine_bar_outlined,
    'Químico':    Icons.science_outlined,
    'Equipo':     Icons.precision_manufacturing_outlined,
  };

  Future<void> _dialog(Map? item, BuildContext ctx,
      Future<void> Function(Map<String, dynamic>) onSave) async {
    String selected = item?['nombre_tipo'] ?? _opciones.first;
    await showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(builder: (ctx2, setSt) => AlertDialog(
        title: Text(item == null ? 'Nuevo tipo de insumo' : 'Editar tipo'),
        content: DropdownButtonFormField<String>(
          value: selected,
          items: _opciones.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: (v) => setSt(() => selected = v!),
          decoration: const InputDecoration(
            labelText: 'Tipo',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx2);
              await onSave({'nombre_tipo': selected});
            },
            child: const Text('Guardar'),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _CrudList(
      endpoint: 'inventario/tipos/',
      titulo: 'Tipos',
      formDialog: _dialog,
      itemBuilder: (item, onEdit, onDelete) => Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: kPrimary.withOpacity(0.1),
            child: Icon(_iconos[item['nombre_tipo']] ?? Icons.category,
                color: kPrimary, size: 20),
          ),
          title: Text(item['nombre_tipo'],
              style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: _AccionesRow(onEdit: onEdit, onDelete: onDelete),
        ),
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
