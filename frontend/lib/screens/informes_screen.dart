import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api/api_client.dart';
import '../core/theme/colors.dart';
import '../providers/auth_provider.dart';

class InformesContent extends StatefulWidget {
  const InformesContent({super.key});
  @override
  State<InformesContent> createState() => _InformesContentState();
}

class _InformesContentState extends State<InformesContent> {
  Map<String, dynamic> _ultimosInformes = {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final auth = context.read<AuthProvider>();
    try {
      final dio = ApiClient.instance.authenticatedDio(auth.token!);
      final r = await dio.get('academico/ultimo-informe/');
      setState(() {
        _ultimosInformes = Map<String, dynamic>.from(r.data);
        _cargando = false;
      });
    } catch (_) {
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : RefreshIndicator(
              color: kPrimary,
              onRefresh: _cargar,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Generación de Informes',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold, color: kPrimary)),
                    const SizedBox(height: 4),
                    const Text('Descarga informes en PDF. Puedes filtrar por rango de fechas.',
                        style: TextStyle(fontSize: 13, color: Colors.black54)),
                    const SizedBox(height: 20),
                    ..._tiposInforme.map((t) => _InformeTile(
                          tipo: t,
                          ultimo: _ultimosInformes[t.codigo],
                          onDescargado: _cargar,
                        )),
                  ],
                ),
              ),
            ),
    );
  }
}

// ── Tipos de informe ─────────────────────────────────────────────────────────

class _TipoInforme {
  final String codigo;
  final String label;
  final String endpoint;
  final IconData icon;
  final bool conFechas;
  const _TipoInforme({
    required this.codigo,
    required this.label,
    required this.endpoint,
    required this.icon,
    this.conFechas = true,
  });
}

const _tiposInforme = [
  _TipoInforme(
    codigo:    'INVENTARIO',
    label:     'Inventario',
    endpoint:  'academico/informes/inventario/',
    icon:      Icons.inventory_2_outlined,
    conFechas: false,
  ),
  _TipoInforme(
    codigo:   'PRESTAMOS',
    label:    'Préstamos',
    endpoint: 'academico/informes/prestamos/',
    icon:     Icons.swap_horiz_outlined,
  ),
  _TipoInforme(
    codigo:   'BITACORA',
    label:    'Bitácora de movimientos',
    endpoint: 'academico/informes/bitacora/',
    icon:     Icons.history_outlined,
  ),
  _TipoInforme(
    codigo:   'HORAS_MONITOR',
    label:    'Horas de monitor',
    endpoint: 'academico/informes/horas-monitor/',
    icon:     Icons.timer_outlined,
  ),
  _TipoInforme(
    codigo:   'PRACTICAS',
    label:    'Prácticas de laboratorio',
    endpoint: 'academico/informes/practicas/',
    icon:     Icons.science_outlined,
  ),
  _TipoInforme(
    codigo:   'DEUDORES',
    label:    'Deudores morosos',
    endpoint: 'academico/informes/deudores/',
    icon:     Icons.report_outlined,
  ),
];

// ── Tile individual ──────────────────────────────────────────────────────────

class _InformeTile extends StatefulWidget {
  final _TipoInforme tipo;
  final dynamic ultimo;
  final VoidCallback onDescargado;

  const _InformeTile({
    required this.tipo,
    required this.ultimo,
    required this.onDescargado,
  });

  @override
  State<_InformeTile> createState() => _InformeTileState();
}

class _InformeTileState extends State<_InformeTile> {
  DateTime? _desde;
  DateTime? _hasta;
  bool _descargando = false;

  Future<void> _seleccionarFecha(bool esDesde) async {
    final initial = esDesde
        ? (_desde ?? DateTime.now().subtract(const Duration(days: 30)))
        : (_hasta ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx)
            .copyWith(colorScheme: const ColorScheme.light(primary: kPrimary)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() { if (esDesde) _desde = picked; else _hasta = picked; });
    }
  }

  String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _label(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

  String _formatUltimo(String? iso) {
    if (iso == null) return 'Nunca generado';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year} '
          '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) {
      return iso;
    }
  }

  Future<void> _descargar() async {
    final auth = context.read<AuthProvider>();
    setState(() => _descargando = true);
    try {
      final params = <String, dynamic>{};
      if (widget.tipo.conFechas) {
        if (_desde != null) params['fecha_desde'] = _iso(_desde!);
        if (_hasta  != null) params['fecha_hasta'] = _iso(_hasta!);
      }

      final dio = ApiClient.instance.authenticatedDio(auth.token!);
      final response = await dio.get<List<int>>(
        widget.tipo.endpoint,
        queryParameters: params.isNotEmpty ? params : null,
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data!;
      final tmp   = Directory.systemTemp;
      final fname = '${widget.tipo.codigo.toLowerCase()}_${_iso(DateTime.now())}.pdf';
      final file  = File('${tmp.path}/$fname');
      await file.writeAsBytes(bytes);

      final uri = Uri.file(file.path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Archivo guardado en: ${file.path}')),
        );
      }

      widget.onDescargado();
    } catch (e) {
      if (mounted) {
        String msg = 'Error al generar el informe.';
        try {
          final data = (e as dynamic).response?.data;
          if (data is Map) msg = data.values.first.toString();
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red[700]),
        );
      }
    } finally {
      if (mounted) setState(() => _descargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ultimaVez = _formatUltimo(widget.ultimo?['generado_en']?.toString());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(widget.tipo.icon, color: kPrimary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.tipo.label,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text('Último: $ultimaVez',
                  style: const TextStyle(color: Colors.black45, fontSize: 11)),
            ])),
          ]),

          if (widget.tipo.conFechas) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _FechaBtn(
                label: _desde != null ? 'Desde: ${_label(_desde!)}' : 'Desde (opcional)',
                onTap: () => _seleccionarFecha(true),
                onClear: _desde != null ? () => setState(() => _desde = null) : null,
              )),
              const SizedBox(width: 8),
              Expanded(child: _FechaBtn(
                label: _hasta != null ? 'Hasta: ${_label(_hasta!)}' : 'Hasta (opcional)',
                onTap: () => _seleccionarFecha(false),
                onClear: _hasta != null ? () => setState(() => _hasta = null) : null,
              )),
            ]),
          ],

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _descargando ? null : _descargar,
              icon: _descargando
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.picture_as_pdf_outlined, size: 16),
              label: Text(_descargando ? 'Generando…' : 'Descargar PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _FechaBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _FechaBtn({required this.label, required this.onTap, this.onClear});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: kPrimary,
        side: const BorderSide(color: Color(0xFFCCCCCC)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(fontSize: 11),
      ),
      onPressed: onTap,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.calendar_today_outlined, size: 13),
        const SizedBox(width: 4),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        if (onClear != null) ...[
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onClear,
            child: const Icon(Icons.close, size: 13, color: Colors.black54),
          ),
        ],
      ]),
    );
  }
}
