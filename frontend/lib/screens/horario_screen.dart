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

String _horaAmPm(int hora) {
  if (hora == 12) return '12 PM';
  if (hora > 12) return '${hora - 12} PM';
  return '$hora AM';
}

const double _colWidth   = 140;
const double _labelWidth = 54;
const double _rowHeight  = 40;

// ── Bloque fusionado de asignatura ────────────────────────────────────────────

class _Bloque {
  final int horaIdx;   // índice en _horas (0-based)
  final int duracion;  // cantidad de horas consecutivas
  // items de CADA hora del bloque: itemsByHora[k] = items de la hora horaIdx+k
  final List<List<Map<String, dynamic>>> itemsByHora;

  const _Bloque(this.horaIdx, this.duracion, this.itemsByHora);
}

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
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tab,
              labelColor: kPrimary,
              unselectedLabelColor: kTextMuted,
              indicatorColor: kPrimary,
              indicatorWeight: 2,
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              tabs: const [
                Tab(height: 36, child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.person_pin_outlined, size: 15),
                  SizedBox(width: 5),
                  Text('Encargados',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ])),
                Tab(height: 36, child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.school_outlined, size: 15),
                  SizedBox(width: 5),
                  Text('Asignaturas',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ])),
                Tab(height: 36, child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.category_outlined, size: 15),
                  SizedBox(width: 5),
                  Text('Gestión',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ])),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: const [
                _TabEncargados(),
                _TabAsignaturas(),
                _TabGestion(),
              ],
            ),
          ),
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
    if (!mounted) return;
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
    if (!mounted) return;
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
      if (!mounted) return;
      setState(() => _grid = grid);
    } catch (_) {}

    try {
      final resp = await dio.get('academico/encargados-disponibles/');
      final disponibles = List<Map<String, dynamic>>.from(
          resp.data is List ? resp.data : (resp.data['results'] ?? []));
      if (!mounted) return;
      setState(() => _disponibles = disponibles);
    } catch (_) {}

    if (!mounted) return;
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
      builder: (_) => _SelectorEncargadoDialog(opciones: opciones, horaInicio: hora),
    );
    if (sel == null || !mounted) return;

    final horaFin = sel['hora_fin'] as int? ?? hora;
    final dio = ApiClient.instance.authenticatedDio(auth.token);
    for (int h = hora; h <= horaFin; h++) {
      // No crear si ya hay un slot para este usuario en esta hora
      final yaEsta = _grid[dia]?[h]?.any((e) => e['usuario'] == sel['id']) ?? false;
      if (yaEsta) continue;
      try {
        final r = await dio.post('academico/horario-encargado/', data: {
          'usuario': sel['id'],
          'dia_semana': dia,
          'hora': h,
        });
        if (mounted) setState(() => _grid[dia]?[h]?.add(r.data as Map<String, dynamic>));
      } catch (_) {}
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

  Future<void> _editarEncargado(int dia, int hora, Map<String, dynamic> item) async {
    final auth = context.read<AuthProvider>();
    if (!auth.can(Perm.academicoGestionar)) return;

    final accion = await showDialog<String>(
      context: context,
      builder: (_) {
        final nombre = item['nombre_completo']?.toString() ?? item['username']?.toString() ?? '?';
        final rol    = item['rol']?.toString() ?? '';
        return AlertDialog(
          title: Text(nombre, style: const TextStyle(color: kPrimary, fontSize: 15)),
          content: Text('$rol · ${_dias[dia]} ${_horaAmPm(hora)}',
              style: const TextStyle(color: kTextMuted, fontSize: 12)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            TextButton(
              onPressed: () => Navigator.pop(context, 'cambiar'),
              child: const Text('Cambiar encargado'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'quitar'),
              child: const Text('Quitar', style: TextStyle(color: kDanger)),
            ),
          ],
        );
      },
    );
    if (!mounted) return;

    if (accion == 'quitar') {
      await _eliminar(dia, hora, item);
    } else if (accion == 'cambiar') {
      final yaAsignados = _grid[dia]?[hora]?.map((e) => e['usuario'] as int).toSet() ?? {};
      final opciones = _disponibles.where((u) => !yaAsignados.contains(u['id'] as int)).toList();
      if (opciones.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay otros encargados disponibles para este bloque.')));
        return;
      }
      final sel = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => _SelectorEncargadoDialog(opciones: opciones, horaInicio: hora),
      );
      if (sel == null || !mounted) return;
      final dio = ApiClient.instance.authenticatedDio(auth.token);
      try {
        final r = await dio.patch('academico/horario-encargado/${item['id']}/', data: {
          'usuario': sel['id'],
          'dia_semana': dia,
          'hora': hora,
        });
        setState(() {
          final list = _grid[dia]?[hora];
          if (list != null) {
            final idx = list.indexWhere((e) => e['id'] == item['id']);
            if (idx >= 0) list[idx] = r.data as Map<String, dynamic>;
          }
        });
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al actualizar'), backgroundColor: kDanger));
      }
    }
  }

  // Tabla de conteo de horas por encargado
  Widget _buildTablaHoras() {
    // Contar cuántas celdas aparece cada usuario en el grid
    final conteo = <int, int>{};
    final nombres = <int, String>{};
    final roles   = <int, String>{};
    for (final diaMap in _grid.values) {
      for (final items in diaMap.values) {
        for (final item in items) {
          final uid = item['usuario'] as int? ?? item['id'] as int? ?? 0;
          conteo[uid] = (conteo[uid] ?? 0) + 1;
          nombres[uid] ??= item['nombre_completo']?.toString() ?? item['username']?.toString() ?? '?';
          roles[uid]   ??= item['rol']?.toString() ?? '';
        }
      }
    }
    if (conteo.isEmpty) return const SizedBox.shrink();

    final sorted = conteo.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 24),
          const Text('HORAS SEMANALES POR ENCARGADO',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                  color: kTextMuted, letterSpacing: 1.1)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFDEE2E6)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(1),
                2: IntrinsicColumnWidth(),
              },
              children: [
                TableRow(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text('Encargado', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kTextMuted)),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Text('Rol', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kTextMuted)),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('Horas', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kTextMuted)),
                    ),
                  ],
                ),
                ...sorted.map((e) {
                  final uid   = e.key;
                  final horas = e.value;
                  final nombre = nombres[uid] ?? '?';
                  final rol    = roles[uid]   ?? '';
                  final color  = rol == 'LAB' ? kSuccess : (rol == 'ADMIN' ? kWarning : kPrimary);
                  return TableRow(
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFDEE2E6))),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text(nombre, style: const TextStyle(fontSize: 12)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(rol,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text('$horas h',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kPrimary)),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _buildGrid(puedeEditar),
                ),
                _buildTablaHoras(),
              ],
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
          ..._dias.map((d) => Container(
            width: _colWidth,
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: kPrimary,
            alignment: Alignment.center,
            child: Text(d,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          )),
        ]),
        const Divider(height: 1, thickness: 1, color: Color(0xFFDEE2E6)),
        // Filas de horas
        ..._horas.map((h) => _buildHoraRow(h, puedeEditar)),
      ],
    );
  }

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
            child: Text(_horaAmPm(hora),
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
      onTap: puedeEditar ? () => _editarEncargado(dia, hora, item) : null,
      child: Tooltip(
        message: '$nombre ($rol)',
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
  List<Map<String, dynamic>> _docentes    = [];
  bool _cargando = true;

  @override
  void initState() { super.initState(); Future.microtask(_cargar); }

  Future<void> _cargar() async {
    if (!mounted) return;
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
      if (!mounted) return;
      setState(() => _grid = grid);
    } catch (_) {}

    try {
      final resp = await dio.get('academico/asignaturas/');
      final asignaturas = List<Map<String, dynamic>>.from(
          resp.data is List ? resp.data : (resp.data['results'] ?? []));
      if (!mounted) return;
      setState(() => _asignaturas = asignaturas);
    } catch (_) {}

    try {
      final resp = await dio.get('academico/docentes/');
      final docentes = List<Map<String, dynamic>>.from(
          resp.data is List ? resp.data : (resp.data['results'] ?? []));
      if (!mounted) return;
      setState(() => _docentes = docentes.where((d) => d['activo'] == true).toList());
    } catch (_) {}

    if (!mounted) return;
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
      builder: (_) => _FormAsignaturaDialog(
          asignaturas: _asignaturas, docentes: _docentes, horaInicio: hora),
    );
    if (result == null || !mounted) return;

    final horaFin = result['hora_fin'] as int? ?? hora;
    final dio = ApiClient.instance.authenticatedDio(auth.token);
    for (int h = hora; h <= horaFin; h++) {
      try {
        final r = await dio.post('academico/horario-asignatura/', data: {
          'asignatura': result['asignatura_id'],
          'dia_semana': dia,
          'hora': h,
          'docente': result['docente'],
          'grupo': result['grupo'],
        });
        if (mounted) setState(() => _grid[dia]?[h]?.add(r.data as Map<String, dynamic>));
      } catch (_) {}
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

  // ── Calcular bloques fusionados para un día ──────────────────────────────────

  List<_Bloque> _computeBloques(int dia) {
    final result = <_Bloque>[];
    int i = 0;
    while (i < _horas.length) {
      final hora  = _horas[i];
      final items = _grid[dia]?[hora] ?? [];
      if (items.isEmpty) { i++; continue; }

      if (items.length == 1) {
        final item    = items[0];
        final asigId  = item['asignatura']?.toString();
        final docente = item['docente']?.toString() ?? '';
        final grupo   = item['grupo']?.toString() ?? '';
        int dur = 1;
        final byHora = [List<Map<String, dynamic>>.from(items)];

        while (i + dur < _horas.length) {
          final next = _grid[dia]?[_horas[i + dur]] ?? [];
          if (next.length == 1 &&
              next[0]['asignatura']?.toString() == asigId &&
              (next[0]['docente']?.toString() ?? '') == docente &&
              (next[0]['grupo']?.toString() ?? '') == grupo) {
            byHora.add(List<Map<String, dynamic>>.from(next));
            dur++;
          } else break;
        }
        result.add(_Bloque(i, dur, byHora));
        i += dur;
      } else {
        result.add(_Bloque(i, 1, [List<Map<String, dynamic>>.from(items)]));
        i++;
      }
    }
    return result;
  }

  Future<void> _eliminarBloque(int dia, _Bloque b) async {
    final auth = context.read<AuthProvider>();
    if (!auth.can(Perm.academicoGestionar)) return;
    final dio = ApiClient.instance.authenticatedDio(auth.token);
    for (int k = 0; k < b.duracion; k++) {
      final hora = _horas[b.horaIdx + k];
      for (final item in b.itemsByHora[k]) {
        try {
          await dio.delete('academico/horario-asignatura/${item['id']}/');
          setState(() => _grid[dia]?[hora]?.removeWhere((e) => e['id'] == item['id']));
        } catch (_) {}
      }
    }
  }

  Future<void> _editarBloque(int dia, _Bloque b) async {
    final auth = context.read<AuthProvider>();
    if (!auth.can(Perm.academicoGestionar)) return;
    final item = b.itemsByHora[0][0];

    final accion = await showDialog<String>(
      context: context,
      builder: (_) {
        final nombre   = item['nombre_asignatura']?.toString() ?? '?';
        final docente  = item['docente']?.toString() ?? '';
        final grupo    = item['grupo']?.toString() ?? '';
        final subtitle = [if (docente.isNotEmpty) docente, if (grupo.isNotEmpty) grupo].join(' · ');
        return AlertDialog(
          title: Text(nombre, style: const TextStyle(color: kPrimary, fontSize: 15)),
          content: Text(
            '${_dias[dia]} ${_horaAmPm(_horas[b.horaIdx])}'
            '${b.duracion > 1 ? ' · ${b.duracion}h' : ''}'
            '${subtitle.isNotEmpty ? '\n$subtitle' : ''}',
            style: const TextStyle(color: kTextMuted, fontSize: 12),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            TextButton(
              onPressed: () => Navigator.pop(context, 'editar'),
              child: const Text('Editar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'quitar'),
              child: const Text('Quitar', style: TextStyle(color: kDanger)),
            ),
          ],
        );
      },
    );
    if (!mounted) return;

    if (accion == 'quitar') {
      await _eliminarBloque(dia, b);
    } else if (accion == 'editar') {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => _FormAsignaturaDialog(
          asignaturas: _asignaturas,
          docentes: _docentes,
          initialAsignaturaId: item['asignatura']?.toString(),
          initialDocente: item['docente']?.toString() ?? '',
          initialGrupo:   item['grupo']?.toString()   ?? '',
        ),
      );
      if (result == null || !mounted) return;
      final dio = ApiClient.instance.authenticatedDio(auth.token);
      // Actualizar todas las filas del bloque con los nuevos datos
      for (int k = 0; k < b.duracion; k++) {
        final hora    = _horas[b.horaIdx + k];
        final rowItem = b.itemsByHora[k][0];
        try {
          final r = await dio.patch('academico/horario-asignatura/${rowItem['id']}/', data: {
            'asignatura': result['asignatura_id'],
            'docente':    result['docente'],
            'grupo':      result['grupo'],
          });
          setState(() {
            final list = _grid[dia]?[hora];
            if (list != null) {
              final idx = list.indexWhere((e) => e['id'] == rowItem['id']);
              if (idx >= 0) list[idx] = r.data as Map<String, dynamic>;
            }
          });
        } catch (_) {}
      }
    }
  }

  Future<void> _editarItem(int dia, int hora, Map<String, dynamic> item) async {
    final auth = context.read<AuthProvider>();
    if (!auth.can(Perm.academicoGestionar)) return;

    final accion = await showDialog<String>(
      context: context,
      builder: (_) {
        final nombre  = item['nombre_asignatura']?.toString() ?? '?';
        final docente = item['docente']?.toString() ?? '';
        final grupo   = item['grupo']?.toString() ?? '';
        final subtitle = [if (docente.isNotEmpty) docente, if (grupo.isNotEmpty) grupo].join(' · ');
        return AlertDialog(
          title: Text(nombre, style: const TextStyle(color: kPrimary, fontSize: 15)),
          content: Text(
            '${_dias[dia]} ${_horaAmPm(hora)}${subtitle.isNotEmpty ? '\n$subtitle' : ''}',
            style: const TextStyle(color: kTextMuted, fontSize: 12),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.pop(context, 'editar'), child: const Text('Editar')),
            TextButton(
              onPressed: () => Navigator.pop(context, 'quitar'),
              child: const Text('Quitar', style: TextStyle(color: kDanger)),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    if (accion == 'quitar') {
      await _eliminar(dia, hora, item);
    } else if (accion == 'editar') {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => _FormAsignaturaDialog(
          asignaturas: _asignaturas,
          docentes: _docentes,
          initialAsignaturaId: item['asignatura']?.toString(),
          initialDocente: item['docente']?.toString() ?? '',
          initialGrupo:   item['grupo']?.toString()   ?? '',
        ),
      );
      if (result == null || !mounted) return;
      final dio = ApiClient.instance.authenticatedDio(auth.token);
      try {
        final r = await dio.patch('academico/horario-asignatura/${item['id']}/', data: {
          'asignatura': result['asignatura_id'],
          'docente':    result['docente'],
          'grupo':      result['grupo'],
        });
        setState(() {
          final list = _grid[dia]?[hora];
          if (list != null) {
            final idx = list.indexWhere((e) => e['id'] == item['id']);
            if (idx >= 0) list[idx] = r.data as Map<String, dynamic>;
          }
        });
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al actualizar'), backgroundColor: kDanger));
      }
    }
  }

  // ── Grid con layout Stack (soporta celdas fusionadas) ────────────────────────

  Widget _buildGrid(bool puedeEditar) {
    final totalH = _horas.length * _rowHeight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabecera días
        Row(children: [
          SizedBox(width: _labelWidth),
          ..._dias.asMap().entries.map((e) => Container(
            width: _colWidth,
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: kPrimary,
            alignment: Alignment.center,
            child: Text(_dias[e.key],
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          )),
        ]),
        const Divider(height: 1, thickness: 1, color: Color(0xFFDEE2E6)),
        // Cuerpo
        SizedBox(
          height: totalH.toDouble(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Columna de horas
              SizedBox(
                width: _labelWidth,
                child: Stack(
                  children: _horas.asMap().entries.map((e) => Positioned(
                    top: (e.key * _rowHeight).toDouble(),
                    left: 0, right: 0,
                    height: _rowHeight.toDouble(),
                    child: Container(
                      alignment: Alignment.topCenter,
                      padding: const EdgeInsets.only(top: 5),
                      decoration: const BoxDecoration(
                        border: Border(
                          right:  BorderSide(color: Color(0xFFDEE2E6)),
                          bottom: BorderSide(color: Color(0xFFDEE2E6)),
                        ),
                      ),
                      child: Text(
                        _horaAmPm(_horas[e.key]),
                        style: const TextStyle(
                            fontSize: 10, color: kTextMuted, fontWeight: FontWeight.w600),
                      ),
                    ),
                  )).toList(),
                ),
              ),
              // Columnas por día
              ...[0, 1, 2, 3, 4, 5].map((dia) => _buildDayCol(dia, puedeEditar)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDayCol(int dia, bool puedeEditar) {
    final totalH  = _horas.length * _rowHeight;
    final bloques  = _computeBloques(dia);
    final occupied = {
      for (final b in bloques)
        for (int k = 0; k < b.duracion; k++) b.horaIdx + k,
    };

    return SizedBox(
      width: _colWidth,
      height: totalH.toDouble(),
      child: Stack(
        children: [
          // Fondo por hora (líneas de grilla + toque para agregar)
          ...List.generate(_horas.length, (i) {
            final empty = !occupied.contains(i);
            return Positioned(
              top: (i * _rowHeight).toDouble(),
              left: 0, right: 0,
              height: _rowHeight.toDouble(),
              child: GestureDetector(
                onTap: (puedeEditar && empty) ? () => _agregar(dia, _horas[i]) : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: dia.isOdd ? const Color(0xFFF8F9FA) : Colors.white,
                    border: const Border(
                      right:  BorderSide(color: Color(0xFFDEE2E6)),
                      bottom: BorderSide(color: Color(0xFFDEE2E6)),
                    ),
                  ),
                  child: (puedeEditar && empty)
                      ? const Center(
                          child: Icon(Icons.add_circle_outline,
                              size: 13, color: Color(0xFFDDDDDD)))
                      : null,
                ),
              ),
            );
          }),
          // Bloques de contenido (fusionados cuando hay horas consecutivas iguales)
          ...bloques.map((b) => Positioned(
            top:    (b.horaIdx * _rowHeight).toDouble() + 1,
            left:   2,
            right:  2,
            height: (b.duracion * _rowHeight).toDouble() - 2,
            child:  _buildBloqueWidget(b, dia, puedeEditar),
          )),
        ],
      ),
    );
  }

  Widget _buildBloqueWidget(_Bloque b, int dia, bool puedeEditar) {
    final items = b.itemsByHora[0];
    if (items.length == 1) return _chipAsignatura(b, dia, puedeEditar);
    // Múltiples asignaturas en la misma hora
    return Wrap(
      spacing: 2, runSpacing: 2,
      children: items
          .map((item) => _chipSingle(item, dia, _horas[b.horaIdx], puedeEditar))
          .toList(),
    );
  }

  // Genera un color de borde para la asignatura basado en su nombre
  static Color _colorBloque(String nombre) {
    final hash = nombre.codeUnits.fold(0, (a, b) => a + b);
    const palette = [kPrimary, Color(0xFF6F42C1), Color(0xFF28A745), Color(0xFF17A2B8), Color(0xFFE65100)];
    return palette[hash % palette.length];
  }

  // Chip para un bloque (posiblemente fusionado)
  Widget _chipAsignatura(_Bloque b, int dia, bool puedeEditar) {
    final item     = b.itemsByHora[0][0];
    final nombre   = item['nombre_asignatura']?.toString() ?? '?';
    final docente  = item['docente']?.toString() ?? '';
    final grupo    = item['grupo']?.toString() ?? '';
    final subtitle = [if (docente.isNotEmpty) docente, if (grupo.isNotEmpty) grupo].join(' · ');
    final isMulti  = b.duracion > 1;
    final color    = _colorBloque(nombre);

    return GestureDetector(
      onTap: puedeEditar ? () => _editarBloque(dia, b) : null,
      child: Tooltip(
        message: '$nombre${subtitle.isNotEmpty ? '\n$subtitle' : ''}'
            '${isMulti ? '\n${b.duracion} horas consecutivas' : ''}',
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border(
              left:   BorderSide(color: color, width: 3),
              top:    const BorderSide(color: Color(0xFFDEE2E6)),
              right:  const BorderSide(color: Color(0xFFDEE2E6)),
              bottom: const BorderSide(color: Color(0xFFDEE2E6)),
            ),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(children: [
                Expanded(
                  child: Text(nombre,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                      overflow: TextOverflow.ellipsis,
                      maxLines: isMulti ? 2 : 1),
                ),
                if (isMulti) ...[
                  const SizedBox(width: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9ECEF),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text('${b.duracion}h',
                        style: const TextStyle(fontSize: 8, color: kTextMuted, fontWeight: FontWeight.bold)),
                  ),
                ],
              ]),
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

  // Chip individual (para horas con múltiples asignaturas simultáneas)
  Widget _chipSingle(
      Map<String, dynamic> item, int dia, int hora, bool puedeEditar) {
    final nombre   = item['nombre_asignatura']?.toString() ?? '?';
    final docente  = item['docente']?.toString() ?? '';
    final grupo    = item['grupo']?.toString() ?? '';
    final subtitle = [if (docente.isNotEmpty) docente, if (grupo.isNotEmpty) grupo].join(' · ');
    final color    = _colorBloque(nombre);

    return GestureDetector(
      onTap: puedeEditar ? () => _editarItem(dia, hora, item) : null,
      child: Tooltip(
        message: '$nombre${subtitle.isNotEmpty ? '\n$subtitle' : ''}',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border(
              left:   BorderSide(color: color, width: 3),
              top:    const BorderSide(color: Color(0xFFDEE2E6)),
              right:  const BorderSide(color: Color(0xFFDEE2E6)),
              bottom: const BorderSide(color: Color(0xFFDEE2E6)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(nombre,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
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
    if (!mounted) return;
    setState(() => _cargando = true);
    final auth = context.read<AuthProvider>();
    final dio  = ApiClient.instance.authenticatedDio(auth.token);

    try {
      final r = await dio.get('academico/areas/');
      if (!mounted) return;
      setState(() => _areas = List<Map<String, dynamic>>.from(
          r.data is List ? r.data : (r.data['results'] ?? [])));
    } catch (_) {}

    try {
      final r = await dio.get('academico/asignaturas/');
      if (!mounted) return;
      setState(() => _asignaturas = List<Map<String, dynamic>>.from(
          r.data is List ? r.data : (r.data['results'] ?? [])));
    } catch (_) {}

    if (!mounted) return;
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
    if (!mounted) return;
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
    if (!mounted) return;
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
                  initialValue: areaId,
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
                            margin: const EdgeInsets.only(bottom: 4),
                            child: ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                              leading: const CircleAvatar(
                                radius: 13,
                                backgroundColor: Color(0x1A007BFF),
                                child: Icon(Icons.category_outlined,
                                    color: kPrimary, size: 13),
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
                              margin: const EdgeInsets.only(bottom: 4),
                              child: ListTile(
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                leading: const CircleAvatar(
                                  radius: 13,
                                  backgroundColor: Color(0x1A007BFF),
                                  child: Icon(Icons.school_outlined,
                                      color: kPrimary, size: 13),
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

class _SelectorEncargadoDialog extends StatefulWidget {
  final List<Map<String, dynamic>> opciones;
  final int horaInicio;
  const _SelectorEncargadoDialog({required this.opciones, required this.horaInicio});
  @override
  State<_SelectorEncargadoDialog> createState() => _SelectorEncargadoDialogState();
}

class _SelectorEncargadoDialogState extends State<_SelectorEncargadoDialog> {
  Map<String, dynamic>? _seleccionado;
  int? _horaFin;

  @override
  Widget build(BuildContext context) {
    final horasFin = [
      for (int h = widget.horaInicio; h <= 21; h++) h
    ];

    return AlertDialog(
      title: const Text('Agregar encargado', style: TextStyle(color: kPrimary)),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Hora de fin
            DropdownButtonFormField<int>(
              value: _horaFin ?? widget.horaInicio,
              decoration: const InputDecoration(
                labelText: 'Hora de fin',
                prefixIcon: Icon(Icons.schedule_outlined, color: kPrimary),
                border: OutlineInputBorder(),
              ),
              items: horasFin.map((h) => DropdownMenuItem(
                value: h,
                child: Text(_horaAmPm(h)),
              )).toList(),
              onChanged: (v) => setState(() => _horaFin = v),
            ),
            const SizedBox(height: 8),
            // Lista de encargados
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.opciones.length,
                itemBuilder: (_, i) {
                  final u   = widget.opciones[i];
                  final rol = u['rol']?.toString() ?? '';
                  final sel = _seleccionado?['id'] == u['id'];
                  return ListTile(
                    dense: true,
                    selected: sel,
                    selectedTileColor: kPrimary.withValues(alpha: 0.08),
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: sel ? kPrimary : (rol == 'LAB' ? kSuccess : kPrimary).withValues(alpha: 0.7),
                      child: Text(
                        (u['username'] as String).substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(u['nombre_completo']?.toString() ?? u['username'],
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text('@${u['username']} · $rol',
                        style: const TextStyle(fontSize: 11, color: kTextMuted)),
                    trailing: sel ? const Icon(Icons.check_circle, color: kPrimary, size: 18) : null,
                    onTap: () => setState(() => _seleccionado = u),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
          onPressed: _seleccionado == null ? null : () {
            Navigator.pop(context, {
              ..._seleccionado!,
              'hora_fin': _horaFin ?? widget.horaInicio,
            });
          },
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}

// ── Diálogo: agregar / editar asignatura en horario ──────────────────────────

const _kOtros = '__otros__';

class _FormAsignaturaDialog extends StatefulWidget {
  final List<Map<String, dynamic>> asignaturas;
  final List<Map<String, dynamic>> docentes;
  final String? initialAsignaturaId;
  final String  initialDocente;
  final String  initialGrupo;
  // null = modo edición (sin selector de hora de fin)
  final int?    horaInicio;
  const _FormAsignaturaDialog({
    required this.asignaturas,
    this.docentes            = const [],
    this.initialAsignaturaId,
    this.initialDocente      = '',
    this.initialGrupo        = '',
    this.horaInicio,
  });
  @override State<_FormAsignaturaDialog> createState() => _FormAsignaturaDialogState();
}

class _FormAsignaturaDialogState extends State<_FormAsignaturaDialog> {
  String?  _asignaturaId;
  String?  _docenteDropdown;
  int?     _horaFin;
  late final TextEditingController _docenteOtroCtrl;
  late final TextEditingController _grupoCtrl;

  @override
  void initState() {
    super.initState();
    _asignaturaId = widget.initialAsignaturaId;
    _horaFin      = widget.horaInicio;
    _grupoCtrl    = TextEditingController(text: widget.initialGrupo);
    _docenteOtroCtrl = TextEditingController();

    // Determinar si el valor inicial coincide con algún docente de la lista
    if (widget.initialDocente.isNotEmpty) {
      final match = widget.docentes.firstWhere(
        (d) => (d['nombre_completo'] as String? ?? '') == widget.initialDocente,
        orElse: () => {},
      );
      if (match.isNotEmpty) {
        _docenteDropdown = match['id'].toString();
      } else {
        _docenteDropdown = _kOtros;
        _docenteOtroCtrl.text = widget.initialDocente;
      }
    }
  }

  @override
  void dispose() {
    _docenteOtroCtrl.dispose();
    _grupoCtrl.dispose();
    super.dispose();
  }

  bool get _esEdicion => widget.initialAsignaturaId != null;

  String _nombreDocente() {
    if (_docenteDropdown == null) return '';
    if (_docenteDropdown == _kOtros) return _docenteOtroCtrl.text.trim();
    final doc = widget.docentes.firstWhere(
      (d) => d['id'].toString() == _docenteDropdown,
      orElse: () => {},
    );
    return doc['nombre_completo'] as String? ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final mostrarOtroField = _docenteDropdown == _kOtros;

    return AlertDialog(
      title: Text(_esEdicion ? 'Editar asignatura' : 'Agregar asignatura',
          style: const TextStyle(color: kPrimary)),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Asignatura
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
            // Docente — lista + Otros
            DropdownButtonFormField<String>(
              value: _docenteDropdown,
              decoration: const InputDecoration(
                labelText: 'Docente',
                prefixIcon: Icon(Icons.person_outline, color: kPrimary),
                border: OutlineInputBorder(),
              ),
              items: [
                ...widget.docentes.map((d) => DropdownMenuItem(
                  value: d['id'].toString(),
                  child: Text(d['nombre_completo']?.toString() ?? '',
                      overflow: TextOverflow.ellipsis),
                )),
                const DropdownMenuItem(
                  value: _kOtros,
                  child: Text('Otros...', style: TextStyle(color: kTextMuted, fontStyle: FontStyle.italic)),
                ),
              ],
              onChanged: (v) => setState(() {
                _docenteDropdown = v;
                if (v != _kOtros) _docenteOtroCtrl.clear();
              }),
            ),
            // Campo libre cuando se elige "Otros..."
            if (mostrarOtroField) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _docenteOtroCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nombre del docente',
                  prefixIcon: Icon(Icons.edit_outlined, color: kPrimary),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Hora de fin (solo al crear, no al editar)
            if (widget.horaInicio != null) ...[
              DropdownButtonFormField<int>(
                value: _horaFin ?? widget.horaInicio,
                decoration: const InputDecoration(
                  labelText: 'Hora de fin',
                  prefixIcon: Icon(Icons.schedule_outlined, color: kPrimary),
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (int h = widget.horaInicio!; h <= 21; h++)
                    DropdownMenuItem(value: h, child: Text(_horaAmPm(h)))
                ],
                onChanged: (v) => setState(() => _horaFin = v),
              ),
              const SizedBox(height: 12),
            ],
            // Grupo
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
              'docente':  _nombreDocente(),
              'grupo':    _grupoCtrl.text.trim(),
              'hora_fin': _horaFin ?? widget.horaInicio,
            });
          },
          child: Text(_esEdicion ? 'Guardar' : 'Agregar'),
        ),
      ],
    );
  }
}
