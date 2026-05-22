import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    _tab = TabController(length: 2, vsync: this);
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
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _TabEncargados(),
          _TabAsignaturas(),
        ],
      ),
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
    try {
      final results = await Future.wait([
        dio.get('academico/horario-encargado/'),
        dio.get('academico/encargados-disponibles/'),
      ]);
      final registros = List<Map<String, dynamic>>.from(
          results[0].data is List ? results[0].data : (results[0].data['results'] ?? []));
      final disponibles = List<Map<String, dynamic>>.from(
          results[1].data is List ? results[1].data : (results[1].data['results'] ?? []));

      final Map<int, Map<int, List<Map<String, dynamic>>>> grid = {
        for (final d in [0,1,2,3,4,5]) d: {for (final h in _horas) h: []},
      };
      for (final r in registros) {
        final dia  = r['dia_semana'] as int;
        final hora = r['hora'] as int;
        grid[dia]?[hora]?.add(r);
      }
      setState(() { _grid = grid; _disponibles = disponibles; _cargando = false; });
    } catch (_) {
      setState(() => _cargando = false);
    }
  }

  Future<void> _agregar(int dia, int hora) async {
    final auth = context.read<AuthProvider>();
    if (!auth.can(Perm.academicoGestionar)) return;

    // Excluir los que ya están en este slot
    final yaAsignados = _grid[dia]?[hora]?.map((e) => e['usuario'] as int).toSet() ?? {};
    final opciones = _disponibles.where((u) => !yaAsignados.contains(u['id'])).toList();

    if (opciones.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Todos los encargados ya están asignados en este bloque.')));
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: _buildGrid(puedeEditar),
      ),
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
      final results = await Future.wait([
        dio.get('academico/horario-asignatura/'),
        dio.get('academico/asignaturas/'),
      ]);
      final registros = List<Map<String, dynamic>>.from(
          results[0].data is List ? results[0].data : (results[0].data['results'] ?? []));
      final asignaturas = List<Map<String, dynamic>>.from(
          results[1].data is List ? results[1].data : (results[1].data['results'] ?? []));

      final Map<int, Map<int, List<Map<String, dynamic>>>> grid = {
        for (final d in [0,1,2,3,4,5]) d: {for (final h in _horas) h: []},
      };
      for (final r in registros) {
        final dia  = r['dia_semana'] as int;
        final hora = r['hora'] as int;
        grid[dia]?[hora]?.add(r);
      }
      setState(() { _grid = grid; _asignaturas = asignaturas; _cargando = false; });
    } catch (_) {
      setState(() => _cargando = false);
    }
  }

  Future<void> _agregar(int dia, int hora) async {
    final auth = context.read<AuthProvider>();
    if (!auth.can(Perm.academicoGestionar)) return;

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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: _buildGrid(puedeEditar),
      ),
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
