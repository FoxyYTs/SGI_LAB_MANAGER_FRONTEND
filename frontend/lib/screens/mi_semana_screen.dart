// "Mi semana": bloques de la semana de un monitor agrupados por día, horas
// en casa, horas registradas y avance hacia la meta semanal.
// Lee GET academico/mi-semana/ (un monitor solo puede ver la suya; quien
// gestiona el horario puede elegir cualquier monitor).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api/api_client.dart';
import '../core/horario_utils.dart';
import '../core/theme/colors.dart';
import '../providers/auth_provider.dart';

DateTime _lunesDe(DateTime d) =>
    DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

String _fechaIso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class MiSemanaScreen extends StatefulWidget {
  /// Monitor a mostrar; null = el usuario autenticado.
  final int? usuarioId;
  /// Muestra el selector de monitor (solo para quien gestiona el horario).
  final bool puedeElegir;

  const MiSemanaScreen({super.key, this.usuarioId, this.puedeElegir = false});

  @override
  State<MiSemanaScreen> createState() => _MiSemanaScreenState();
}

class _MiSemanaScreenState extends State<MiSemanaScreen> {
  DateTime _lunes = _lunesDe(DateTime.now());
  int? _usuarioId;
  List<Map<String, dynamic>> _monitores = [];
  MiSemana? _semana;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _usuarioId = widget.usuarioId;
    Future.microtask(() async {
      if (widget.puedeElegir) await _cargarMonitores();
      await _cargar();
    });
  }

  Future<void> _cargarMonitores() async {
    final auth = context.read<AuthProvider>();
    final dio = ApiClient.instance.authenticatedDio(auth.token);
    try {
      final r = await dio.get('academico/seguimiento-monitores/',
          queryParameters: {'semana': _fechaIso(_lunes)});
      final lista = ApiListas.listaDe(r.data is Map ? r.data['monitores'] : null);
      if (!mounted) return;
      setState(() => _monitores = lista);
    } catch (_) {
      // Sin la lista igual se puede ver la propia semana.
    }
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() { _cargando = true; _error = null; });
    final auth = context.read<AuthProvider>();
    final dio = ApiClient.instance.authenticatedDio(auth.token);
    try {
      final r = await dio.get('academico/mi-semana/', queryParameters: {
        'semana': _fechaIso(_lunes),
        if (_usuarioId != null) 'usuario': _usuarioId,
      });
      if (!mounted) return;
      setState(() {
        _semana = MiSemana.desdeJson(Map<String, dynamic>.from(r.data as Map));
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar la semana. Revisa la conexión e intenta de nuevo.';
        _cargando = false;
      });
    }
  }

  void _cambiarSemana(int dias) {
    setState(() => _lunes = _lunes.add(Duration(days: dias)));
    _cargar();
  }

  String _rangoSemana() {
    final fin = _lunes.add(const Duration(days: 5));
    String f(DateTime d) => '${d.day}/${d.month}';
    return 'Semana del ${f(_lunes)} al ${f(fin)}';
  }

  @override
  Widget build(BuildContext context) {
    final esActual = _lunes == _lunesDe(DateTime.now());
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: Text(_semana != null && _usuarioId != null ? _semana!.nombre : 'Mi semana'),
        backgroundColor: Colors.white,
        foregroundColor: kPrimary,
        elevation: 0.5,
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (widget.puedeElegir && _monitores.isNotEmpty) ...[
                    DropdownButtonFormField<int?>(
                      initialValue: _usuarioId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Monitor',
                        prefixIcon: Icon(Icons.person_search_outlined, color: kPrimary),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('Mi semana')),
                        ..._monitores.map((m) => DropdownMenuItem<int?>(
                              value: m['usuario'] as int?,
                              child: Text(m['nombre_completo']?.toString() ?? '?',
                                  overflow: TextOverflow.ellipsis),
                            )),
                        // Persona abierta desde otra pantalla que no está en
                        // la lista de monitores (el dropdown exige su valor).
                        if (_usuarioId != null && !_monitores.any((m) => m['usuario'] == _usuarioId))
                          DropdownMenuItem<int?>(
                            value: _usuarioId,
                            child: Text(_semana?.nombre ?? 'Usuario $_usuarioId',
                                overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (v) {
                        setState(() => _usuarioId = v);
                        _cargar();
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(children: [
                    IconButton(
                      tooltip: 'Semana anterior',
                      icon: const Icon(Icons.chevron_left, color: kPrimary),
                      onPressed: () => _cambiarSemana(-7),
                    ),
                    Expanded(
                      child: Text(_rangoSemana(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    IconButton(
                      tooltip: 'Semana siguiente',
                      icon: const Icon(Icons.chevron_right, color: kPrimary),
                      onPressed: () => _cambiarSemana(7),
                    ),
                  ]),
                  if (!esActual)
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() => _lunes = _lunesDe(DateTime.now()));
                          _cargar();
                        },
                        icon: const Icon(Icons.today_outlined, size: 16),
                        label: const Text('Ir a esta semana', style: TextStyle(fontSize: 12)),
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
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: kDanger)),
                        TextButton.icon(
                          onPressed: _cargar,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Reintentar'),
                        ),
                      ]),
                    )
                  else if (_semana != null)
                    ..._contenido(_semana!),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _contenido(MiSemana s) {
    final f = s.horas;
    final colorAvance = f.cumple ? kSuccess : kWarning;
    return [
      MiSemanaResumenCard(semana: s),
      const SizedBox(height: 16),
      _seccion('TURNOS PRESENCIALES', Icons.calendar_month_outlined, [
        if (s.rangos.isEmpty)
          const _Vacio('Sin turnos asignados en el horario.')
        else
          for (final e in s.rangosPorDia.entries)
            _fila(
              kNombresDia[e.key],
              e.value.map((r) => r.texto).join('  ·  '),
              formatoHoras(e.value.fold<double>(0, (a, r) => a + r.duracion)),
            ),
      ]),
      _seccion('HORAS EN CASA', Icons.home_work_outlined, [
        if (s.enCasa.isEmpty)
          const _Vacio('Sin horas en casa asignadas.')
        else
          for (final e in s.enCasa)
            _fila(e['descripcion']?.toString() ?? '', 'Cada semana',
                formatoHoras(_num(e['duracion_horas']))),
      ]),
      _seccion('REGISTRADAS ESTA SEMANA', Icons.fact_check_outlined, [
        if (s.registros.isEmpty)
          const _Vacio('Aún no hay registros de horas esta semana.')
        else
          for (final r in s.registros)
            _fila(
              _fechaCorta(r['fecha_actividad']?.toString()),
              r['descripcion']?.toString() ?? '',
              formatoHoras(_num(r['duracion_horas'])),
              color: colorAvance,
            ),
      ]),
    ];
  }

  static double _num(dynamic v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);

  static String _fechaCorta(String? iso) {
    final d = DateTime.tryParse(iso ?? '');
    if (d == null) return iso ?? '';
    return '${kNombresDia[(d.weekday - 1).clamp(0, 5)]} ${d.day}/${d.month}';
  }

  Widget _seccion(String titulo, IconData icono, List<Widget> hijos) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(icono, size: 14, color: kTextMuted),
            const SizedBox(width: 6),
            Text(titulo,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold, color: kTextMuted, letterSpacing: 1.1)),
          ]),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFDEE2E6)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(children: hijos),
          ),
        ]),
      );

  Widget _fila(String titulo, String detalle, String horas, {Color? color}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF1F3F5))),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              if (detalle.isNotEmpty)
                Text(detalle, style: const TextStyle(fontSize: 12, color: kTextMuted)),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: (color ?? kPrimary).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(horas,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color ?? kPrimary)),
          ),
        ]),
      );
}

class _Vacio extends StatelessWidget {
  final String texto;
  const _Vacio(this.texto);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text(texto, style: const TextStyle(fontSize: 12, color: kTextMuted)),
      );
}

/// Tarjeta de avance semanal (registradas vs. meta), reutilizada por el
/// dashboard.
class MiSemanaResumenCard extends StatelessWidget {
  final MiSemana semana;
  final VoidCallback? onTap;
  final bool compacta;

  const MiSemanaResumenCard({super.key, required this.semana, this.onTap, this.compacta = false});

  @override
  Widget build(BuildContext context) {
    final f = semana.horas;
    final color = f.cumple ? kSuccess : kWarning;
    Widget dato(String label, double h, {Color? c}) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(formatoHoras(h),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c ?? kPrimary)),
            Text(label, style: const TextStyle(fontSize: 11, color: kTextMuted)),
          ],
        );
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.insights_outlined, color: kPrimary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(compacta ? 'Mi semana' : 'Avance de la semana',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              if (semana.completada)
                const Tooltip(
                  message: 'Semana marcada como completada',
                  child: Icon(Icons.verified_outlined, color: kSuccess, size: 18),
                ),
              if (onTap != null) const Icon(Icons.chevron_right, color: kTextMuted),
            ]),
            const SizedBox(height: 10),
            Text(
              '${formatoHoras(f.registradas)} registradas de ${formatoHoras(f.meta)}'
              '${f.cumple ? ' · ¡meta cumplida!' : ' · faltan ${formatoHoras(f.pendientes)}'}',
              style: TextStyle(fontSize: 13, color: color == kWarning ? const Color(0xFF8A6D00) : kSuccess,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: f.progreso,
                minHeight: 8,
                color: color,
                backgroundColor: const Color(0xFFE9ECEF),
              ),
            ),
            if (compacta && semana.rangos.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                semana.rangosPorDia.entries
                    .map((e) => '${kInicialesDia[e.key]} ${e.value.map((r) => r.texto).join(', ')}')
                    .join('   ·   '),
                style: const TextStyle(fontSize: 12, color: kTextMuted),
              ),
            ],
            if (!compacta) ...[
              const SizedBox(height: 14),
              Wrap(spacing: 24, runSpacing: 10, children: [
                dato('Presenciales', f.presenciales),
                dato('En casa', f.noPresenciales),
                dato('Registradas', f.registradas, c: color),
                dato('Pendientes', f.pendientes, c: f.pendientes > 0 ? kWarning : kTextMuted),
              ]),
              if (f.sinAsignar > 0) ...[
                const SizedBox(height: 10),
                Text(
                  'Entre turnos y horas en casa hay ${formatoHoras(f.asignadas)} asignadas: '
                  'faltan ${formatoHoras(f.sinAsignar)} por asignar para la meta.',
                  style: const TextStyle(fontSize: 11, color: kTextMuted),
                ),
              ],
            ],
          ]),
        ),
      ),
    );
  }
}
