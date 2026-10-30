import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api/api_client.dart';
import '../core/api/paginacion.dart';
import '../core/impresion_calculo.dart';
import '../core/permissions.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/colors.dart';
import '../providers/auth_provider.dart';
import '../widgets/registrar_movimiento_dialog.dart' show mensajeErrorApi;

/// Cotizaciones de impresión 3D para personas externas: se cotiza, queda el
/// registro de a quién y se marca a mano cuando paga (efectivo/recibo).
/// Toda la pestaña exige 'impresiones.gestionar' (ver Seccion.impresiones).
class ImpresionesContent extends StatefulWidget {
  const ImpresionesContent({super.key});
  @override
  State<ImpresionesContent> createState() => _ImpresionesContentState();
}

class _ImpresionesContentState extends State<ImpresionesContent> {
  List<Map<String, dynamic>> _cotizaciones = [];
  List<Map<String, dynamic>> _materiales = [];
  Map<String, dynamic> _tarifa = {};
  bool _cargando = true;
  String? _error;
  String? _filtroPagado; // null = todas, 'false' = pendientes, 'true' = pagadas
  final _busquedaCtrl = TextEditingController();
  Timer? _debounce;

  Dio get _dio => ApiClient.instance.authenticatedDio(context.read<AuthProvider>().token!);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final dio = _dio;
      final q = _busquedaCtrl.text.trim();
      final res = await Future.wait([
        obtenerTodas(
          dio,
          'operaciones/impresiones/',
          queryParameters: {if (_filtroPagado != null) 'pagado': _filtroPagado, if (q.isNotEmpty) 'q': q},
        ),
        obtenerTodas(dio, 'operaciones/materiales-impresion/'),
        dio.get('operaciones/tarifa-impresion/').then((r) => [Map<String, dynamic>.from(r.data)]),
      ]);
      if (!mounted) return;
      setState(() {
        _cotizaciones = res[0];
        _materiales = res[1];
        _tarifa = res[2].first;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = mensajeErrorApi(e);
      });
    }
  }

  void _buscar(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _cargar);
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _abrirFormulario([Map<String, dynamic>? cotizacion]) async {
    final activos = _materiales.where((m) => m['activo'] == true || m['id'] == cotizacion?['material']).toList();
    if (activos.isEmpty) {
      _snack('Primero agrega un material en "Tarifas y materiales".', kDanger);
      return;
    }
    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => _CotizacionDialog(dio: _dio, materiales: activos, tarifa: _tarifa, cotizacion: cotizacion),
    );
    if (guardado == true) _cargar();
  }

  Future<void> _marcarPagado(Map<String, dynamic> c) async {
    final pagado = c['pagado'] == true;
    String? recibo;
    if (!pagado) {
      final ctrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Registrar pago'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${c['cliente_nombre']} — ${formatoPesos(num.parse('${c['total']}'))}'),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(labelText: 'N.º de recibo (opcional)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Marcar pagado')),
          ],
        ),
      );
      recibo = ctrl.text.trim();
      ctrl.dispose();
      if (ok != true) return;
    }
    try {
      await _dio.post(
        'operaciones/impresiones/${c['id']}/marcar-pagado/',
        data: {'pagado': !pagado, 'recibo': recibo ?? ''},
      );
      _cargar();
    } catch (e) {
      if (mounted) _snack(mensajeErrorApi(e), kDanger);
    }
  }

  Future<void> _eliminar(Map<String, dynamic> c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cotización'),
        content: Text('¿Eliminar la cotización de ${c['cliente_nombre']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Eliminar', style: TextStyle(color: context.sgi.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _dio.delete('operaciones/impresiones/${c['id']}/');
      _cargar();
    } catch (e) {
      if (mounted) _snack(mensajeErrorApi(e), kDanger);
    }
  }

  Future<void> _abrirTarifas() async {
    final cambio = await showDialog<bool>(
      context: context,
      builder: (_) => _TarifasDialog(dio: _dio, tarifa: _tarifa, materiales: _materiales),
    );
    if (cambio == true) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      floatingActionButton: !auth.can(Perm.impresionesGestionar)
          ? null
          : FloatingActionButton.extended(
              onPressed: _cargando ? null : () => _abrirFormulario(),
              backgroundColor: context.sgi.brandBar,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Nueva cotización'),
            ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Impresiones 3D',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.sgi.accent),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Cotiza por gramos y horas de máquina y registra el pago.',
                            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    if (auth.can(Perm.impresionesTarifas))
                      TextButton.icon(
                        onPressed: _cargando ? null : _abrirTarifas,
                        icon: const Icon(Icons.tune),
                        label: const Text('Tarifas y materiales'),
                      ),
                  ],
                ),
              ),
              Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final (valor, etiqueta) in [(null, 'Todas'), ('false', 'Pendientes'), ('true', 'Pagadas')])
                      ChoiceChip(
                        label: Text(etiqueta),
                        selected: _filtroPagado == valor,
                        onSelected: (_) {
                          setState(() => _filtroPagado = valor);
                          _cargar();
                        },
                      ),
                    SizedBox(
                      width: 260,
                      child: TextField(
                        controller: _busquedaCtrl,
                        onChanged: _buscar,
                        decoration: const InputDecoration(
                          isDense: true,
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Buscar cliente o documento',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: _lista(cs)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lista(ColorScheme cs) {
    if (_cargando) return Center(child: CircularProgressIndicator(color: context.sgi.accent));
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: TextStyle(color: context.sgi.danger),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: _cargar, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (_cotizaciones.isEmpty) {
      return Center(
        child: Text('No hay cotizaciones.', style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        itemCount: _cotizaciones.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (_, i) => _tarjeta(_cotizaciones[i], cs),
      ),
    );
  }

  Widget _tarjeta(Map<String, dynamic> c, ColorScheme cs) {
    final pagado = c['pagado'] == true;
    final gestiona = context.read<AuthProvider>().can(Perm.impresionesGestionar);
    final estadoColor = pagado ? context.sgi.success : context.sgi.orange;
    final fecha = DateTime.tryParse('${c['fecha_hora']}')?.toLocal();
    final detalle = [
      '${c['nombre_material']} · ${'${c['gramos']}'.replaceAll('.', ',')} g · ${c['horas']} h ${c['minutos']} min',
      if ((c['descripcion'] ?? '').toString().isNotEmpty) c['descripcion'],
      if (fecha != null) '${fecha.day}/${fecha.month}/${fecha.year}',
      if (pagado && (c['recibo'] ?? '').toString().isNotEmpty) 'Recibo ${c['recibo']}',
    ].join('  ·  ');
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: gestiona ? () => _abrirFormulario(c) : null,
        title: Text(
          [
            c['cliente_nombre'],
            if ((c['cliente_documento'] ?? '').toString().isNotEmpty) c['cliente_documento'],
          ].join(' — '),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(detalle, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatoPesos(num.parse('${c['total']}')),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.sgi.tileBg(estadoColor),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    pagado ? 'Pagado' : 'Pendiente',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: estadoColor),
                  ),
                ),
              ],
            ),
            if (gestiona)
              PopupMenuButton<String>(
                onSelected: (op) => switch (op) {
                  'editar' => _abrirFormulario(c),
                  'pago' => _marcarPagado(c),
                  _ => _eliminar(c),
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'editar', child: Text('Editar')),
                  PopupMenuItem(value: 'pago', child: Text(pagado ? 'Quitar pago' : 'Marcar pagado')),
                  const PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ── Formulario de cotización ─────────────────────────────────────────────────

class _CotizacionDialog extends StatefulWidget {
  final Dio dio;
  final List<Map<String, dynamic>> materiales;
  final Map<String, dynamic> tarifa;
  final Map<String, dynamic>? cotizacion;
  const _CotizacionDialog({required this.dio, required this.materiales, required this.tarifa, this.cotizacion});
  @override
  State<_CotizacionDialog> createState() => _CotizacionDialogState();
}

class _CotizacionDialogState extends State<_CotizacionDialog> {
  final _form = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.cotizacion?['cliente_nombre'] ?? '');
  late final _documento = TextEditingController(text: widget.cotizacion?['cliente_documento'] ?? '');
  late final _contacto = TextEditingController(text: widget.cotizacion?['cliente_contacto'] ?? '');
  late final _descripcion = TextEditingController(text: widget.cotizacion?['descripcion'] ?? '');
  late final _gramos = TextEditingController(text: widget.cotizacion?['gramos']?.toString().replaceAll('.', ',') ?? '');
  late final _horas = TextEditingController(text: '${widget.cotizacion?['horas'] ?? ''}');
  late final _minutos = TextEditingController(text: '${widget.cotizacion?['minutos'] ?? ''}');
  late int _materialId;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final porDefecto = widget.materiales.firstWhere(
      (m) => '${m['nombre']}'.toLowerCase() == 'hyper pla',
      orElse: () => widget.materiales.first,
    );
    _materialId = widget.cotizacion?['material'] ?? porDefecto['id'];
  }

  @override
  void dispose() {
    for (final c in [_nombre, _documento, _contacto, _descripcion, _gramos, _horas, _minutos]) {
      c.dispose();
    }
    super.dispose();
  }

  double _n(Object? v) => double.tryParse('$v') ?? 0;

  /// Vista previa: una cotización existente con el mismo material conserva
  /// sus tarifas congeladas (igual que hace el backend al editarla).
  double get _totalPrevio {
    final c = widget.cotizacion;
    final congelada = c != null && c['material'] == _materialId;
    final m = widget.materiales.firstWhere((m) => m['id'] == _materialId);
    final t = congelada ? c : widget.tarifa;
    return calcularCotizacion(
      precioRollo: _n(congelada ? c['precio_rollo'] : m['precio_rollo']),
      pesoRolloG: _n(congelada ? c['peso_rollo_g'] : m['peso_rollo_g']),
      gramos: leerDecimal(_gramos.text) ?? 0,
      horas: int.tryParse(_horas.text) ?? 0,
      minutos: int.tryParse(_minutos.text) ?? 0,
      tarifaHora: _n(t['tarifa_hora']),
      margenPct: _n(t['margen_fallos_pct']),
      cobroMinimo: _n(t['cobro_minimo']),
    ).total;
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    final datos = {
      'cliente_nombre': _nombre.text.trim(),
      'cliente_documento': _documento.text.trim(),
      'cliente_contacto': _contacto.text.trim(),
      'descripcion': _descripcion.text.trim(),
      'material': _materialId,
      'gramos': leerDecimal(_gramos.text)!.toStringAsFixed(2),
      'horas': int.tryParse(_horas.text) ?? 0,
      'minutos': int.tryParse(_minutos.text) ?? 0,
    };
    try {
      final id = widget.cotizacion?['id'];
      if (id == null) {
        await widget.dio.post('operaciones/impresiones/', data: datos);
      } else {
        await widget.dio.patch('operaciones/impresiones/$id/', data: datos);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensajeErrorApi(e)), backgroundColor: kDanger));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String? requerido(String? v) => (v ?? '').trim().isEmpty ? 'Requerido' : null;
    return AlertDialog(
      title: Text(widget.cotizacion == null ? 'Nueva cotización' : 'Editar cotización'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _form,
          onChanged: () => setState(() {}),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nombre,
                  validator: requerido,
                  decoration: const InputDecoration(labelText: 'Nombre del cliente *'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _documento,
                        decoration: const InputDecoration(labelText: 'Documento'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _contacto,
                        decoration: const InputDecoration(labelText: 'Correo o teléfono'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descripcion,
                  decoration: const InputDecoration(labelText: 'Descripción de la pieza'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: _materialId,
                  decoration: const InputDecoration(labelText: 'Material'),
                  items: [
                    for (final m in widget.materiales)
                      DropdownMenuItem(
                        value: m['id'] as int,
                        child: Text(
                          '${m['nombre']} (${formatoPesos(_n(m['precio_rollo']))} / ${_n(m['peso_rollo_g']).toStringAsFixed(0)} g)',
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _materialId = v!),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _gramos,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Gramos *'),
                        validator: (v) => (leerDecimal(v ?? '') ?? 0) <= 0 ? 'Mayor que 0' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _horas,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Horas'),
                        validator: (v) => (v ?? '').isEmpty || (int.tryParse(v!) ?? -1) >= 0 ? null : 'Inválido',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _minutos,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Minutos'),
                        validator: (v) {
                          if ((v ?? '').isEmpty) return null;
                          final m = int.tryParse(v!);
                          return m == null || m < 0 || m > 59 ? '0 a 59' : null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Text('Total estimado', style: TextStyle(color: cs.onSurfaceVariant)),
                      const Spacer(),
                      Text(
                        formatoPesos(_totalPrevio),
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.sgi.accent),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _guardando ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
        ElevatedButton(onPressed: _guardando ? null : _guardar, child: const Text('Guardar')),
      ],
    );
  }
}

// ── Tarifas y materiales ─────────────────────────────────────────────────────

class _TarifasDialog extends StatefulWidget {
  final Dio dio;
  final Map<String, dynamic> tarifa;
  final List<Map<String, dynamic>> materiales;
  const _TarifasDialog({required this.dio, required this.tarifa, required this.materiales});
  @override
  State<_TarifasDialog> createState() => _TarifasDialogState();
}

class _TarifasDialogState extends State<_TarifasDialog> {
  static String _pesos(Object? v) => formatoPesos(double.tryParse('$v') ?? 0).substring(1);
  late final _tarifaHora = TextEditingController(text: _pesos(widget.tarifa['tarifa_hora']));
  late final _minimo = TextEditingController(text: _pesos(widget.tarifa['cobro_minimo']));
  late final _margen = TextEditingController(
    text: (double.tryParse('${widget.tarifa['margen_fallos_pct']}') ?? 0).toString().replaceAll(RegExp(r'\.0$'), ''),
  );
  late List<Map<String, dynamic>> _materiales = widget.materiales;
  bool _cambio = false;
  bool _guardando = false;

  @override
  void dispose() {
    _tarifaHora.dispose();
    _minimo.dispose();
    _margen.dispose();
    super.dispose();
  }

  void _snack(String msg, Color color) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));

  Future<void> _guardarTarifa() async {
    final hora = leerPesos(_tarifaHora.text), minimo = leerPesos(_minimo.text), margen = leerDecimal(_margen.text);
    if (hora == null || minimo == null || margen == null || hora < 0 || minimo < 0 || margen < 0) {
      _snack('Revisa los valores: deben ser números no negativos.', kDanger);
      return;
    }
    setState(() => _guardando = true);
    try {
      await widget.dio.patch(
        'operaciones/tarifa-impresion/',
        data: {
          'tarifa_hora': hora.toStringAsFixed(2),
          'cobro_minimo': minimo.toStringAsFixed(2),
          'margen_fallos_pct': margen.toStringAsFixed(2),
        },
      );
      _cambio = true;
      if (mounted) _snack('Tarifas guardadas. Aplican a las cotizaciones nuevas.', kSuccess);
    } catch (e) {
      if (mounted) _snack(mensajeErrorApi(e), kDanger);
    }
    if (mounted) setState(() => _guardando = false);
  }

  Future<void> _editarMaterial([Map<String, dynamic>? m]) async {
    final nombre = TextEditingController(text: m?['nombre'] ?? '');
    final precio = TextEditingController(text: m == null ? '' : _pesos(m['precio_rollo']));
    final peso = TextEditingController(text: m == null ? '1000' : _pesos(m['peso_rollo_g']));
    var activo = m?['activo'] ?? true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(m == null ? 'Nuevo material' : 'Editar material'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombre,
                decoration: const InputDecoration(labelText: 'Nombre (ej. PETG)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: precio,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Precio del rollo (\$)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: peso,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Peso del rollo (g)'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Activo'),
                value: activo,
                onChanged: (v) => setD(() => activo = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    final datos = {
      'nombre': nombre.text.trim(),
      'precio_rollo': leerPesos(precio.text)?.toStringAsFixed(2),
      'peso_rollo_g': leerPesos(peso.text)?.toStringAsFixed(2),
      'activo': activo,
    };
    for (final c in [nombre, precio, peso]) {
      c.dispose();
    }
    if (ok != true) return;
    if ((datos['nombre'] as String).isEmpty || datos['precio_rollo'] == null || datos['peso_rollo_g'] == null) {
      _snack('Nombre, precio y peso son obligatorios.', kDanger);
      return;
    }
    try {
      if (m == null) {
        await widget.dio.post('operaciones/materiales-impresion/', data: datos);
      } else {
        await widget.dio.patch('operaciones/materiales-impresion/${m['id']}/', data: datos);
      }
      _cambio = true;
      final lista = await obtenerTodas(widget.dio, 'operaciones/materiales-impresion/');
      if (mounted) setState(() => _materiales = lista);
    } catch (e) {
      if (mounted) _snack(mensajeErrorApi(e), kDanger);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Tarifas y materiales'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tarifaHora,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Máquina \$/hora'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _minimo,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cobro mínimo \$'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _margen,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Margen fallos %'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'El margen se suma al costo del material. Los cambios no alteran cotizaciones ya hechas.',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: _guardando ? null : _guardarTarifa, child: const Text('Guardar tarifas')),
              ),
              const Divider(),
              Row(
                children: [
                  const Text('Materiales', style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _editarMaterial(),
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar'),
                  ),
                ],
              ),
              for (final m in _materiales)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    '${m['nombre']}',
                    style: TextStyle(color: m['activo'] == true ? null : cs.onSurfaceVariant),
                  ),
                  subtitle: Text(
                    '${formatoPesos(double.tryParse('${m['precio_rollo']}') ?? 0)} por '
                    '${_pesos(m['peso_rollo_g'])} g${m['activo'] == true ? '' : ' · inactivo'}',
                  ),
                  trailing: IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _editarMaterial(m)),
                ),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context, _cambio), child: const Text('Cerrar'))],
    );
  }
}
