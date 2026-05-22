import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api/api_client.dart';
import '../core/theme/colors.dart';
import '../core/permissions.dart';
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
        dio.get('operaciones/bitacora/?insumo=${widget.insumoId}&limit=8'),
      ]);
      final bData = results[1].data;
      setState(() {
        _insumo = Map<String, dynamic>.from(results[0].data);
        _movimientos = List<Map<String, dynamic>>.from(
          bData is List ? bData : (bData['results'] ?? []));
        _cargando = false;
      });
    } catch (_) {
      setState(() => _cargando = false);
    }
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
    final stock = double.tryParse(d['stock_actual']?.toString() ?? '0') ?? 0;
    final stockMin = double.tryParse(d['stock_minimo']?.toString() ?? '0') ?? 0;
    final unidad = d['unidad_abreviatura']?.toString() ?? '';

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
                  _infoRow(Icons.straighten_outlined, 'Unidad', unidad),
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
