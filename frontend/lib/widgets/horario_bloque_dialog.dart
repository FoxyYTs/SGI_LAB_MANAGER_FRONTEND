// Diálogo para asignar un rango de horas en uno o varios días (encargado o
// asignatura) y para editar el rango de un bloque existente, más el helper
// que envía las operaciones masivas atómicas del backend y muestra los
// choques (409) sin haber cambiado nada.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/horario_utils.dart';
import '../core/theme/colors.dart';

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
  final List<int> dias;
  final int horaInicio;
  final int horaFin; // exclusiva

  const BloqueFormResultado({
    this.usuario,
    this.nombreUsuario = '',
    this.asignatura,
    this.docente = '',
    this.grupo = '',
    required this.dias,
    required this.horaInicio,
    required this.horaFin,
  });
}

class BloqueFormDialog extends StatefulWidget {
  final ModoBloque modo;
  final String titulo;
  final String textoBoton;
  /// true: chips de días (asignar). false: día fijo `diasIniciales.first` (editar).
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
  late Set<int> _dias;
  late int _inicio;
  late int _fin;
  int? _usuario;
  String? _asignatura;
  String? _docenteDropdown;
  late final TextEditingController _docenteOtroCtrl;
  late final TextEditingController _grupoCtrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _dias = {...widget.diasIniciales};
    _inicio = widget.horaInicio.clamp(kHoraMinLab, kHoraFinMaxLab - 1);
    _fin = widget.horaFin.clamp(_inicio + 1, kHoraFinMaxLab);
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

  void _aceptar() {
    final errorRango = RangosHorario.validar(_inicio, _fin);
    final msg = widget.modo == ModoBloque.encargado && _usuario == null
        ? 'Elige el encargado'
        : widget.modo == ModoBloque.asignatura && _asignatura == null
            ? 'Elige la asignatura'
            : _dias.isEmpty
                ? 'Elige al menos un día'
                : errorRango;
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
        dias: (_dias.toList()..sort()),
        horaInicio: _inicio,
        horaFin: _fin,
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Días', style: TextStyle(fontSize: 12, color: kTextMuted)),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (int d = 0; d < 6; d++)
          FilterChip(
            label: Text(_kDiasCortos[d]),
            selected: _dias.contains(d),
            selectedColor: kPrimary.withValues(alpha: 0.15),
            checkmarkColor: kPrimary,
            visualDensity: VisualDensity.compact,
            onSelected: (sel) => setState(() {
              sel ? _dias.add(d) : _dias.remove(d);
              _error = null;
            }),
          ),
        ActionChip(
          label: const Text('Lun a Vie'),
          visualDensity: VisualDensity.compact,
          onPressed: () => setState(() {
            _dias = _dias.containsAll(lunAVie) && _dias.length == 5 ? <int>{} : {...lunAVie};
            _error = null;
          }),
        ),
      ]),
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
    final n = RangosHorario.bloquesACrear(_dias, _inicio, _fin);
    return AlertDialog(
      title: Text(widget.titulo, style: const TextStyle(color: kPrimary)),
      scrollable: true,
      content: SizedBox(
        width: 380,
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
            _selectorHoras(),
            const SizedBox(height: 10),
            if (widget.multiDia && n > 0)
              Text(
                '${RangosHorario.diasCortos(_dias)} · ${horaAmPm(_inicio)} – ${horaAmPm(_fin)}: '
                '$n bloque${n == 1 ? '' : 's'} de 1 h. Las horas que ya estén asignadas '
                'igual se ignoran.',
                style: const TextStyle(fontSize: 12, color: kTextMuted),
              ),
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
          style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
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
