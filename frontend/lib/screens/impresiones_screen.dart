import 'dart:async';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api/api_client.dart';
import '../core/api/paginacion.dart';
import '../core/download_helper.dart';
import '../core/impresion_calculo.dart';
import '../core/permissions.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/colors.dart';
import '../providers/auth_provider.dart';
import '../utils/qr_saver.dart';
import '../widgets/qr_generator_dialog.dart' show urlPublica;
import '../widgets/registrar_movimiento_dialog.dart' show mensajeErrorApi;

/// Encargos de impresión 3D para personas externas: una o varias piezas, se
/// cobran por abonos registrados a mano (efectivo/recibo) y el cliente sigue
/// el encargo con un QR que abre una página pública (`/seguimiento`).
/// Toda la pestaña exige 'impresiones.ver' (ver Seccion.impresiones).
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
  String? _filtroPago; // null = todos, o PENDIENTE / ABONADO / PAGADO
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
          queryParameters: {if (_filtroPago != null) 'estado_pago': _filtroPago, if (q.isNotEmpty) 'q': q},
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

  static num _num(Object? v) => num.tryParse('$v') ?? 0;
  static List<Map<String, dynamic>> _lista(Object? v) => (v as List? ?? []).cast<Map<String, dynamic>>();
  static bool _tieneAbonos(Map<String, dynamic> c) => _lista(c['pagos']).any((p) => p['anulado_en'] == null);

  /// Ejecuta una acción sobre el encargo y recarga, o muestra el error.
  Future<void> _post(String ruta, [Map<String, dynamic>? datos]) async {
    try {
      await _dio.post('operaciones/impresiones/$ruta', data: datos ?? {});
      _cargar();
    } catch (e) {
      if (mounted) _snack(mensajeErrorApi(e), kDanger);
    }
  }

  Future<void> _abrirFormulario([Map<String, dynamic>? cotizacion]) async {
    final usados = {for (final p in _lista(cotizacion?['piezas'])) p['material']};
    final activos = _materiales.where((m) => m['activo'] == true || usados.contains(m['id'])).toList();
    if (activos.isEmpty) {
      _snack('Primero agrega un material en "Tarifas y materiales".', kDanger);
      return;
    }
    final guardado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _CotizacionDialog(dio: _dio, materiales: activos, tarifa: _tarifa, cotizacion: cotizacion),
    );
    if (guardado == null) return;
    _cargar();
    if (cotizacion == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Encargo creado.'),
          action: SnackBarAction(label: 'Adjuntar archivos', onPressed: () => _verArchivos(guardado)),
        ),
      );
    }
  }

  Future<void> _verArchivos(Map<String, dynamic> c) async {
    final cambio = await showDialog<bool>(
      context: context,
      builder: (_) => _ArchivosDialog(dio: _dio, cotizacion: c),
    );
    if (cambio == true) _cargar();
  }

  /// Propone el anticipo si aún no hay abonos, o el saldo pendiente.
  Future<void> _registrarAbono(Map<String, dynamic> c) async {
    final saldo = _num(c['saldo']), anticipo = _num(c['anticipo']);
    final propone = _num(c['abonado']) == 0 && anticipo > 0 && anticipo < saldo ? anticipo : saldo;
    final monto = TextEditingController(text: formatoPesos(propone).substring(1));
    final recibo = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar abono'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${c['cliente_nombre']}'),
            Text(
              'Total ${formatoPesos(_num(c['total']))} · abonado ${formatoPesos(_num(c['abonado']))} · '
              'saldo ${formatoPesos(saldo)}',
              style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (anticipo > 0 && anticipo < saldo)
                  ActionChip(
                    label: Text('Anticipo ${_num(c['anticipo_pct']).round()} %'),
                    onPressed: () => monto.text = formatoPesos(anticipo).substring(1),
                  ),
                ActionChip(
                  label: const Text('Saldo completo'),
                  onPressed: () => monto.text = formatoPesos(saldo).substring(1),
                ),
              ],
            ),
            TextField(
              controller: monto,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Monto (\$)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: recibo,
              decoration: const InputDecoration(labelText: 'N.º de recibo (opcional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Registrar')),
        ],
      ),
    );
    final valor = leerPesos(monto.text), numRecibo = recibo.text.trim();
    monto.dispose();
    recibo.dispose();
    if (ok != true) return;
    if (valor == null || valor <= 0 || valor > saldo) {
      _snack('El monto debe ser mayor que 0 y no pasar del saldo (${formatoPesos(saldo)}).', kDanger);
      return;
    }
    await _post('${c['id']}/abonos/', {'monto': valor.toStringAsFixed(2), 'recibo': numRecibo});
  }

  Future<void> _verAbonos(Map<String, dynamic> c) async {
    final anula = context.read<AuthProvider>().can(Perm.impresionesAnularPagos);
    final aAnular = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final pagos = _lista(c['pagos']);
        return AlertDialog(
          title: const Text('Abonos'),
          content: SizedBox(
            width: 420,
            child: pagos.isEmpty
                ? const Text('Sin abonos registrados.')
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final p in pagos)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            formatoPesos(_num(p['monto'])),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              decoration: p['anulado_en'] == null ? null : TextDecoration.lineThrough,
                            ),
                          ),
                          subtitle: Text(
                            [
                              _fecha(p['fecha']),
                              if ('${p['recibo'] ?? ''}'.isNotEmpty) 'Recibo ${p['recibo']}',
                              if (p['nombre_registrado_por'] != null) 'por ${p['nombre_registrado_por']}',
                              if (p['anulado_en'] != null)
                                'Anulado por ${p['nombre_anulado_por'] ?? '—'}: ${p['motivo_anulacion']}',
                            ].join(' · '),
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                          ),
                          trailing: anula && p['anulado_en'] == null
                              ? TextButton(onPressed: () => Navigator.pop(ctx, p), child: const Text('Anular'))
                              : null,
                        ),
                    ],
                  ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))],
        );
      },
    );
    if (aAnular == null || !mounted) return;
    final motivo = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Anular abono de ${formatoPesos(_num(aAnular['monto']))}'),
        content: TextField(
          controller: motivo,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Motivo *'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Anular', style: TextStyle(color: context.sgi.danger)),
          ),
        ],
      ),
    );
    final texto = motivo.text.trim();
    motivo.dispose();
    if (ok != true) return;
    if (texto.isEmpty) {
      _snack('Escribe el motivo de la anulación.', kDanger);
      return;
    }
    await _post('${c['id']}/abonos/${aAnular['id']}/anular/', {'motivo': texto});
  }

  Future<void> _cambiarEstado(Map<String, dynamic> c) async {
    final nuevo = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Estado del trabajo'),
        children: [
          for (final e in estadosTrabajoImpresion.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, e.key),
              child: Row(
                children: [
                  Icon(
                    c['estado'] == e.key ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 20,
                    color: context.sgi.accent,
                  ),
                  const SizedBox(width: 12),
                  Text(e.value),
                ],
              ),
            ),
        ],
      ),
    );
    if (nuevo != null && nuevo != c['estado']) await _post('${c['id']}/estado/', {'estado': nuevo});
  }

  Future<void> _verQr(Map<String, dynamic> c) async {
    final cambio = await showDialog<bool>(
      context: context,
      builder: (_) => _SeguimientoQrDialog(dio: _dio, cotizacion: c),
    );
    if (cambio == true) _cargar();
  }

  Future<void> _eliminar(Map<String, dynamic> c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar encargo'),
        content: Text('¿Eliminar el encargo de ${c['cliente_nombre']}?'),
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
              label: const Text('Nuevo encargo'),
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
                            'Cotiza encargos por gramos y horas de máquina, registra abonos y comparte el seguimiento por QR.',
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
                    for (final (valor, etiqueta) in [
                      (null, 'Todos'),
                      ('PENDIENTE', 'Pendientes'),
                      ('ABONADO', 'Abonados'),
                      ('PAGADO', 'Pagados'),
                    ])
                      ChoiceChip(
                        label: Text(etiqueta),
                        selected: _filtroPago == valor,
                        onSelected: (_) {
                          setState(() => _filtroPago = valor);
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
                          hintText: 'Buscar cliente, documento o código',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: _listado(cs)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _listado(ColorScheme cs) {
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
        child: Text('No hay encargos.', style: TextStyle(color: cs.onSurfaceVariant)),
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

  Widget _chip(String texto, Color color) => Container(
    margin: const EdgeInsets.only(top: 2),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: context.sgi.tileBg(color), borderRadius: BorderRadius.circular(10)),
    child: Text(texto, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
  );

  Widget _tarjeta(Map<String, dynamic> c, ColorScheme cs) {
    final gestiona = context.read<AuthProvider>().can(Perm.impresionesGestionar);
    final conAbonos = _tieneAbonos(c);
    final estadoPago = '${c['estado_pago']}';
    final colorPago = switch (estadoPago) {
      'PAGADO' => context.sgi.success,
      'ABONADO' => context.sgi.warning,
      _ => context.sgi.orange,
    };
    final piezas = _lista(c['piezas']);
    final gramos = piezas.fold<num>(0, (s, p) => s + _num(p['gramos']));
    final p0 = piezas.isEmpty ? null : piezas.first;
    final detalle = [
      if (piezas.length == 1 && p0 != null)
        '${p0['nombre_material']} · ${'${p0['gramos']}'.replaceAll('.', ',')} g · ${p0['horas']} h ${p0['minutos']} min'
      else
        '${piezas.length} piezas · ${'$gramos'.replaceAll('.', ',')} g',
      if ('${c['descripcion'] ?? ''}'.isNotEmpty) c['descripcion'],
      estadosTrabajoImpresion[c['estado']] ?? '${c['estado']}',
      if (c['urgente'] == true) 'Urgente',
      _fecha(c['fecha_hora']),
    ].join('  ·  ');
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: !gestiona ? null : () => conAbonos ? _verAbonos(c) : _abrirFormulario(c),
        title: Text(
          [
            c['cliente_nombre'],
            if ('${c['cliente_documento'] ?? ''}'.isNotEmpty) c['cliente_documento'],
          ].join(' — '),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(detalle, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (piezas.any((p) => p['url_archivo'] != null || '${p['enlace_archivo'] ?? ''}'.isNotEmpty))
              IconButton(
                tooltip: 'Archivos de las piezas',
                icon: Icon(Icons.attach_file, size: 20, color: cs.onSurfaceVariant),
                onPressed: () => _verArchivos(c),
              ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatoPesos(_num(c['total'])),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                _chip(
                  estadoPago == 'ABONADO'
                      ? 'Saldo ${formatoPesos(_num(c['saldo']))}'
                      : estadosPagoImpresion[estadoPago] ?? estadoPago,
                  colorPago,
                ),
              ],
            ),
            if (gestiona)
              PopupMenuButton<String>(
                onSelected: (op) => switch (op) {
                  'editar' => _abrirFormulario(c),
                  'abono' => _registrarAbono(c),
                  'abonos' => _verAbonos(c),
                  'estado' => _cambiarEstado(c),
                  'qr' => _verQr(c),
                  'archivos' => _verArchivos(c),
                  _ => _eliminar(c),
                },
                itemBuilder: (_) => [
                  if (!conAbonos) const PopupMenuItem(value: 'editar', child: Text('Editar')),
                  if (_num(c['saldo']) > 0) const PopupMenuItem(value: 'abono', child: Text('Registrar abono')),
                  if (_lista(c['pagos']).isNotEmpty) const PopupMenuItem(value: 'abonos', child: Text('Ver abonos')),
                  const PopupMenuItem(value: 'estado', child: Text('Cambiar estado')),
                  const PopupMenuItem(value: 'qr', child: Text('QR de seguimiento')),
                  const PopupMenuItem(value: 'archivos', child: Text('Archivos de las piezas')),
                  if (!conAbonos) const PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// "10/11/2026" a partir de una fecha ISO del backend ('' si no hay).
String _fecha(Object? iso) {
  final f = DateTime.tryParse('${iso ?? ''}')?.toLocal();
  return f == null ? '' : '${f.day}/${f.month}/${f.year}';
}

// ── QR de seguimiento ────────────────────────────────────────────────────────

class _SeguimientoQrDialog extends StatefulWidget {
  final Dio dio;
  final Map<String, dynamic> cotizacion;
  const _SeguimientoQrDialog({required this.dio, required this.cotizacion});
  @override
  State<_SeguimientoQrDialog> createState() => _SeguimientoQrDialogState();
}

class _SeguimientoQrDialogState extends State<_SeguimientoQrDialog> {
  late String _codigo = '${widget.cotizacion['codigo_seguimiento']}';
  bool _cambio = false;

  String get _url => urlPublica('/seguimiento', query: {'c': _codigo});

  void _snack(String msg, Color color) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));

  Future<void> _regenerar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regenerar código'),
        content: const Text('El QR y el enlace anteriores dejarán de funcionar. ¿Continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Regenerar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final r = await widget.dio.post('operaciones/impresiones/${widget.cotizacion['id']}/regenerar-codigo/');
      setState(() {
        _codigo = '${r.data['codigo_seguimiento']}';
        _cambio = true;
      });
    } catch (e) {
      if (mounted) _snack(mensajeErrorApi(e), kDanger);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final archivo = 'qr_encargo_${_codigo.substring(0, 6)}.svg';
    return AlertDialog(
      title: const Text('QR de seguimiento'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Entrégalo a ${widget.cotizacion['cliente_nombre']}: cualquiera que lo escanee ve el estado del '
              'pago y del trabajo, sin documento ni contacto.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(8),
              child: QrImageView(data: _url, version: QrVersions.auto, size: 200, backgroundColor: Colors.white),
            ),
            const SizedBox(height: 8),
            SelectableText(_url, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _regenerar, child: const Text('Regenerar')),
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: _url));
            if (mounted) _snack('Enlace copiado.', kSuccess);
          },
          child: const Text('Copiar enlace'),
        ),
        TextButton(
          onPressed: () async {
            await guardarQrComoSvg(Barcode.qrCode().toSvg(_url, width: 200, height: 200), fileName: archivo);
            if (mounted) _snack('QR guardado como $archivo', kSuccess);
          },
          child: const Text('Guardar QR'),
        ),
        ElevatedButton(onPressed: () => Navigator.pop(context, _cambio), child: const Text('Cerrar')),
      ],
    );
  }
}

// ── Archivos de las piezas ───────────────────────────────────────────────────

/// Modelo 3D de cada pieza: un enlace (el archivo vive en Drive, Printables…)
/// o el archivo subido al servidor. Es interno: no sale en la página del QR.
/// Se puede cambiar aunque el encargo tenga abonos (no altera el cobro).
class _ArchivosDialog extends StatefulWidget {
  final Dio dio;
  final Map<String, dynamic> cotizacion;
  const _ArchivosDialog({required this.dio, required this.cotizacion});
  @override
  State<_ArchivosDialog> createState() => _ArchivosDialogState();
}

class _ArchivosDialogState extends State<_ArchivosDialog> {
  late Map<String, dynamic> _cot = widget.cotizacion;
  bool _cambio = false;
  int? _ocupada; // pieza con una operación en curso

  List<Map<String, dynamic>> get _piezas => (_cot['piezas'] as List? ?? []).cast<Map<String, dynamic>>();

  void _snack(String msg, Color color) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));

  String _ruta(Map<String, dynamic> p) => 'operaciones/impresiones/${_cot['id']}/piezas/${p['id']}/archivo/';

  /// Ejecuta la petición sobre la pieza y toma el encargo actualizado.
  Future<void> _enviar(Map<String, dynamic> p, Future<Response> Function() peticion) async {
    setState(() => _ocupada = p['id']);
    try {
      final r = await peticion();
      _cot = Map<String, dynamic>.from(r.data);
      _cambio = true;
    } catch (e) {
      if (mounted) _snack(mensajeErrorApi(e), kDanger);
    }
    if (mounted) setState(() => _ocupada = null);
  }

  Future<void> _subir(Map<String, dynamic> p) async {
    final elegidos = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['stl', '3mf', 'obj', 'step', 'stp', 'gcode', 'bgcode'],
    );
    if (elegidos.isEmpty) return;
    final archivo = elegidos.first;
    final bytes = await archivo.readAsBytes();
    if (bytes.isEmpty) return;
    await _enviar(p, () => widget.dio.post(
      _ruta(p),
      data: FormData.fromMap({'archivo': MultipartFile.fromBytes(bytes, filename: archivo.name)}),
    ));
  }

  Future<void> _pegarEnlace(Map<String, dynamic> p) async {
    final ctrl = TextEditingController(text: '${p['enlace_archivo'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enlace del archivo'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(labelText: 'https://… (Drive, Printables, OneDrive…)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );
    final enlace = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || enlace.isEmpty) return;
    await _enviar(p, () => widget.dio.post(_ruta(p), data: {'enlace': enlace}));
  }

  /// Un enlace se abre afuera; un archivo subido se descarga con el JWT
  /// (la ruta de /media/ está bloqueada), igual que los informes subidos.
  Future<void> _abrir(Map<String, dynamic> p) async {
    final enlace = '${p['enlace_archivo'] ?? ''}';
    try {
      if (enlace.isNotEmpty) {
        await launchUrl(Uri.parse(enlace), mode: LaunchMode.externalApplication);
        return;
      }
      setState(() => _ocupada = p['id']);
      final r = await widget.dio.get<List<int>>(p['url_archivo'], options: Options(responseType: ResponseType.bytes));
      final msg = await saveAndOpenFile(r.data!, '${p['nombre_archivo']}');
      if (msg != null && mounted) _snack(msg, kSuccess);
    } catch (e) {
      if (mounted) _snack(mensajeErrorApi(e), kDanger);
    }
    if (mounted) setState(() => _ocupada = null);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Archivos de las piezas'),
      content: SizedBox(
        width: 460,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              'Pega el enlace si el archivo está en la nube; si lo trajeron en USB, súbelo (hasta 50 MB). '
              'No se muestra en el QR público.',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            for (final (i, p) in _piezas.indexed)
              Builder(builder: (_) {
                final enlace = '${p['enlace_archivo'] ?? ''}';
                final tiene = enlace.isNotEmpty || p['url_archivo'] != null;
                final ocupada = _ocupada == p['id'];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    enlace.isNotEmpty ? Icons.link : (tiene ? Icons.insert_drive_file_outlined : Icons.block),
                    color: tiene ? context.sgi.accent : cs.outline,
                  ),
                  title: Text('${p['descripcion'] ?? ''}'.isEmpty ? 'Pieza ${i + 1}' : '${p['descripcion']}'),
                  subtitle: Text(
                    enlace.isNotEmpty ? enlace : (tiene ? '${p['nombre_archivo']}' : 'Sin archivo'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: ocupada
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (tiene)
                              IconButton(tooltip: 'Abrir', icon: const Icon(Icons.open_in_new), onPressed: () => _abrir(p)),
                            IconButton(tooltip: 'Pegar enlace', icon: const Icon(Icons.add_link), onPressed: () => _pegarEnlace(p)),
                            IconButton(tooltip: 'Subir archivo', icon: const Icon(Icons.upload_file), onPressed: () => _subir(p)),
                            if (tiene)
                              IconButton(
                                tooltip: 'Quitar',
                                icon: Icon(Icons.delete_outline, color: context.sgi.danger),
                                onPressed: () => _enviar(p, () => widget.dio.delete(_ruta(p))),
                              ),
                          ],
                        ),
                );
              }),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context, _cambio), child: const Text('Cerrar'))],
    );
  }
}

// ── Formulario del encargo ───────────────────────────────────────────────────

/// Campos de una pieza del formulario. Una pieza que ya existía guarda su
/// material y precio de rollo congelados para la vista previa.
class _PiezaCampos {
  final int? id;
  int materialId;
  final int? materialOriginal;
  final double? precioRollo, pesoRolloG;
  final TextEditingController descripcion, gramos, horas, minutos;

  _PiezaCampos(this.materialId, [Map<String, dynamic>? p])
    : id = p?['id'],
      materialOriginal = p?['material'],
      precioRollo = double.tryParse('${p?['precio_rollo']}'),
      pesoRolloG = double.tryParse('${p?['peso_rollo_g']}'),
      descripcion = TextEditingController(text: p?['descripcion'] ?? ''),
      gramos = TextEditingController(text: p?['gramos']?.toString().replaceAll('.', ',') ?? ''),
      horas = TextEditingController(text: '${p?['horas'] ?? ''}'),
      minutos = TextEditingController(text: '${p?['minutos'] ?? ''}');

  void dispose() {
    for (final c in [descripcion, gramos, horas, minutos]) {
      c.dispose();
    }
  }
}

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
  late final List<_PiezaCampos> _piezas;
  late bool _urgente = widget.cotizacion?['urgente'] == true;
  bool _guardando = false;
  bool _autoriza = false;

  /// Ley 1581: documento o contacto del cliente exigen su autorización; un
  /// encargo que ya la tiene no la vuelve a pedir.
  bool get _yaAutorizo => widget.cotizacion?['autorizacion_datos'] != null;
  bool get _pideAutorizacion => _documento.text.trim().isNotEmpty || _contacto.text.trim().isNotEmpty;

  /// Tarifas de la vista previa: las congeladas del encargo, o las vigentes.
  Map<String, dynamic> get _t => widget.cotizacion ?? widget.tarifa;

  late final int _materialPorDefecto = widget.materiales.firstWhere(
    (m) => '${m['nombre']}'.toLowerCase() == 'hyper pla',
    orElse: () => widget.materiales.first,
  )['id'];

  @override
  void initState() {
    super.initState();
    final previas = (widget.cotizacion?['piezas'] as List? ?? []).cast<Map<String, dynamic>>();
    _piezas = previas.isEmpty
        ? [_PiezaCampos(_materialPorDefecto)]
        : [for (final p in previas) _PiezaCampos(p['material'], p)];
  }

  @override
  void dispose() {
    for (final c in [_nombre, _documento, _contacto, _descripcion]) {
      c.dispose();
    }
    for (final p in _piezas) {
      p.dispose();
    }
    super.dispose();
  }

  double _n(Object? v) => double.tryParse('$v') ?? 0;

  /// Vista previa de una pieza: si ya existía y conserva el material, usa el
  /// precio de rollo congelado (igual que el backend al editarla).
  ({double material, double maquina, double preparacion}) _costos(_PiezaCampos p) {
    final congelada = p.id != null && p.materialId == p.materialOriginal;
    final m = widget.materiales.firstWhere((m) => m['id'] == p.materialId);
    return calcularPieza(
      precioRollo: congelada ? p.precioRollo! : _n(m['precio_rollo']),
      pesoRolloG: congelada ? p.pesoRolloG! : _n(m['peso_rollo_g']),
      gramos: leerDecimal(p.gramos.text) ?? 0,
      horas: int.tryParse(p.horas.text) ?? 0,
      minutos: int.tryParse(p.minutos.text) ?? 0,
      tarifaHora: _n(_t['tarifa_hora']),
      margenPct: _n(_t['margen_fallos_pct']),
      cargoPreparacion: _n(_t['cargo_preparacion']),
    );
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    final datos = {
      'cliente_nombre': _nombre.text.trim(),
      'cliente_documento': _documento.text.trim(),
      'cliente_contacto': _contacto.text.trim(),
      'descripcion': _descripcion.text.trim(),
      'urgente': _urgente,
      'autoriza_datos': _autoriza,
      'piezas': [
        for (final p in _piezas)
          {
            'id': ?p.id,
            'descripcion': p.descripcion.text.trim(),
            'material': p.materialId,
            'gramos': leerDecimal(p.gramos.text)!.toStringAsFixed(2),
            'horas': int.tryParse(p.horas.text) ?? 0,
            'minutos': int.tryParse(p.minutos.text) ?? 0,
          },
      ],
    };
    try {
      final id = widget.cotizacion?['id'];
      final r = id == null
          ? await widget.dio.post('operaciones/impresiones/', data: datos)
          : await widget.dio.patch('operaciones/impresiones/$id/', data: datos);
      if (mounted) Navigator.pop(context, Map<String, dynamic>.from(r.data));
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensajeErrorApi(e)), backgroundColor: kDanger));
    }
  }

  Widget _pieza(int i, ColorScheme cs) {
    final p = _piezas[i];
    final costo = _costos(p);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text('Pieza ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                formatoPesos(costo.material + costo.maquina + costo.preparacion),
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              IconButton(
                tooltip: 'Quitar pieza',
                icon: const Icon(Icons.close, size: 18),
                onPressed: _piezas.length == 1
                    ? null
                    : () => setState(() => _piezas.removeAt(i).dispose()),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              children: [
                TextFormField(
                  controller: p.descripcion,
                  decoration: const InputDecoration(labelText: 'Descripción (se ve en el QR)'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: p.materialId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Material'),
                  items: [
                    for (final m in widget.materiales)
                      DropdownMenuItem(
                        value: m['id'] as int,
                        child: Text(
                          '${m['nombre']} (${formatoPesos(_n(m['precio_rollo']))} / ${_n(m['peso_rollo_g']).toStringAsFixed(0)} g)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => p.materialId = v!),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: p.gramos,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Gramos *'),
                        validator: (v) => (leerDecimal(v ?? '') ?? 0) <= 0 ? 'Mayor que 0' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: p.horas,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Horas'),
                        validator: (v) {
                          if ((v ?? '').isEmpty) return null;
                          final h = int.tryParse(v!);
                          return h == null || h < 0 || h > 1000 ? '0 a 1000' : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: p.minutos,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String? requerido(String? v) => (v ?? '').trim().isEmpty ? 'Requerido' : null;
    final costos = _piezas.map(_costos).toList();
    final recargoPct = _n(_t['recargo_urgencia_pct']);
    final total = totalEncargo(
      costos,
      cobroMinimo: _n(_t['cobro_minimo']),
      recargoUrgenciaPct: recargoPct,
      urgente: _urgente,
    );
    double suma(double Function(({double material, double maquina, double preparacion}) c) f) =>
        costos.fold(0.0, (s, c) => s + f(c));
    final preparacion = suma((c) => c.preparacion);
    Widget linea(String etiqueta, double valor) => Row(
      children: [
        Text(etiqueta, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        const Spacer(),
        Text(formatoPesos(valor), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      ],
    );
    return AlertDialog(
      title: Text(widget.cotizacion == null ? 'Nuevo encargo' : 'Editar encargo'),
      content: SizedBox(
        width: 480,
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
                if (_pideAutorizacion)
                  FormField<bool>(
                    validator: (_) => _yaAutorizo || _autoriza ? null : 'Sin autorización deja documento y contacto vacíos.',
                    builder: (campo) => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _yaAutorizo || _autoriza,
                      onChanged: _yaAutorizo ? null : (v) => setState(() => _autoriza = v ?? false),
                      title: const Text(
                        'El cliente autorizó el tratamiento de su documento y contacto (Ley 1581)',
                        style: TextStyle(fontSize: 13),
                      ),
                      subtitle: campo.hasError
                          ? Text(campo.errorText!, style: TextStyle(fontSize: 12, color: context.sgi.danger))
                          : null,
                    ),
                  ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descripcion,
                  decoration: const InputDecoration(labelText: 'Descripción del encargo'),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < _piezas.length; i++) _pieza(i, cs),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _piezas.add(_PiezaCampos(_materialPorDefecto))),
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar pieza'),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _urgente,
                  onChanged: (v) => setState(() => _urgente = v ?? false),
                  title: Text('Urgente (+${recargoPct.toStringAsFixed(0)} %)', style: const TextStyle(fontSize: 13)),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    children: [
                      linea('Material', suma((c) => c.material)),
                      linea('Máquina', suma((c) => c.maquina)),
                      if (preparacion > 0) linea('Preparación', preparacion),
                      if (_urgente) linea('Recargo por urgencia', suma((c) => c.material + c.maquina + c.preparacion) * recargoPct / 100),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text('Total estimado', style: TextStyle(color: cs.onSurfaceVariant)),
                          const Spacer(),
                          Text(
                            formatoPesos(total),
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.sgi.accent),
                          ),
                        ],
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
        TextButton(onPressed: _guardando ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
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
  static String _pct(Object? v) => (double.tryParse('$v') ?? 0).toString().replaceAll(RegExp(r'\.0$'), '');
  late final _margen = TextEditingController(text: _pct(widget.tarifa['margen_fallos_pct']));
  late final _preparacion = TextEditingController(text: _pesos(widget.tarifa['cargo_preparacion']));
  late final _urgencia = TextEditingController(text: _pct(widget.tarifa['recargo_urgencia_pct']));
  late final _anticipo = TextEditingController(text: _pct(widget.tarifa['anticipo_pct']));
  late List<Map<String, dynamic>> _materiales = widget.materiales;
  bool _cambio = false;
  bool _guardando = false;

  @override
  void dispose() {
    for (final c in [_tarifaHora, _minimo, _margen, _preparacion, _urgencia, _anticipo]) {
      c.dispose();
    }
    super.dispose();
  }

  void _snack(String msg, Color color) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));

  Future<void> _guardarTarifa() async {
    final hora = leerPesos(_tarifaHora.text), minimo = leerPesos(_minimo.text), margen = leerDecimal(_margen.text);
    final preparacion = leerPesos(_preparacion.text), urgencia = leerDecimal(_urgencia.text);
    final anticipo = leerDecimal(_anticipo.text);
    final valores = [hora, minimo, margen, preparacion, urgencia, anticipo];
    if (valores.any((v) => v == null || v < 0) || anticipo! > 100) {
      _snack('Revisa los valores: números no negativos y anticipo de 0 a 100 %.', kDanger);
      return;
    }
    setState(() => _guardando = true);
    try {
      await widget.dio.patch(
        'operaciones/tarifa-impresion/',
        data: {
          'tarifa_hora': hora!.toStringAsFixed(2),
          'cobro_minimo': minimo!.toStringAsFixed(2),
          'margen_fallos_pct': margen!.toStringAsFixed(2),
          'cargo_preparacion': preparacion!.toStringAsFixed(2),
          'recargo_urgencia_pct': urgencia!.toStringAsFixed(2),
          'anticipo_pct': anticipo.toStringAsFixed(2),
        },
      );
      _cambio = true;
      if (mounted) _snack('Tarifas guardadas. Aplican a los encargos nuevos.', kSuccess);
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
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _preparacion,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Preparación \$/pieza'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _urgencia,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Urgencia %'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _anticipo,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Anticipo sugerido %'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'El margen se suma al material; la preparación, a cada pieza; la urgencia, al encargo '
                'marcado como urgente. El anticipo solo se propone al registrar el primer abono. '
                'Los cambios no alteran encargos ya hechos.',
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
                  trailing: IconButton(tooltip: 'Editar material', icon: const Icon(Icons.edit_outlined), onPressed: () => _editarMaterial(m)),
                ),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context, _cambio), child: const Text('Cerrar'))],
    );
  }
}
