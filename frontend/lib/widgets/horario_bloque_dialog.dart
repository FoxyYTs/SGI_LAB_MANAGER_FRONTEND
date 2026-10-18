// Diálogo para asignar horas en uno o varios días (encargado o asignatura),
// con rangos propios por día y varios rangos el mismo día, y para editar el
// rango de un bloque existente, más el helper
// que envía las operaciones masivas atómicas del backend y muestra los
// choques (409) sin haber cambiado nada.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/horario_utils.dart';
import '../core/theme/colors.dart';
import '../core/theme/app_theme.dart';

enum ModoBloque { encargado, asignatura }

const _kOtros = '__otros__';

/// Primer elemento que cumple `test`, o null (sin `orElse`, que falla si la
/// lista tiene un tipo de mapa más estrecho que `Map<String, dynamic>`).
Map<String, dynamic>? _buscar(
    List<Map<String, dynamic>> lista, bool Function(Map<String, dynamic>) test) {
  for (final e in lista) {
    if (test(e)) return e;
  }
  return null;
}
const _kDiasCortos = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];

/// Resultado del diálogo: lo que hay que mandar al backend.
class BloqueFormResultado {
  final int? usuario;
  final String nombreUsuario;
  final String? asignatura;
  final String docente;
  final String grupo;
  /// Rangos elegidos, ya normalizados (sin solapes, ordenados por día y
  /// hora; fin exclusivo). En "editar" hay exactamente uno.
  final List<RangoHoras> rangos;

  const BloqueFormResultado({
    this.usuario,
    this.nombreUsuario = '',
    this.asignatura,
    this.docente = '',
    this.grupo = '',
    required this.rangos,
  });

  /// Días con al menos un rango, en orden.
  List<int> get dias => {for (final r in rangos) r.dia}.toList()..sort();
  /// Inicio/fin del primer rango (en "editar", el único).
  int get horaInicio => rangos.first.inicio;
  int get horaFin => rangos.first.fin;
  /// Cuerpo `bloques` para asignar-bloques.
  List<Map<String, int>> get bloquesJson => RangosHorario.aBloquesJson(rangos);
}

/// Rango editable de una fila del diálogo (id estable para las keys).
class _RangoEditable {
  final int id;
  int inicio;
  int fin;
  _RangoEditable(this.id, this.inicio, this.fin);
}

class BloqueFormDialog extends StatefulWidget {
  final ModoBloque modo;
  final String titulo;
  final String textoBoton;
  /// true: chips de días con rangos propios por día (asignar).
  /// false: día fijo `diasIniciales.first` y un solo rango (editar).
  final bool multiDia;
  final Set<int> diasIniciales;
  final int horaInicio;
  final int horaFin;
  final List<Map<String, dynamic>> encargados;
  final int? usuarioInicial;
  final List<Map<String, dynamic>> asignaturas;
  final List<Map<String, dynamic>> docentes;
  final String? asignaturaInicial;
  final String docenteInicial;
  final String grupoInicial;
  /// Texto extra bajo el título (p. ej. el bloque que se está editando).
  final String? nota;

  const BloqueFormDialog({
    super.key,
    required this.modo,
    required this.titulo,
    required this.textoBoton,
    required this.multiDia,
    required this.diasIniciales,
    required this.horaInicio,
    required this.horaFin,
    this.encargados = const [],
    this.usuarioInicial,
    this.asignaturas = const [],
    this.docentes = const [],
    this.asignaturaInicial,
    this.docenteInicial = '',
    this.grupoInicial = '',
    this.nota,
  });

  @override
  State<BloqueFormDialog> createState() => _BloqueFormDialogState();
}

class _BloqueFormDialogState extends State<BloqueFormDialog> {
  // Editar (un día, un rango).
  late int _inicio;
  late int _fin;
  // Varios días: rangos por día marcado (un día marcado siempre tiene ≥1).
  final Map<int, List<_RangoEditable>> _rangos = {};
  int _sigId = 0;
  /// Último rango tocado: se precarga al marcar un día nuevo.
  late ({int inicio, int fin}) _ultimo;
  int? _usuario;
  String? _asignatura;
  String? _docenteDropdown;
  late final TextEditingController _docenteOtroCtrl;
  late final TextEditingController _grupoCtrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _inicio = widget.horaInicio.clamp(kHoraMinLab, kHoraFinMaxLab - 1);
    _fin = widget.horaFin.clamp(_inicio + 1, kHoraFinMaxLab);
    _ultimo = (inicio: _inicio, fin: _fin);
    for (final d in widget.diasIniciales) {
      if (d >= 0 && d < kNombresDia.length) _marcarDia(d);
    }
    _usuario = widget.encargados.any((u) => u['id'] == widget.usuarioInicial)
        ? widget.usuarioInicial
        : null;
    _asignatura = widget.asignaturas.any((a) => a['id'].toString() == widget.asignaturaInicial)
        ? widget.asignaturaInicial
        : null;
    _grupoCtrl = TextEditingController(text: widget.grupoInicial);
    _docenteOtroCtrl = TextEditingController();
    if (widget.docenteInicial.isNotEmpty) {
      final match = _buscar(widget.docentes,
          (d) => (d['nombre_completo']?.toString() ?? '') == widget.docenteInicial);
      if (match != null) {
        _docenteDropdown = match['id'].toString();
      } else {
        _docenteDropdown = _kOtros;
        _docenteOtroCtrl.text = widget.docenteInicial;
      }
    }
  }

  @override
  void dispose() {
    _docenteOtroCtrl.dispose();
    _grupoCtrl.dispose();
    super.dispose();
  }

  String _nombreDocente() {
    if (_docenteDropdown == null) return '';
    if (_docenteDropdown == _kOtros) return _docenteOtroCtrl.text.trim();
    final doc = _buscar(widget.docentes, (d) => d['id'].toString() == _docenteDropdown);
    return doc?['nombre_completo']?.toString() ?? '';
  }

  static String _nombreEncargado(Map<String, dynamic> u) =>
      u['nombre_completo']?.toString() ?? u['username']?.toString() ?? '?';

  // ── Rangos por día ──────────────────────────────────────────────────────

  _RangoEditable _nuevoRango(int inicio, int fin) => _RangoEditable(_sigId++, inicio, fin);

  void _marcarDia(int d) {
    _rangos.putIfAbsent(d, () => [_nuevoRango(_ultimo.inicio, _ultimo.fin)]);
  }

  void _usar(_RangoEditable r) => _ultimo = (inicio: r.inicio, fin: r.fin);

  /// Todos los rangos del diálogo (sin normalizar).
  List<RangoHoras> get _todos => [
        for (final e in _rangos.entries)
          for (final r in e.value) RangoHoras(e.key, r.inicio, r.fin),
      ];

  List<RangoHoras> _resultadoRangos() => widget.multiDia
      ? RangosHorario.normalizar(_todos)
      : [RangoHoras(widget.diasIniciales.isEmpty ? 0 : widget.diasIniciales.first, _inicio, _fin)];

  String? _errorRangos() {
    if (!widget.multiDia) return RangosHorario.validar(_inicio, _fin);
    if (_rangos.isEmpty) return 'Elige al menos un día';
    for (final e in _rangos.entries) {
      for (final r in e.value) {
        final err = RangosHorario.validar(r.inicio, r.fin);
        if (err != null) return '${kNombresDia[e.key]}: $err';
      }
    }
    return null;
  }

  void _aceptar() {
    final msg = widget.modo == ModoBloque.encargado && _usuario == null
        ? 'Elige el encargado'
        : widget.modo == ModoBloque.asignatura && _asignatura == null
            ? 'Elige la asignatura'
            : _errorRangos();
    if (msg != null) {
      setState(() => _error = msg);
      return;
    }
    final enc = _buscar(widget.encargados, (u) => u['id'] == _usuario);
    Navigator.pop(
      context,
      BloqueFormResultado(
        usuario: _usuario,
        nombreUsuario: enc == null ? '' : _nombreEncargado(enc),
        asignatura: _asignatura,
        docente: _nombreDocente(),
        grupo: _grupoCtrl.text.trim(),
        rangos: _resultadoRangos(),
      ),
    );
  }

  Widget _selectorEncargado() {
    final opciones = [...widget.encargados]
      ..sort((a, b) => _nombreEncargado(a).toLowerCase().compareTo(_nombreEncargado(b).toLowerCase()));
    return DropdownButtonFormField<int>(
      initialValue: _usuario,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Encargado *',
        prefixIcon: Icon(Icons.person_outline, color: kPrimary),
        border: OutlineInputBorder(),
      ),
      items: opciones
          .map((u) => DropdownMenuItem<int>(
                value: u['id'] as int,
                child: Text('${_nombreEncargado(u)} · ${u['rol'] ?? ''}',
                    overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (v) => setState(() { _usuario = v; _error = null; }),
    );
  }

  List<Widget> _camposAsignatura() => [
        DropdownButtonFormField<String>(
          initialValue: _asignatura,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Asignatura *',
            prefixIcon: Icon(Icons.school_outlined, color: kPrimary),
            border: OutlineInputBorder(),
          ),
          items: widget.asignaturas
              .map((a) => DropdownMenuItem(
                    value: a['id'].toString(),
                    child: Text(a['nombre_asignatura'].toString(), overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (v) => setState(() { _asignatura = v; _error = null; }),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _docenteDropdown,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Docente',
            prefixIcon: Icon(Icons.person_outline, color: kPrimary),
            border: OutlineInputBorder(),
          ),
          items: [
            ...widget.docentes.map((d) => DropdownMenuItem(
                  value: d['id'].toString(),
                  child: Text(d['nombre_completo']?.toString() ?? '', overflow: TextOverflow.ellipsis),
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
        if (_docenteDropdown == _kOtros) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _docenteOtroCtrl,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Nombre del docente',
              prefixIcon: Icon(Icons.edit_outlined, color: kPrimary),
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _grupoCtrl,
          maxLength: 30,
          decoration: const InputDecoration(
            labelText: 'Grupo (ej. G-01)',
            prefixIcon: Icon(Icons.group_outlined, color: kPrimary),
            border: OutlineInputBorder(),
            counterText: '',
          ),
        ),
      ];

  Widget _selectorDias() {
    if (!widget.multiDia) {
      final d = widget.diasIniciales.isEmpty ? 0 : widget.diasIniciales.first;
      return Row(children: [
        const Icon(Icons.calendar_today_outlined, size: 16, color: kTextMuted),
        const SizedBox(width: 8),
        Text(kNombresDia[d], style: const TextStyle(fontWeight: FontWeight.w600)),
      ]);
    }
    final lunAVie = {0, 1, 2, 3, 4};
    final marcados = _rangos.keys.toSet();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Días', style: TextStyle(fontSize: 12, color: kTextMuted)),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (int d = 0; d < 6; d++)
          FilterChip(
            label: Text(_kDiasCortos[d]),
            selected: marcados.contains(d),
            selectedColor: kPrimary.withValues(alpha: 0.15),
            checkmarkColor: kPrimary,
            visualDensity: VisualDensity.compact,
            onSelected: (sel) => setState(() {
              sel ? _marcarDia(d) : _rangos.remove(d);
              _error = null;
            }),
          ),
        ActionChip(
          label: const Text('Lun a Vie'),
          visualDensity: VisualDensity.compact,
          onPressed: () => setState(() {
            if (marcados.length == 5 && marcados.containsAll(lunAVie)) {
              _rangos.clear();
            } else {
              _rangos.remove(5);
              lunAVie.forEach(_marcarDia);
            }
            _error = null;
          }),
        ),
      ]),
    ]);
  }

  /// Selector compacto de hora (controlado: refleja `valor` aunque cambie
  /// desde fuera, p. ej. al copiar un rango a todos los días).
  Widget _dropHora({
    required Key key,
    required int valor,
    required List<int> opciones,
    required ValueChanged<int> onChanged,
  }) =>
      InputDecorator(
        key: key,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          border: OutlineInputBorder(),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: opciones.contains(valor) ? valor : opciones.first,
            isExpanded: true,
            isDense: true,
            items: opciones
                .map((h) => DropdownMenuItem(value: h, child: Text(horaAmPm(h))))
                .toList(),
            onChanged: (v) { if (v != null) onChanged(v); },
          ),
        ),
      );

  Widget _filaRango(int dia, int i, _RangoEditable r, {required bool copiar}) {
    return Padding(
      key: ValueKey('rango-$dia-$i'),
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        Expanded(
          child: _dropHora(
            key: ValueKey('desde-$dia-$i'),
            valor: r.inicio,
            opciones: RangosHorario.iniciosPosibles,
            onChanged: (v) => setState(() {
              r.fin = RangosHorario.ajustarFin(v, r.inicio, r.fin);
              r.inicio = v;
              _usar(r);
              _error = null;
            }),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('–', style: TextStyle(color: kTextMuted)),
        ),
        Expanded(
          child: _dropHora(
            key: ValueKey('hasta-$dia-$i'),
            valor: r.fin,
            opciones: RangosHorario.finesPosibles(r.inicio),
            onChanged: (v) => setState(() {
              r.fin = v;
              _usar(r);
              _error = null;
            }),
          ),
        ),
        if (copiar)
          IconButton(
            key: ValueKey('copiar-$dia-$i'),
            icon: const Icon(Icons.copy_all_outlined, size: 20),
            color: kPrimary,
            tooltip: 'Copiar este rango a todos los días marcados',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
            onPressed: () => _copiarATodos(dia, r),
          ),
        IconButton(
          key: ValueKey('quitar-$dia-$i'),
          icon: const Icon(Icons.close, size: 20),
          color: kTextMuted,
          tooltip: 'Quitar rango',
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          padding: EdgeInsets.zero,
          onPressed: () => setState(() {
            _rangos[dia]?.remove(r);
            // Sin rangos el día deja de estar marcado.
            if (_rangos[dia]?.isEmpty ?? false) _rangos.remove(dia);
            _error = null;
          }),
        ),
      ]),
    );
  }

  /// Deja `r` como único rango de cada día marcado.
  void _copiarATodos(int origen, _RangoEditable r) {
    setState(() {
      for (final d in _rangos.keys.toList()) {
        if (d == origen) continue;
        _rangos[d] = [_nuevoRango(r.inicio, r.fin)];
      }
      _usar(r);
      _error = null;
    });
  }

  Widget _rangosPorDia() {
    final dias = _rangos.keys.toList()..sort();
    if (dias.isEmpty) {
      return const Text('Marca los días y elige las horas de cada uno.',
          style: TextStyle(fontSize: 12, color: kTextMuted));
    }
    final copiar = dias.length > 1;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final d in dias)
        Container(
          key: ValueKey('dia-$d'),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(10, 4, 4, 8),
          decoration: BoxDecoration(
            border: Border.all(color: kPrimary.withValues(alpha: 0.25)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: kNombresDia[d],
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    TextSpan(
                      text: '  ${RangosHorario.totalHoras([
                        for (final r in _rangos[d]!) RangoHoras(d, r.inicio, r.fin),
                      ])} h',
                      style: const TextStyle(fontSize: 12, color: kTextMuted),
                    ),
                  ]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                key: ValueKey('agregar-$d'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('rango'),
                onPressed: () => setState(() {
                  final lista = _rangos[d]!;
                  final s = RangosHorario.sugerirRangoNuevo(
                    d,
                    [for (final r in lista) RangoHoras(d, r.inicio, r.fin)],
                    RangoHoras(d, _ultimo.inicio, _ultimo.fin),
                  );
                  lista.add(_nuevoRango(s.inicio, s.fin));
                  _error = null;
                }),
              ),
            ]),
            for (int i = 0; i < _rangos[d]!.length; i++)
              _filaRango(d, i, _rangos[d]![i], copiar: copiar),
          ]),
        ),
    ]);
  }

  Widget _selectorHoras() {
    final fines = RangosHorario.finesPosibles(_inicio);
    final inicio = DropdownButtonFormField<int>(
      initialValue: _inicio,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Desde',
        prefixIcon: Icon(Icons.schedule_outlined, color: kPrimary),
        border: OutlineInputBorder(),
      ),
      items: RangosHorario.iniciosPosibles
          .map((h) => DropdownMenuItem(value: h, child: Text(horaAmPm(h))))
          .toList(),
      onChanged: (v) {
        if (v == null) return;
        setState(() {
          _fin = RangosHorario.ajustarFin(v, _inicio, _fin);
          _inicio = v;
          _error = null;
        });
      },
    );
    final fin = DropdownButtonFormField<int>(
      // La key fuerza a reconstruir el campo cuando cambian las opciones.
      key: ValueKey('fin-$_inicio'),
      initialValue: fines.contains(_fin) ? _fin : fines.first,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Hasta',
        border: OutlineInputBorder(),
      ),
      items: fines.map((h) => DropdownMenuItem(value: h, child: Text(horaAmPm(h)))).toList(),
      onChanged: (v) => setState(() { if (v != null) _fin = v; _error = null; }),
    );
    return Row(children: [
      Expanded(child: inicio),
      const SizedBox(width: 8),
      Expanded(child: fin),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final angosta = MediaQuery.sizeOf(context).width < 480;
    final todos = widget.multiDia ? _todos : const <RangoHoras>[];
    return AlertDialog(
      title: Text(widget.titulo, style: const TextStyle(color: kPrimary)),
      scrollable: true,
      // En teléfonos, menos margen para que quepan desde–hasta y los botones.
      insetPadding: widget.multiDia && angosta
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 24)
          : null,
      contentPadding: widget.multiDia && angosta
          ? const EdgeInsets.fromLTRB(16, 16, 16, 8)
          : null,
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.nota != null) ...[
              Text(widget.nota!, style: const TextStyle(fontSize: 12, color: kTextMuted)),
              const SizedBox(height: 12),
            ],
            if (widget.modo == ModoBloque.encargado) _selectorEncargado() else ..._camposAsignatura(),
            const SizedBox(height: 12),
            _selectorDias(),
            const SizedBox(height: 12),
            if (widget.multiDia) ...[
              _rangosPorDia(),
              if (todos.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  RangosHorario.resumenTotal(todos),
                  key: const ValueKey('resumen-total'),
                  style: const TextStyle(fontWeight: FontWeight.w600, color: kPrimary),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Los rangos que se solapan se unen y las horas que ya estén '
                  'asignadas se ignoran.',
                  style: TextStyle(fontSize: 12, color: kTextMuted),
                ),
              ],
            ] else ...[
              _selectorHoras(),
            ],
            const SizedBox(height: 10),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: kDanger, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: context.sgi.brandBar, foregroundColor: Colors.white),
          onPressed: _aceptar,
          child: Text(widget.textoBoton),
        ),
      ],
    );
  }
}

/// Mensaje legible de una respuesta de error del API ({detail} o
/// {campo: [msg]}).
String? mensajeErrorApi(dynamic data) {
  if (data is Map) {
    final detail = data['detail'];
    if (detail != null) return detail.toString();
    for (final v in data.values) {
      if (v is List && v.isNotEmpty) return v.first.toString();
      if (v is String && v.isNotEmpty) return v;
    }
  }
  return null;
}

/// Diálogo con los choques de un 409: no se guardó nada.
Future<void> mostrarChoques(BuildContext context, dynamic data) {
  final lineas = RangosHorario.describirChoques(data is Map ? data['choques'] : null);
  final detalle = mensajeErrorApi(data) ?? 'Hay bloques que chocan. No se guardó nada.';
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Row(children: [
        Icon(Icons.warning_amber_rounded, color: kDanger),
        SizedBox(width: 8),
        Expanded(child: Text('No se guardó nada', style: TextStyle(fontSize: 16))),
      ]),
      scrollable: true,
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(detalle, style: const TextStyle(fontSize: 13)),
            if (lineas.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...lineas.map((l) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('•  ', style: TextStyle(color: kDanger)),
                      Expanded(child: Text(l, style: const TextStyle(fontSize: 12))),
                    ]),
                  )),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
      ],
    ),
  );
}

/// POST de una operación masiva del horario. Devuelve el JSON de respuesta,
/// o null si falló (ya mostró los choques o el error al usuario).
Future<Map<String, dynamic>?> postHorario(
    BuildContext context, Dio dio, String path, Map<String, dynamic> data) async {
  try {
    final r = await dio.post(path, data: data);
    return r.data is Map ? Map<String, dynamic>.from(r.data as Map) : <String, dynamic>{};
  } on DioException catch (e) {
    if (!context.mounted) return null;
    final resp = e.response;
    if (resp?.statusCode == 409) {
      await mostrarChoques(context, resp!.data);
    } else {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text(mensajeErrorApi(resp?.data) ??
            (resp?.statusCode == 403
                ? 'No tienes permiso para modificar el horario.'
                : 'No se pudo guardar. Revisa la conexión e intenta de nuevo.')),
        backgroundColor: kDanger,
        duration: const Duration(seconds: 4),
      ));
    }
    return null;
  }
}
