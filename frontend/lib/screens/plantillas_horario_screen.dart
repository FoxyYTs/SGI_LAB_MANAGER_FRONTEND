// Plantillas de horario: guardar el horario vigente con un nombre, listar
// las guardadas y aplicar una (reemplaza el horario vigente de forma
// atómica, con respaldo automático y confirmación previa).
// API: academico/plantillas-horario/ (requiere academico.gestionar).
//
// Al cerrar devuelve `true` si se aplicó alguna plantilla, para que el
// horario se recargue.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api/api_client.dart';
import '../core/horario_utils.dart';
import '../core/theme/colors.dart';
import '../providers/auth_provider.dart';
import '../widgets/horario_bloque_dialog.dart';

class PlantillasHorarioScreen extends StatefulWidget {
  const PlantillasHorarioScreen({super.key});
  @override
  State<PlantillasHorarioScreen> createState() => _PlantillasHorarioScreenState();
}

class _PlantillasHorarioScreenState extends State<PlantillasHorarioScreen> {
  List<Map<String, dynamic>> _plantillas = [];
  bool _cargando = true;
  bool _ocupado = false;
  bool _aplicada = false;
  bool _verRespaldos = false;
  String? _error;

  Dio get _dio => ApiClient.instance.authenticatedDio(context.read<AuthProvider>().token);

  @override
  void initState() {
    super.initState();
    Future.microtask(_cargar);
  }

  void _avisar(String msg, {bool error = false}) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? kDanger : kSuccess,
      duration: Duration(seconds: error ? 4 : 3),
    ));
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() { _cargando = true; _error = null; });
    try {
      final r = await _dio.get('academico/plantillas-horario/');
      if (!mounted) return;
      setState(() { _plantillas = ApiListas.listaDe(r.data); _cargando = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar las plantillas.';
        _cargando = false;
      });
    }
  }

  // ── Guardar el horario actual ─────────────────────────────────────────────

  Future<void> _guardarActual() async {
    final nombreCtrl = TextEditingController();
    bool enc = true, asg = true;
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSt) => AlertDialog(
          title: const Text('Guardar horario actual', style: TextStyle(color: kPrimary, fontSize: 16)),
          scrollable: true,
          content: SizedBox(
            width: 380,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: nombreCtrl,
                autofocus: true,
                maxLength: 150,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la plantilla',
                  hintText: 'Ej: Semestre 2026-2',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: enc,
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Encargados'),
                onChanged: (v) => setSt(() => enc = v ?? false),
              ),
              CheckboxListTile(
                value: asg,
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Asignaturas'),
                onChanged: (v) => setSt(() => asg = v ?? false),
              ),
              if (error != null)
                Text(error!, style: const TextStyle(color: kDanger, fontSize: 12)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
              onPressed: () {
                final msg = nombreCtrl.text.trim().isEmpty
                    ? 'Escribe un nombre'
                    : (!enc && !asg) ? 'Elige encargados, asignaturas o ambos' : null;
                if (msg != null) { setSt(() => error = msg); return; }
                Navigator.pop(ctx, true);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    final nombre = nombreCtrl.text.trim();
    nombreCtrl.dispose();
    if (ok != true || !mounted) return;

    setState(() => _ocupado = true);
    try {
      final r = await _dio.post('academico/plantillas-horario/', data: {
        'nombre': nombre,
        'incluye_encargados': enc,
        'incluye_asignaturas': asg,
      });
      final p = Map<String, dynamic>.from(r.data as Map);
      _avisar('Plantilla "$nombre" guardada '
          '(${p['total_encargados'] ?? 0} bloques de encargados, '
          '${p['total_asignaturas'] ?? 0} de asignaturas)');
      await _cargar();
    } on DioException catch (e) {
      _avisar(mensajeErrorApi(e.response?.data) ?? 'No se pudo guardar la plantilla.', error: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  // ── Aplicar ───────────────────────────────────────────────────────────────

  static String _partes(Map<String, dynamic> p) => [
        if (p['incluye_encargados'] == true) 'encargados',
        if (p['incluye_asignaturas'] == true) 'asignaturas',
      ].join(' y ');

  static String _omitidoTexto(Map<String, dynamic> o) {
    final n = o['bloques'] ?? 0;
    return '${o['nombre']} (${o['tipo']}, $n h): ${o['motivo']}';
  }

  Widget _listaOmitidos(List<Map<String, dynamic>> omitidos) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: omitidos
            .map((o) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('•  ', style: TextStyle(color: kWarning)),
                    Expanded(child: Text(_omitidoTexto(o), style: const TextStyle(fontSize: 12))),
                  ]),
                ))
            .toList(),
      );

  Future<void> _aplicar(Map<String, dynamic> p) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    Map<String, dynamic> prev;
    try {
      final r = await _dio.get('academico/plantillas-horario/${p['id']}/previsualizar/');
      prev = Map<String, dynamic>.from(r.data as Map);
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _ocupado = false);
        _avisar(mensajeErrorApi(e.response?.data) ?? 'No se pudo preparar la plantilla.', error: true);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _ocupado = false);

    final borrar = Map<String, dynamic>.from(prev['borrar'] as Map? ?? const {});
    final crear = Map<String, dynamic>.from(prev['crear'] as Map? ?? const {});
    final omitidos = ApiListas.listaDe(prev['omitidos']);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Aplicar "${p['nombre']}"', style: const TextStyle(color: kPrimary, fontSize: 16)),
        scrollable: true,
        content: SizedBox(
          width: 400,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Se reemplazará el horario vigente de ${_partes(p)}:',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
            _cifra(Icons.delete_outline, kDanger,
                'Se borran ${borrar['total'] ?? 0} bloques',
                'Encargados: ${borrar['encargados'] ?? 0} · Asignaturas: ${borrar['asignaturas'] ?? 0}'),
            const SizedBox(height: 6),
            _cifra(Icons.add_circle_outline, kSuccess,
                'Se crean ${crear['total'] ?? 0} bloques',
                'Encargados: ${crear['encargados'] ?? 0} · Asignaturas: ${crear['asignaturas'] ?? 0}'),
            if (omitidos.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Se omitirán:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF8A6D00))),
              const SizedBox(height: 4),
              _listaOmitidos(omitidos),
            ],
            const SizedBox(height: 12),
            const Text(
              'Antes de aplicar se guarda automáticamente un respaldo del horario actual '
              'en esta misma lista, por si necesitas volver atrás.',
              style: TextStyle(fontSize: 11, color: kTextMuted),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kDanger, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reemplazar horario'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _ocupado = true);
    final r = await postHorario(context, _dio, 'academico/plantillas-horario/${p['id']}/aplicar/', {});
    if (!mounted) return;
    setState(() => _ocupado = false);
    if (r == null) return;
    _aplicada = true;
    final omit = ApiListas.listaDe(r['omitidos']);
    final crearR = Map<String, dynamic>.from(r['crear'] as Map? ?? const {});
    final respaldo = r['respaldo'] is Map ? r['respaldo']['nombre']?.toString() : null;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.check_circle_outline, color: kSuccess),
          SizedBox(width: 8),
          Expanded(child: Text('Plantilla aplicada', style: TextStyle(fontSize: 16))),
        ]),
        scrollable: true,
        content: SizedBox(
          width: 400,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Se crearon ${crearR['total'] ?? 0} bloques.', style: const TextStyle(fontSize: 13)),
            if (respaldo != null) ...[
              const SizedBox(height: 6),
              Text('Respaldo guardado: $respaldo', style: const TextStyle(fontSize: 12, color: kTextMuted)),
            ],
            if (omit.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('Omitidos:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              _listaOmitidos(omit),
            ],
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido'))],
      ),
    );
    await _cargar();
  }

  Widget _cifra(IconData icono, Color color, String titulo, String detalle) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
              Text(detalle, style: const TextStyle(fontSize: 11, color: kTextMuted)),
            ]),
          ),
        ],
      );

  // ── Eliminar ──────────────────────────────────────────────────────────────

  Future<void> _eliminar(Map<String, dynamic> p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar plantilla'),
        content: Text('¿Eliminar "${p['nombre']}"? El horario vigente no cambia.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: kDanger)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _dio.delete('academico/plantillas-horario/${p['id']}/');
      if (!mounted) return;
      setState(() => _plantillas.removeWhere((x) => x['id'] == p['id']));
    } on DioException catch (e) {
      _avisar(mensajeErrorApi(e.response?.data) ?? 'No se pudo eliminar.', error: true);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  static String _fecha(dynamic iso) {
    final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
    if (d == null) return '';
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(d.day)}/${dos(d.month)}/${d.year} ${dos(d.hour)}:${dos(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final visibles = _plantillas.where((p) => _verRespaldos || p['es_respaldo'] != true).toList();
    final nRespaldos = _plantillas.where((p) => p['es_respaldo'] == true).length;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _aplicada);
      },
      child: Scaffold(
        backgroundColor: kBackground,
        appBar: AppBar(
          title: const Text('Plantillas de horario'),
          backgroundColor: Colors.white,
          foregroundColor: kPrimary,
          elevation: 0.5,
          bottom: _ocupado
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(2),
                  child: LinearProgressIndicator(minHeight: 2, color: kPrimary),
                )
              : null,
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          onPressed: _ocupado ? null : _guardarActual,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Guardar horario actual'),
        ),
        body: RefreshIndicator(
          onRefresh: _cargar,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Text(
                      'Guarda el horario vigente (p. ej. al cerrar un semestre) y vuelve a '
                      'aplicarlo cuando lo necesites. Aplicar reemplaza el horario actual; '
                      'antes se guarda un respaldo automático.',
                      style: TextStyle(fontSize: 12, color: kTextMuted),
                    ),
                    if (nRespaldos > 0)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilterChip(
                          label: Text('Ver respaldos automáticos ($nRespaldos)'),
                          selected: _verRespaldos,
                          visualDensity: VisualDensity.compact,
                          onSelected: (v) => setState(() => _verRespaldos = v),
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (_cargando)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator(color: kPrimary)),
                      )
                    else if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(children: [
                          Text(_error!, style: const TextStyle(color: kDanger)),
                          TextButton.icon(
                            onPressed: _cargar,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Reintentar'),
                          ),
                        ]),
                      )
                    else if (visibles.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text('Aún no hay plantillas guardadas.',
                              style: TextStyle(color: kTextMuted)),
                        ),
                      )
                    else
                      ...visibles.map(_tarjeta),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tarjeta(Map<String, dynamic> p) {
    final respaldo = p['es_respaldo'] == true;
    final autor = p['creada_por_nombre']?.toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0.5,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(respaldo ? Icons.history : Icons.bookmark_outline,
                color: respaldo ? kTextMuted : kPrimary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p['nombre']?.toString() ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(
                  [
                    _fecha(p['creada_en']),
                    if (autor != null && autor.isNotEmpty) autor,
                  ].join(' · '),
                  style: const TextStyle(fontSize: 11, color: kTextMuted),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            if (p['incluye_encargados'] == true)
              Chip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.person_pin_outlined, size: 14),
                label: Text('${p['total_encargados'] ?? 0} h de encargados',
                    style: const TextStyle(fontSize: 11)),
              ),
            if (p['incluye_asignaturas'] == true)
              Chip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.school_outlined, size: 14),
                label: Text('${p['total_asignaturas'] ?? 0} h de asignaturas',
                    style: const TextStyle(fontSize: 11)),
              ),
          ]),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(spacing: 4, children: [
              TextButton.icon(
                onPressed: _ocupado ? null : () => _eliminar(p),
                icon: const Icon(Icons.delete_outline, size: 16, color: kDanger),
                label: const Text('Eliminar', style: TextStyle(color: kDanger, fontSize: 12)),
              ),
              TextButton.icon(
                onPressed: _ocupado ? null : () => _aplicar(p),
                icon: const Icon(Icons.restore_page_outlined, size: 16),
                label: const Text('Aplicar', style: TextStyle(fontSize: 12)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
