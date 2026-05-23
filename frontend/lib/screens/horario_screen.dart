import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api/api_client.dart';
import '../core/theme/colors.dart';
import '../core/permissions.dart';
import '../providers/auth_provider.dart';

// ── Constantes ────────────────────────────────────────────────────────────────

const _dias = ['Lunes', 'Martes', 'Miérc.', 'Jueves', 'Viernes', 'Sábado'];
const _horas = [6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21];

const double _colWidth   = 150;
const double _labelWidth = 54;
const double _rowHeight  = 62;

// ── Screen ────────────────────────────────────────────────────────────────────

class HorarioScreen extends StatefulWidget {
  const HorarioScreen({super.key});
  @override State<HorarioScreen> createState() => _HorarioScreenState();
}

class _HorarioScreenState extends State<HorarioScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Horario semanal',
            style: TextStyle(color: kPrimary, fontWeight: FontWeight.bold)),
        elevation: 1,
        bottom: TabBar(
          controller: _tab,
          labelColor: kPrimary,
          unselectedLabelColor: kTextMuted,
          indicatorColor: kPrimary,
          tabs: const [
            Tab(icon: Icon(Icons.person_pin_outlined),   text: 'Encargados'),
            Tab(icon: Icon(Icons.school_outlined),        text: 'Asignaturas'),
            Tab(icon: Icon(Icons.category_outlined),      text: 'Gestión'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _TabEncargados(),
          _TabAsignaturas(),
          _TabGestion(),
        ],
      ),
    );
  }
}

// ── Diálogo: gestión de guías de una asignatura ───────────────────────────────

class _GuiasDialog extends StatefulWidget {
  final Map<String, dynamic> asignatura;
  final bool puedeEditar;
  const _GuiasDialog({required this.asignatura, required this.puedeEditar});
  @override
  State<_GuiasDialog> createState() => _GuiasDialogState();
}

class _GuiasDialogState extends State<_GuiasDialog> {
  List<Map<String, dynamic>> _guias = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final auth = context.read<AuthProvider>();
      final dio  = ApiClient.instance.authenticatedDio(auth.token);
      final asigId = widget.asignatura['id'].toString();
      final r = await dio.get('academico/guias/?asignatura=$asigId');
      setState(() {
        _guias = List<Map<String, dynamic>>.from(
            r.data is List ? r.data : (r.data['results'] ?? []));
        _cargando = false;
      });
    } catch (_) {
      setState(() => _cargando = false);
    }
  }

  Future<void> _guardar(Map<String, dynamic> data, {String? id}) async {
    final auth = context.read<AuthProvider>();
    final dio  = ApiClient.instance.authenticatedDio(auth.token);
    try {
      if (id != null) {
        await dio.patch('academico/guias/$id/', data: data);
      } else {
        await dio.post('academico/guias/', data: {
          ...data,
          'asignatura': widget.asignatura['id'],
        });
      }
      await _cargar();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: kDanger));
    }
  }

  Future<void> _eliminar(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar guía'),
        content: const Text('¿Estás seguro? Se eliminará el registro de esta guía.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar', style: TextStyle(color: kDanger))),
        ],
      ),
    );
    if (ok != true) return;
    final auth = context.read<AuthProvider>();
    final dio  = ApiClient.instance.authenticatedDio(auth.token);
    try {
      await dio.delete('academico/guias/$id/');
      await _cargar();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: kDanger));
    }
  }

  Future<void> _dialog([Map<String, dynamic>? item]) async {
    final nomCtrl = TextEditingController(text: item?['nombre_guia'] ?? '');
    final urlCtrl = TextEditingController(text: item?['url_guia'] ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(item == null ? 'Nueva guía' : 'Editar guía',
            style: const TextStyle(color: kPrimary)),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Nombre de la guía *',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'URL en Drive (opcional)',
                  hintText: 'https://drive.google.com/...',
                  prefixIcon: Icon(Icons.link, color: kPrimary),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    final nombre = nomCtrl.text.trim();
    final url    = urlCtrl.text.trim();
    nomCtrl.dispose();
    urlCtrl.dispose();
    if (ok != true || nombre.isEmpty) return;
    await _guardar(
        {'nombre_guia': nombre, 'url_guia': url.isEmpty ? null : url},
        id: item?['id']?.toString());
  }

  @override
  Widget build(BuildContext context) {
    final asigNombre = widget.asignatura['nombre_asignatura'] ?? '';
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.menu_book_outlined, color: kPrimary, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Guías — $asigNombre',
              style: const TextStyle(color: kPrimary, fontSize: 15)),
        ),
        if (widget.puedeEditar)
          IconButton(
            icon: const Icon(Icons.add, color: kPrimary),
            tooltip: 'Nueva guía',
            onPressed: _dialog,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ]),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      content: SizedBox(
        width: 420,
        height: 360,
        child: _cargando
            ? const Center(child: CircularProgressIndicator(color: kPrimary))
            : _guias.isEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.menu_book_outlined,
                          size: 48, color: kTextMuted),
                      const SizedBox(height: 8),
                      const Text('Sin guías registradas',
                          style: TextStyle(color: kTextMuted)),
                      if (widget.puedeEditar) ...[
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _dialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Agregar primera guía'),
                        ),
                      ],
                    ],
                  )
                : ListView.separated(
                    itemCount: _guias.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final g   = _guias[i];
                      final url = g['url_guia']?.toString() ?? '';
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.description_outlined,
                            color: kPrimary, size: 20),
                        title: Text(g['nombre_guia'] ?? '',
                            style: const TextStyle(fontSize: 13)),
                        subtitle: url.isNotEmpty
                            ? Text(url,
                                style: const TextStyle(
                                    fontSize: 10, color: kTextMuted),
                                overflow: TextOverflow.ellipsis)
                            : const Text('Sin URL',
                                style: TextStyle(
                                    fontSize: 10, color: kTextMuted)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (url.isNotEmpty)
                              Tooltip(
                                message: 'Abrir en Drive',
                                child: IconButton(
                                  icon: const Icon(Icons.open_in_new,
                                      color: kPrimary, size: 18),
                                  onPressed: () =>
                                      launchUrl(Uri.parse(url)),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ),
                            if (widget.puedeEditar) ...[
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    color: kPrimary, size: 18),
                                onPressed: () => _dialog(g),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: kDanger, size: 18),
                                onPressed: () =>
                                    _eliminar(g['id'].toString()),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar')),
      ],
    );
  }
}

// ── Tab Encargados ────────────────────────────────────────────────────────────

class _TabEncargados extends StatefulWidget {
  const _TabEncargados();
  @override State<_TabEncargados> createState() => _TabEncargadosState();
}

class _TabEncargadosState extends State<_TabEncargados>
    with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;

  // [dia][hora] → List<{id, username, nombre_completo, rol}>
  Map<int, Map<int, List<Map<String, dynamic>>>> _grid = {};
  List<Map<String, dynamic>> _disponibles = [];
  bool _cargando = true;

  @override
  void initState() { super.initState(); Future.microtask(_cargar); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final auth = context.read<AuthProvider>();
    final dio  = ApiClient.instance.authenticatedDio(auth.token);

    // Grid y disponibles se cargan por separado: un fallo en uno no bloquea al otro
    try {
      final resp = await dio.get('academico/horario-encargado/');
      final registros = List<Map<String, dynamic>>.from(
          resp.data is List ? resp.data : (resp.data['results'] ?? []));
      final Map<int, Map<int, List<Map<String, dynamic>>>> grid = {
        for (final d in [0,1,2,3,4,5]) d: {for (final h in _horas) h: []},
      };
      for (final r in registros) {
        grid[r['dia_semana'] as int]?[r['hora'] as int]?.add(r);
      }
      setState(() => _grid = grid);
    } catch (_) {}

    try {
      final resp = await dio.get('academico/encargados-disponibles/');
      final disponibles = List<Map<String, dynamic>>.from(
          resp.data is List ? resp.data : (resp.data['results'] ?? []));
      setState(() => _disponibles = disponibles);
    } catch (_) {}

    setState(() => _cargando = false);
  }

  Future<void> _agregar(int dia, int hora) async {
    final auth = context.read<AuthProvider>();
    if (!auth.can(Perm.academicoGestionar)) return;

    if (_disponibles.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No hay usuarios con rol LAB o MONITOR. '
              'Asigna el rol en Permisos → Por usuario y actualiza.'),
          duration: Duration(seconds: 4),
        ));
      }
      return;
    }

    // Excluir los que ya están en este slot
    final yaAsignados = _grid[dia]?[hora]?.map((e) => e['usuario'] as int).toSet() ?? {};
    final opciones = _disponibles.where((u) => !yaAsignados.contains(u['id'] as int)).toList();

    if (opciones.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Todos los encargados disponibles ya están en este bloque.')));
      }
      return;
    }

    final sel = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _SelectorEncargadoDialog(opciones: opciones),
    );
    if (sel == null || !mounted) return;

    final dio = ApiClient.instance.authenticatedDio(auth.token);
    try {
      final r = await dio.post('academico/horario-encargado/', data: {
        'usuario': sel['id'],
        'dia_semana': dia,
        'hora': hora,
      });
      setState(() => _grid[dia]?[hora]?.add(r.data as Map<String, dynamic>));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al guardar'), backgroundColor: kDanger));
      }
    }
  }

  Future<void> _eliminar(int dia, int hora, Map<String, dynamic> item) async {
    final auth = context.read<AuthProvider>();
    if (!auth.can(Perm.academicoGestionar)) return;
    final dio = ApiClient.instance.authenticatedDio(auth.token);
    try {
      await dio.delete('academico/horario-encargado/${item['id']}/');
      setState(() => _grid[dia]?[hora]?.removeWhere((e) => e['id'] == item['id']));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = context.watch<AuthProvider>();
    final puedeEditar = auth.can(Perm.academicoGestionar);

    if (_cargando) return const Center(child: CircularProgressIndicator(color: kPrimary));

    return Column(
      children: [
        // Barra superior con info de encargados + botón actualizar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            Icon(Icons.people_outline, size: 16, color: _disponibles.isEmpty ? kDanger : kTextMuted),
            const SizedBox(width: 6),
            Text(
              _disponibles.isEmpty
                  ? 'Sin encargados LAB/MONITOR disponibles'
                  : '${_disponibles.length} encargado${_disponibles.length != 1 ? 's' : ''} disponible${_disponibles.length != 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 12,
                color: _disponibles.isEmpty ? kDanger : kTextMuted,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Actualizar', style: TextStyle(fontSize: 12)),
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildGrid(puedeEditar),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(bool puedeEditar) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabecera con días
        Row(children: [
          SizedBox(width: _labelWidth),
          ..._dias.asMap().entries.map((e) => _diaHeader(e.key, e.value)),
        ]),
        const Divider(height: 1, thickness: 1, color: Color(0xFFDEE2E6)),
        // Filas de horas
        ..._horas.map((h) => _buildHoraRow(h, puedeEditar)),
      ],
    );
  }

  Widget _diaHeader(int dia, String nombre) => Container(
    width: _colWidth,
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: const BoxDecoration(color: kPrimary),
    alignment: Alignment.center,
    child: Text(nombre,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
  );

  Widget _buildHoraRow(int hora, bool puedeEditar) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Etiqueta de hora
          Container(
            width: _labelWidth,
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: Color(0xFFDEE2E6))),
            ),
            child: Text('${hora.toString().padLeft(2, '0')}:00',
                style: const TextStyle(fontSize: 11, color: kTextMuted, fontWeight: FontWeight.w600)),
          ),
          // Celdas por día
          ...[0,1,2,3,4,5].map((dia) {
            final items = _grid[dia]?[hora] ?? [];
            return GestureDetector(
              onTap: puedeEditar ? () => _agregar(dia, hora) : null,
              child: Container(
                width: _colWidth,
                constraints: const BoxConstraints(minHeight: _rowHeight),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: dia.isOdd ? const Color(0xFFF8F9FA) : Colors.white,
                  border: const Border(
                    right:  BorderSide(color: Color(0xFFDEE2E6)),
                    bottom: BorderSide(color: Color(0xFFDEE2E6)),
                  ),
                ),
                child: Wrap(
                  spacing: 3, runSpacing: 3,
                  children: [
                    ...items.map((item) => _chipEncargado(item, dia, hora, puedeEditar)),
                    if (puedeEditar)
                      InkWell(
                        onTap: () => _agregar(dia, hora),
                        borderRadius: BorderRadius.circular(10),
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(Icons.add_circle_outline, size: 16, color: kTextMuted),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _chipEncargado(Map<String, dynamic> item, int dia, int hora, bool puedeEditar) {
    final rol = item['rol']?.toString() ?? '';
    final color = rol == 'LAB' ? kSuccess : kPrimary;
    final nombre = item['nombre_completo']?.toString() ?? item['username']?.toString() ?? '?';
    final iniciales = nombre.split(' ').take(2).map((p) => p.isNotEmpty ? p[0].toUpperCase() : '').join();

    return GestureDetector(
      onLongPress: puedeEditar ? () => _eliminar(dia, hora, item) : null,
      child: Tooltip(
        message: '$nombre ($rol)\nMantén presionado para quitar',
        child: Chip(
          label: Text(iniciales.isEmpty ? nombre.substring(0, 1).toUpperCase() : iniciales,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          backgroundColor: color,
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

// ── Tab Asignaturas ───────────────────────────────────────────────────────────

class _TabAsignaturas extends StatefulWidget {
  const _TabAsignaturas();
  @override State<_TabAsignaturas> createState() => _TabAsignaturasState();
}

class _TabAsignaturasState extends State<_TabAsignaturas>
    with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;

  // [dia][hora] → List<{id, nombre_asignatura, docente, grupo}>
  Map<int, Map<int, List<Map<String, dynamic>>>> _grid = {};
  List<Map<String, dynamic>> _asignaturas = [];
  bool _cargando = true;

  @override
  void initState() { super.initState(); Future.microtask(_cargar); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final auth = context.read<AuthProvider>();
    final dio  = ApiClient.instance.authenticatedDio(auth.token);

    try {
      final resp = await dio.get('academico/horario-asignatura/');
      final registros = List<Map<String, dynamic>>.from(
          resp.data is List ? resp.data : (resp.data['results'] ?? []));
      final Map<int, Map<int, List<Map<String, dynamic>>>> grid = {
        for (final d in [0,1,2,3,4,5]) d: {for (final h in _horas) h: []},
      };
      for (final r in registros) {
        grid[r['dia_semana'] as int]?[r['hora'] as int]?.add(r);
      }
      setState(() => _grid = grid);
    } catch (_) {}

    try {
      final resp = await dio.get('academico/asignaturas/');
      final asignaturas = List<Map<String, dynamic>>.from(
          resp.data is List ? resp.data : (resp.data['results'] ?? []));
      setState(() => _asignaturas = asignaturas);
    } catch (_) {}

    setState(() => _cargando = false);
  }

  Future<void> _agregar(int dia, int hora) async {
    final auth = context.read<AuthProvider>();
    if (!auth.can(Perm.academicoGestionar)) return;

    if (_asignaturas.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No hay asignaturas. Créalas en la pestaña "Gestión".'),
          duration: Duration(seconds: 3),
        ));
      }
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _FormAsignaturaDialog(asignaturas: _asignaturas),
    );
    if (result == null || !mounted) return;

    final dio = ApiClient.instance.authenticatedDio(auth.token);
    try {
      final r = await dio.post('academico/horario-asignatura/', data: {
        'asignatura': result['asignatura_id'],
        'dia_semana': dia,
        'hora': hora,
        'docente': result['docente'],
        'grupo': result['grupo'],
      });
      setState(() => _grid[dia]?[hora]?.add(r.data as Map<String, dynamic>));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al guardar'), backgroundColor: kDanger));
      }
    }
  }

  Future<void> _eliminar(int dia, int hora, Map<String, dynamic> item) async {
    final auth = context.read<AuthProvider>();
    if (!auth.can(Perm.academicoGestionar)) return;
    final dio = ApiClient.instance.authenticatedDio(auth.token);
    try {
      await dio.delete('academico/horario-asignatura/${item['id']}/');
      setState(() => _grid[dia]?[hora]?.removeWhere((e) => e['id'] == item['id']));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = context.watch<AuthProvider>();
    final puedeEditar = auth.can(Perm.academicoGestionar);

    if (_cargando) return const Center(child: CircularProgressIndicator(color: kPrimary));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            Icon(Icons.school_outlined, size: 16, color: _asignaturas.isEmpty ? kDanger : kTextMuted),
            const SizedBox(width: 6),
            Text(
              _asignaturas.isEmpty
                  ? 'Sin asignaturas registradas'
                  : '${_asignaturas.length} asignatura${_asignaturas.length != 1 ? 's' : ''} disponible${_asignaturas.length != 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 12,
                color: _asignaturas.isEmpty ? kDanger : kTextMuted,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Actualizar', style: TextStyle(fontSize: 12)),
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildGrid(puedeEditar),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(bool puedeEditar) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          SizedBox(width: _labelWidth),
          ..._dias.asMap().entries.map((e) => _diaHeader(e.key, e.value)),
        ]),
        const Divider(height: 1, thickness: 1, color: Color(0xFFDEE2E6)),
        ..._horas.map((h) => _buildHoraRow(h, puedeEditar)),
      ],
    );
  }

  Widget _diaHeader(int dia, String nombre) => Container(
    width: _colWidth,
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: const BoxDecoration(color: kPrimary),
    alignment: Alignment.center,
    child: Text(nombre,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
  );

  Widget _buildHoraRow(int hora, bool puedeEditar) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: _labelWidth,
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: Color(0xFFDEE2E6))),
            ),
            child: Text('${hora.toString().padLeft(2, '0')}:00',
                style: const TextStyle(fontSize: 11, color: kTextMuted, fontWeight: FontWeight.w600)),
          ),
          ...[0,1,2,3,4,5].map((dia) {
            final items = _grid[dia]?[hora] ?? [];
            return GestureDetector(
              onTap: puedeEditar ? () => _agregar(dia, hora) : null,
              child: Container(
                width: _colWidth,
                constraints: const BoxConstraints(minHeight: _rowHeight),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: dia.isOdd ? const Color(0xFFF8F9FA) : Colors.white,
                  border: const Border(
                    right:  BorderSide(color: Color(0xFFDEE2E6)),
                    bottom: BorderSide(color: Color(0xFFDEE2E6)),
                  ),
                ),
                child: Wrap(
                  spacing: 3, runSpacing: 3,
                  children: [
                    ...items.map((item) => _chipAsignatura(item, dia, hora, puedeEditar)),
                    if (puedeEditar)
                      InkWell(
                        onTap: () => _agregar(dia, hora),
                        borderRadius: BorderRadius.circular(10),
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(Icons.add_circle_outline, size: 16, color: kTextMuted),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _chipAsignatura(Map<String, dynamic> item, int dia, int hora, bool puedeEditar) {
    final nombre  = item['nombre_asignatura']?.toString() ?? '?';
    final docente = item['docente']?.toString() ?? '';
    final grupo   = item['grupo']?.toString() ?? '';
    final subtitle = [if (docente.isNotEmpty) docente, if (grupo.isNotEmpty) grupo].join(' · ');

    return GestureDetector(
      onLongPress: puedeEditar ? () => _eliminar(dia, hora, item) : null,
      child: Tooltip(
        message: '$nombre${subtitle.isNotEmpty ? '\n$subtitle' : ''}\nMantén presionado para quitar',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: kPrimary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: kPrimary.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(nombre,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kPrimary),
                  overflow: TextOverflow.ellipsis),
              if (subtitle.isNotEmpty)
                Text(subtitle,
                    style: const TextStyle(fontSize: 9, color: kTextMuted),
                    overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tab Gestión (Áreas + Asignaturas CRUD) ────────────────────────────────────

class _TabGestion extends StatefulWidget {
  const _TabGestion();
  @override State<_TabGestion> createState() => _TabGestionState();
}

class _TabGestionState extends State<_TabGestion>
    with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _areas        = [];
  List<Map<String, dynamic>> _asignaturas  = [];
  bool _cargando = true;

  @override
  void initState() { super.initState(); Future.microtask(_cargar); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final auth = context.read<AuthProvider>();
    final dio  = ApiClient.instance.authenticatedDio(auth.token);

    try {
      final r = await dio.get('academico/areas/');
      setState(() => _areas = List<Map<String, dynamic>>.from(
          r.data is List ? r.data : (r.data['results'] ?? [])));
    } catch (_) {}

    try {
      final r = await dio.get('academico/asignaturas/');
      setState(() => _asignaturas = List<Map<String, dynamic>>.from(
          r.data is List ? r.data : (r.data['results'] ?? [])));
    } catch (_) {}

    setState(() => _cargando = false);
  }

  // ── CRUD Áreas ──────────────────────────────────────────────────────────────

  Future<void> _guardarArea(Map<String, dynamic> data, {String? id}) async {
    final auth = context.read<AuthProvider>();
    final dio  = ApiClient.instance.authenticatedDio(auth.token);
    try {
      if (id != null) {
        await dio.patch('academico/areas/$id/', data: data);
      } else {
        await dio.post('academico/areas/', data: data);
      }
      await _cargar();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: kDanger));
    }
  }

  Future<void> _eliminarArea(String id) async {
    if (await _confirmar() != true) return;
    final auth = context.read<AuthProvider>();
    final dio  = ApiClient.instance.authenticatedDio(auth.token);
    try {
      await dio.delete('academico/areas/$id/');
      await _cargar();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: kDanger));
    }
  }

  Future<void> _dialogArea([Map<String, dynamic>? item]) async {
    final ctrl = TextEditingController(text: item?['nombre_area'] ?? '');
    final ok   = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(item == null ? 'Nueva área' : 'Editar área',
            style: const TextStyle(color: kPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre del área *',
            hintText: 'Ej: Química, Biología',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    final nombre = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || nombre.isEmpty) return;
    await _guardarArea({'nombre_area': nombre}, id: item?['id']?.toString());
  }

  // ── CRUD Asignaturas ────────────────────────────────────────────────────────

  Future<void> _guardarAsignatura(Map<String, dynamic> data, {String? id}) async {
    final auth = context.read<AuthProvider>();
    final dio  = ApiClient.instance.authenticatedDio(auth.token);
    try {
      if (id != null) {
        await dio.patch('academico/asignaturas/$id/', data: data);
      } else {
        await dio.post('academico/asignaturas/', data: data);
      }
      await _cargar();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: kDanger));
    }
  }

  Future<void> _eliminarAsignatura(String id) async {
    if (await _confirmar() != true) return;
    final auth = context.read<AuthProvider>();
    final dio  = ApiClient.instance.authenticatedDio(auth.token);
    try {
      await dio.delete('academico/asignaturas/$id/');
      await _cargar();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: kDanger));
    }
  }

  Future<void> _dialogAsignatura([Map<String, dynamic>? item]) async {
    if (_areas.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Crea un área primero antes de agregar asignaturas.')));
      return;
    }
    final ctrl   = TextEditingController(text: item?['nombre_asignatura'] ?? '');
    String? areaId = item?['area']?.toString() ?? _areas.first['id']?.toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(item == null ? 'Nueva asignatura' : 'Editar asignatura',
              style: const TextStyle(color: kPrimary)),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la asignatura *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: areaId,
                  decoration: const InputDecoration(
                    labelText: 'Área *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category_outlined, color: kPrimary),
                  ),
                  items: _areas.map((a) => DropdownMenuItem(
                    value: a['id'].toString(),
                    child: Text(a['nombre_area'].toString()),
                  )).toList(),
                  onChanged: (v) => setS(() => areaId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    final nombre = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || nombre.isEmpty || areaId == null) return;
    await _guardarAsignatura(
        {'nombre_asignatura': nombre, 'area': areaId},
        id: item?['id']?.toString());
  }

  Future<bool?> _confirmar() => showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Confirmar eliminación'),
      content: const Text('¿Estás seguro de que quieres eliminar este elemento?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: kDanger))),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth        = context.watch<AuthProvider>();
    final puedeEditar = auth.can(Perm.academicoGestionar);

    if (_cargando) return const Center(child: CircularProgressIndicator(color: kPrimary));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            const Icon(Icons.category_outlined, size: 16, color: kTextMuted),
            const SizedBox(width: 6),
            Text(
              '${_areas.length} área${_areas.length != 1 ? 's' : ''} · ${_asignaturas.length} asignatura${_asignaturas.length != 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 12, color: kTextMuted),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Actualizar', style: TextStyle(fontSize: 12)),
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Columna Áreas ────────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Text('ÁREAS',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold,
                                color: kTextMuted, letterSpacing: 1.2)),
                        const Spacer(),
                        if (puedeEditar)
                          TextButton.icon(
                            onPressed: () => _dialogArea(),
                            icon: const Icon(Icons.add, size: 14),
                            label: const Text('Nueva', style: TextStyle(fontSize: 12)),
                          ),
                      ]),
                      const SizedBox(height: 8),
                      if (_areas.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('Sin áreas registradas',
                              style: TextStyle(color: kTextMuted, fontSize: 13)),
                        )
                      else
                        ..._areas.map((a) {
                          final countAsig = _asignaturas
                              .where((s) => s['area'].toString() == a['id'].toString())
                              .length;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              dense: true,
                              leading: const CircleAvatar(
                                radius: 14,
                                backgroundColor: Color(0x1A007BFF),
                                child: Icon(Icons.category_outlined,
                                    color: kPrimary, size: 14),
                              ),
                              title: Text(a['nombre_area']?.toString() ?? '',
                                  style: const TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w600)),
                              subtitle: Text('$countAsig asignatura${countAsig != 1 ? 's' : ''}',
                                  style: const TextStyle(fontSize: 11)),
                              trailing: puedeEditar
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined,
                                              color: kPrimary, size: 18),
                                          onPressed: () => _dialogArea(a),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline,
                                              color: kDanger, size: 18),
                                          onPressed: () =>
                                              _eliminarArea(a['id'].toString()),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    )
                                  : null,
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // ── Columna Asignaturas ──────────────────────────────────────
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Text('ASIGNATURAS',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold,
                                color: kTextMuted, letterSpacing: 1.2)),
                        const Spacer(),
                        if (puedeEditar)
                          TextButton.icon(
                            onPressed: () => _dialogAsignatura(),
                            icon: const Icon(Icons.add, size: 14),
                            label: const Text('Nueva', style: TextStyle(fontSize: 12)),
                          ),
                      ]),
                      const SizedBox(height: 8),
                      if (_asignaturas.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('Sin asignaturas registradas',
                              style: TextStyle(color: kTextMuted, fontSize: 13)),
                        )
                      else
                        ..._asignaturas.map((s) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                dense: true,
                                leading: const CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Color(0x1A007BFF),
                                  child: Icon(Icons.school_outlined,
                                      color: kPrimary, size: 14),
                                ),
                                title: Text(s['nombre_asignatura']?.toString() ?? '',
                                    style: const TextStyle(
                                        fontSize: 13, fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                    s['nombre_area']?.toString() ?? '',
                                    style: const TextStyle(
                                        fontSize: 11, color: kTextMuted)),
                                trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Botón Guías
                                      Tooltip(
                                        message: 'Gestionar guías',
                                        child: TextButton.icon(
                                          onPressed: () => showDialog(
                                            context: context,
                                            builder: (_) => _GuiasDialog(
                                              asignatura: s,
                                              puedeEditar: puedeEditar,
                                            ),
                                          ),
                                          icon: const Icon(Icons.menu_book_outlined,
                                              size: 14, color: kPrimary),
                                          label: Text(
                                            'Guías ${s['total_guias'] != null ? '(${s['total_guias']})' : ''}',
                                            style: const TextStyle(
                                                fontSize: 11, color: kPrimary),
                                          ),
                                          style: TextButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 2)),
                                        ),
                                      ),
                                      if (puedeEditar) ...[
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined,
                                              color: kPrimary, size: 18),
                                          onPressed: () => _dialogAsignatura(s),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline,
                                              color: kDanger, size: 18),
                                          onPressed: () => _eliminarAsignatura(
                                              s['id'].toString()),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ],
                                  ),
                              ),
                            )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Diálogo: seleccionar encargado ────────────────────────────────────────────

class _SelectorEncargadoDialog extends StatelessWidget {
  final List<Map<String, dynamic>> opciones;
  const _SelectorEncargadoDialog({required this.opciones});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar encargado', style: TextStyle(color: kPrimary)),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      content: SizedBox(
        width: 300,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: opciones.length,
          itemBuilder: (_, i) {
            final u = opciones[i];
            final rol = u['rol']?.toString() ?? '';
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: rol == 'LAB' ? kSuccess : kPrimary,
                child: Text(
                  (u['username'] as String).substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(u['nombre_completo']?.toString() ?? u['username'],
                  style: const TextStyle(fontSize: 13)),
              subtitle: Text('@${u['username']} · $rol',
                  style: const TextStyle(fontSize: 11, color: kTextMuted)),
              onTap: () => Navigator.pop(context, u),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      ],
    );
  }
}

// ── Diálogo: agregar asignatura ───────────────────────────────────────────────

class _FormAsignaturaDialog extends StatefulWidget {
  final List<Map<String, dynamic>> asignaturas;
  const _FormAsignaturaDialog({required this.asignaturas});
  @override State<_FormAsignaturaDialog> createState() => _FormAsignaturaDialogState();
}

class _FormAsignaturaDialogState extends State<_FormAsignaturaDialog> {
  String?  _asignaturaId;
  final _docenteCtrl = TextEditingController();
  final _grupoCtrl   = TextEditingController();

  @override
  void dispose() { _docenteCtrl.dispose(); _grupoCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar asignatura', style: TextStyle(color: kPrimary)),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _asignaturaId,
              decoration: const InputDecoration(
                labelText: 'Asignatura *',
                prefixIcon: Icon(Icons.school_outlined, color: kPrimary),
                border: OutlineInputBorder(),
              ),
              items: widget.asignaturas.map((a) => DropdownMenuItem(
                value: a['id'].toString(),
                child: Text(a['nombre_asignatura'].toString(), overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (v) => setState(() => _asignaturaId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _docenteCtrl,
              decoration: const InputDecoration(
                labelText: 'Docente',
                prefixIcon: Icon(Icons.person_outline, color: kPrimary),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _grupoCtrl,
              decoration: const InputDecoration(
                labelText: 'Grupo (ej. G-01)',
                prefixIcon: Icon(Icons.group_outlined, color: kPrimary),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary, foregroundColor: Colors.white),
          onPressed: _asignaturaId == null ? null : () {
            Navigator.pop(context, {
              'asignatura_id': _asignaturaId,
              'docente': _docenteCtrl.text.trim(),
              'grupo':   _grupoCtrl.text.trim(),
            });
          },
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}
