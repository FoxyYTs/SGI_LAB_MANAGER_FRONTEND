import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api/api_client.dart';
import '../core/api/paginacion.dart';
import '../core/theme/colors.dart';
import '../core/permissions.dart';
import '../core/presentaciones.dart';
import '../providers/auth_provider.dart';
import 'insumo_form_screen.dart';
import 'sga_screen.dart';

class InsumoDetailScreen extends StatefulWidget {
  final String insumoId;
  final String insumoNombre;
  const InsumoDetailScreen({
    super.key,
    required this.insumoId,
    required this.insumoNombre,
  });

  @override
  State<InsumoDetailScreen> createState() => _InsumoDetailScreenState();
}

class _InsumoDetailScreenState extends State<InsumoDetailScreen> {
  Map<String, dynamic>? _insumo;
  List<Map<String, dynamic>> _movimientos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final auth = context.read<AuthProvider>();
    final dio = ApiClient.instance.authenticatedDio(auth.token);
    try {
      final results = await Future.wait([
        dio.get('inventario/lista/${widget.insumoId}/'),
        // `limit` no existe en el backend (PageNumberPagination, 50/pág,
        // más reciente primero): se pide la 1.ª página y se toman 8.
        dio.get('operaciones/bitacora/',
            queryParameters: {'insumo': widget.insumoId}),
      ]);
      setState(() {
        _insumo = Map<String, dynamic>.from(results[0].data);
        _movimientos = listaDeRespuesta(results[1].data).take(8).toList();
        _cargando = false;
      });
    } catch (_) {
      setState(() => _cargando = false);
    }
  }

  /// Registra una ROTURA en la bitácora. El backend exige `presentacion`
  /// (FK obligatoria de BitacoraMovimientos) — antes se enviaba `insumo`
  /// y fallaba siempre. Con una sola presentación se usa directamente;
  /// con varias, el diálogo deja elegir de cuál se descuenta. Solo se
  /// ofrecen las presentaciones activas.
  Future<void> _reportarRotura(String nombre) async {
    final presentaciones =
        presentacionesActivas(_insumo?['presentaciones'] as List?);
    if (presentaciones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Este insumo no tiene presentaciones activas: '
              'agrega o reactiva una antes de reportar una rotura.'),
          backgroundColor: kDanger));
      return;
    }
    String presId = presentaciones.first['id'].toString();
    String unidadDe(String id) => presentaciones
            .firstWhere((p) => p['id'].toString() == id,
                orElse: () => const {})['unidad_nombre']
            ?.toString() ??
        '';
    String etiquetaPres(Map<String, dynamic> p) {
      final stock = double.tryParse(p['stock_actual']?.toString() ?? '');
      final u = p['unidad_nombre']?.toString() ?? '';
      return stock == null ? u : '$u — stock ${_fmtNum(stock)}';
    }

    final cantCtrl = TextEditingController();
    final estudCtrl = TextEditingController();
    final nitCtrl   = TextEditingController();
    final obsCtrl   = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.warning_amber_outlined, color: kDanger, size: 20),
          const SizedBox(width: 8),
          const Text('Reportar rotura / pérdida',
              style: TextStyle(color: kDanger, fontSize: 15)),
        ]),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Insumo: $nombre',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 12),
              if (presentaciones.length > 1) ...[
                DropdownButtonFormField<String>(
                  initialValue: presId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Presentación *',
                    prefixIcon: Icon(Icons.inventory_2_outlined,
                        color: kDanger, size: 18),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: presentaciones
                      .map((p) => DropdownMenuItem(
                            value: p['id'].toString(),
                            child: Text(etiquetaPres(p),
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setD(() => presId = v);
                  },
                ),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: cantCtrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Cantidad (${unidadDe(presId)}) *',
                  prefixIcon: const Icon(Icons.numbers, color: kDanger, size: 18),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: estudCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del estudiante (opcional)',
                  prefixIcon:
                      Icon(Icons.person_outline, color: kTextMuted, size: 18),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nitCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'NIT / Cédula (opcional)',
                  prefixIcon:
                      Icon(Icons.badge_outlined, color: kTextMuted, size: 18),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: obsCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Observaciones (opcional)',
                  prefixIcon:
                      Icon(Icons.notes_outlined, color: kTextMuted, size: 18),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: kDanger, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Registrar rotura'),
          ),
        ],
      )),
    );

    final cantidad = double.tryParse(cantCtrl.text.trim()) ?? 0;
    cantCtrl.dispose();

    if (ok != true || cantidad <= 0) {
      estudCtrl.dispose();
      nitCtrl.dispose();
      obsCtrl.dispose();
      return;
    }

    // Componer observaciones con datos del estudiante si se proporcionaron
    final partes = <String>[];
    if (estudCtrl.text.trim().isNotEmpty) {
      partes.add('Estudiante: ${estudCtrl.text.trim()}');
    }
    if (nitCtrl.text.trim().isNotEmpty) {
      partes.add('NIT: ${nitCtrl.text.trim()}');
    }
    if (obsCtrl.text.trim().isNotEmpty) {
      partes.add(obsCtrl.text.trim());
    }
    estudCtrl.dispose();
    nitCtrl.dispose();
    obsCtrl.dispose();

    if (!mounted) return;
    try {
      final auth = context.read<AuthProvider>();
      final dio  = ApiClient.instance.authenticatedDio(auth.token);
      await dio.post('operaciones/bitacora/', data: {
        'presentacion':     presId,
        'tipo_movimiento':  'ROTURA',
        'cantidad':         cantidad,
        'observaciones':    partes.join(' | '),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Rotura registrada y stock actualizado.'),
            backgroundColor: kSuccess));
        _cargar();
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('No se pudo registrar la rotura: ${_mensajeError(e)}'),
            backgroundColor: kDanger));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: kDanger));
      }
    }
  }

  /// Desactiva o reactiva una presentación. Desactivar es la alternativa a
  /// borrar una presentación con historial (el backend responde 409): deja
  /// de ofrecerse para préstamos y su stock no cuenta en el total, pero se
  /// conserva con sus movimientos.
  Future<void> _cambiarEstadoPresentacion(
      Map<String, dynamic> pres, bool activar) async {
    final unidad = pres['unidad_nombre']?.toString() ?? '';
    if (!activar) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Desactivar presentación'),
          content: Text(
              'La presentación "$unidad" dejará de aparecer para nuevos '
              'préstamos y roturas, y su stock no contará en el total del '
              'insumo. Su historial se conserva y puedes reactivarla cuando '
              'quieras.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Desactivar',
                    style: TextStyle(color: kDanger))),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    try {
      final auth = context.read<AuthProvider>();
      final dio = ApiClient.instance.authenticatedDio(auth.token);
      await dio.post('inventario/lista/${widget.insumoId}/presentaciones/'
          '${pres['id']}/${activar ? 'activar' : 'desactivar'}/');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(activar
              ? 'Presentación "$unidad" reactivada.'
              : 'Presentación "$unidad" desactivada.'),
          backgroundColor: kSuccess));
      _cargar();
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('No se pudo cambiar la presentación: ${_mensajeError(e)}'),
          backgroundColor: kDanger));
    }
  }

  static String _fmtNum(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  /// Primer mensaje legible de una respuesta de error de DRF.
  static String _mensajeError(DioException e) {
    dynamic d = e.response?.data;
    while (true) {
      if (d is Map && d.isNotEmpty) {
        d = d['error'] ?? d['detail'] ?? d.values.first;
      } else if (d is List && d.isNotEmpty) {
        d = d.first;
      } else {
        break;
      }
    }
    final txt = d?.toString() ?? '';
    return txt.isNotEmpty ? txt : (e.message ?? 'error de red');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          widget.insumoNombre,
          style: const TextStyle(color: kPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_insumo != null && _insumo!['tipo_nombre'] == 'Químico')
            IconButton(
              icon: const Icon(Icons.science_outlined, color: kPrimary),
              tooltip: 'Ficha SGA',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SgaScreen(
                    insumoId: widget.insumoId,
                    insumoNombre: widget.insumoNombre,
                  ),
                ),
              ),
            ),
          if (_insumo != null && auth.can(Perm.inventarioGestionar))
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: kPrimary),
              tooltip: 'Editar',
              onPressed: () async {
                final ok = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InsumoFormScreen(insumo: _insumo),
                  ),
                );
                if (ok == true) _cargar();
              },
            ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : _insumo == null
              ? const Center(child: Text('No se pudo cargar el insumo.'))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final d = _insumo!;
    final tipo = d['tipo_nombre']?.toString() ?? '';
    // stock_total = suma de presentaciones; stock_actual queda como fallback legacy
    final stock = double.tryParse(
            (d['stock_total'] ?? d['stock_actual'])?.toString() ?? '0') ?? 0;
    final stockMin = double.tryParse(d['stock_minimo']?.toString() ?? '0') ?? 0;
    final presentaciones = d['presentaciones'] as List? ?? const [];
    final unidad = presentaciones.isNotEmpty
        ? (presentaciones.first as Map)['unidad_nombre']?.toString() ?? ''
        : d['unidad_abreviatura']?.toString() ?? '';

    Color semaforoColor;
    String semaforoLabel;
    if (stock <= stockMin) {
      semaforoColor = kSemaforoRojo;
      semaforoLabel = 'Stock crítico';
    } else if (stock <= stockMin * 1.5) {
      semaforoColor = kSemaforoAmarillo;
      semaforoLabel = 'Stock bajo';
    } else {
      semaforoColor = kSemaforoVerde;
      semaforoLabel = 'En stock';
    }

    final fotoAbsUrl = (d['foto'] as String?)?.isNotEmpty == true
        ? d['foto'] as String
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Foto del insumo ─────────────────────────────────────────────
          if (fotoAbsUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                fotoAbsUrl,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(
                        height: 200,
                        color: Colors.grey[100],
                        child: const Center(
                            child: CircularProgressIndicator(color: kPrimary)),
                      ),
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Info general ────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        d['nombre_insumo'] ?? '',
                        style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: kPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(tipo,
                          style: const TextStyle(
                            color: kPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          )),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _infoRow(Icons.place_outlined, 'Ubicación',
                      d['ubicacion_nombre']?.toString() ?? 'Sin ubicación'),
                  if (d['observaciones']?.toString().isNotEmpty == true)
                    _infoRow(Icons.notes_outlined, 'Observaciones',
                        d['observaciones'].toString()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Stock ────────────────────────────────────────────────────────
          Row(children: [
            Expanded(
              child: _stockCard('Stock actual',
                  '${stock.toStringAsFixed(0)} $unidad', semaforoColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _stockCard('Stock mínimo',
                  '${stockMin.toStringAsFixed(0)} $unidad', kTextMuted),
            ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                  color: semaforoColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(semaforoLabel,
                style: TextStyle(
                  color: semaforoColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                )),
          ]),

          // ── Detalle Químico ──────────────────────────────────────────────
          if (tipo == 'Químico' && d['detalle_quimico'] != null) ...[
            const SizedBox(height: 16),
            _buildDetalleQuimico(
                Map<String, dynamic>.from(d['detalle_quimico'])),
          ],

          // ── Detalle Material ─────────────────────────────────────────────
          if ((tipo == 'Implemento' || tipo == 'Vidriería') &&
              d['detalle_material'] != null) ...[
            const SizedBox(height: 16),
            _buildDetalleMaterial(
                Map<String, dynamic>.from(d['detalle_material'])),
          ],

          // ── Presentaciones disponibles ───────────────────────────────────
          if ((d['presentaciones'] as List?)?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            _buildPresentaciones(
              List<Map<String, dynamic>>.from(d['presentaciones'] as List),
              stockMin,
              puedeGestionar:
                  context.read<AuthProvider>().can(Perm.inventarioGestionar),
            ),
          ],

          // ── Reportar rotura ─────────────────────────────────────────────
          if (context.read<AuthProvider>().can(Perm.bitacoraGestionar)) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.warning_amber_outlined,
                  color: kDanger, size: 18),
              label: const Text('Reportar rotura / pérdida',
                  style: TextStyle(color: kDanger)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: kDanger),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
              ),
              onPressed: () => _reportarRotura(
                  d['nombre_insumo']?.toString() ?? widget.insumoNombre),
            ),
          ],

          // ── Últimos movimientos ──────────────────────────────────────────
          if (_movimientos.isNotEmpty) ...[
            const SizedBox(height: 20),
            _seccion('Últimos movimientos'),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                child: Column(
                  children: _movimientos.map(_buildMovRow).toList(),
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDetalleQuimico(Map<String, dynamic> q) {
    final pics = (q['pictogramas_sga'] as List?)?.cast<String>() ?? [];
    final pwa = q['palabra_advertencia']?.toString() ?? '';
    final pwaColor = pwa == 'PELIGRO' ? kDanger : kWarning;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _seccion('Información SGA/GHS'),
            if (q['formula_quimica']?.toString().isNotEmpty == true)
              _infoRow(Icons.science_outlined, 'Fórmula',
                  q['formula_quimica'].toString()),
            if (q['numero_cas']?.toString().isNotEmpty == true)
              _infoRow(Icons.tag, 'Número CAS',
                  q['numero_cas'].toString()),
            if (q['concentracion']?.toString().isNotEmpty == true)
              _infoRow(Icons.opacity, 'Concentración',
                  q['concentracion'].toString()),
            if (pwa.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: pwaColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: pwaColor),
                ),
                child: Text('⚠ $pwa',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: pwaColor,
                    )),
              ),
            ],
            if (pics.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: pics
                    .map((c) => Chip(
                          label: Text(c,
                              style: const TextStyle(fontSize: 11)),
                          backgroundColor:
                              kPrimary.withValues(alpha: 0.1),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
              ),
            ],
            if (q['datos_extraidos'] != true)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  const Icon(Icons.info_outline,
                      size: 14, color: kTextMuted),
                  const SizedBox(width: 4),
                  Text('Sin datos SGA completos. Ver ficha en pestaña SGA.',
                      style: const TextStyle(
                          color: kTextMuted, fontSize: 12)),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetalleMaterial(Map<String, dynamic> m) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _seccion('Información del material'),
            if (m['marca']?.toString().isNotEmpty == true)
              _infoRow(Icons.label_outline, 'Marca',
                  m['marca'].toString()),
            if (m['capacidad_volumetrica']?.toString().isNotEmpty == true)
              _infoRow(Icons.water_drop_outlined, 'Capacidad',
                  m['capacidad_volumetrica'].toString()),
            if (m['material']?.toString().isNotEmpty == true)
              _infoRow(Icons.texture_outlined, 'Material',
                  m['material'].toString()),
            _infoRow(
              Icons.check_circle_outline,
              'Graduado',
              m['es_graduado'] == true ? 'Sí' : 'No',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovRow(Map<String, dynamic> m) {
    final tipo = m['tipo_movimiento']?.toString() ?? '';
    final esEntrada = tipo == 'ENTRADA';
    final color = esEntrada ? kSuccess : kDanger;
    final icon = esEntrada ? Icons.arrow_downward : Icons.arrow_upward;
    final fecha = (m['fecha_hora']?.toString() ?? '')
        .replaceFirst('T', ' ')
        .substring(0, (m['fecha_hora']?.toString().length ?? 16).clamp(0, 16));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${m['username'] ?? '?'}  ·  $fecha',
            style: const TextStyle(fontSize: 12, color: kTextMuted),
          ),
        ),
        Text(
          '${esEntrada ? '+' : '-'}${m['cantidad']}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ]),
    );
  }

  Widget _buildPresentaciones(List<Map<String, dynamic>> presentaciones, double stockMin,
      {bool puedeGestionar = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header azul
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: kPrimary,
            child: const Row(children: [
              Icon(Icons.inventory_2_outlined, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Presentaciones',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ]),
          ),
          // Filas de presentación
          ...presentaciones.asMap().entries.map((e) {
            final idx   = e.key;
            final p     = e.value;
            final stock = double.tryParse(p['stock_actual']?.toString() ?? '0') ?? 0;
            final unidad = p['unidad_nombre']?.toString() ?? '';
            final activa = presentacionActiva(p);

            final (chipLabel, chipColor, chipBg) = !activa
                ? ('INACTIVA', kTextMuted,         const Color(0xFFE9ECEF))
                : stock <= 0
                ? ('SIN STOCK', kDanger,           const Color(0xFFFFEBEE))
                : stock <= stockMin
                    ? ('CRÍTICO',  kSemaforoRojo,    const Color(0xFFFFEBEE))
                    : stock <= stockMin * 1.5
                        ? ('BAJO',     const Color(0xFFE65100), const Color(0xFFFFF8E1))
                        : ('OK',       kSemaforoVerde, const Color(0xFFE8F5E9));

            return Container(
              decoration: BoxDecoration(
                color: idx.isOdd ? const Color(0xFFF8F9FA) : Colors.white,
                border: const Border(bottom: BorderSide(color: Color(0xFFDEE2E6))),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                // Ícono frasco
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9ECEF),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.science_outlined, size: 18, color: kTextMuted),
                ),
                const SizedBox(width: 12),
                // Nombre presentación
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(unidad, style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13,
                        color: activa ? null : kTextMuted,
                        decoration: activa ? null : TextDecoration.lineThrough)),
                    Text(
                        activa
                            ? '${stock.toStringAsFixed(stock.truncateToDouble() == stock ? 0 : 2)} $unidad disponibles'
                            : '${stock.toStringAsFixed(stock.truncateToDouble() == stock ? 0 : 2)} $unidad · no se presta ni cuenta en el total',
                        style: const TextStyle(fontSize: 11, color: kTextMuted)),
                  ]),
                ),
                // Chip estado
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(20)),
                  child: Text(chipLabel,
                      style: TextStyle(color: chipColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                if (puedeGestionar)
                  PopupMenuButton<bool>(
                    tooltip: 'Opciones de la presentación',
                    icon: const Icon(Icons.more_vert, size: 18, color: kTextMuted),
                    onSelected: (activar) => _cambiarEstadoPresentacion(p, activar),
                    itemBuilder: (_) => [
                      activa
                          ? const PopupMenuItem(
                              value: false,
                              child: ListTile(
                                dense: true,
                                leading: Icon(Icons.block, color: kDanger, size: 18),
                                title: Text('Desactivar'),
                              ))
                          : const PopupMenuItem(
                              value: true,
                              child: ListTile(
                                dense: true,
                                leading: Icon(Icons.restore, color: kSuccess, size: 18),
                                title: Text('Reactivar'),
                              )),
                    ],
                  ),
              ]),
            );
          }),
        ]),
      ),
    );
  }

  Widget _stockCard(String label, String value, Color color) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: color, width: 3)),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(color: kTextMuted, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: color,
              )),
        ]),
      );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 15, color: kTextMuted),
          const SizedBox(width: 6),
          Text('$label: ',
              style: const TextStyle(color: kTextMuted, fontSize: 13)),
          Expanded(
              child: Text(value, style: const TextStyle(fontSize: 13))),
        ]),
      );

  Widget _seccion(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: kPrimary,
              fontSize: 14,
            )),
      );
}
