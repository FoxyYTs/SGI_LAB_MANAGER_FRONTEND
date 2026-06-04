import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api/api_client.dart';
import '../core/download_helper.dart';
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
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    try {
      final dio = ApiClient.instance.authenticatedDio(auth.token!);
      final r = await dio.get('academico/ultimo-informe/');
      if (!mounted) return;
      setState(() {
        _ultimosInformes = Map<String, dynamic>.from(r.data);
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                // En pantallas anchas (desktop) el grid no supera 1100 px.
                constraints: const BoxConstraints(maxWidth: 1100),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final crossCount = w < 500 ? 1 : (w < 720 ? 2 : 3);
                    return RefreshIndicator(
                      color: kPrimary,
                      onRefresh: _cargar,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Generación de Informes',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: kPrimary)),
                                  const SizedBox(height: 4),
                                  const Text(
                                      'Descarga informes en PDF o Excel. Puedes filtrar por rango de fechas.',
                                      style: TextStyle(fontSize: 13, color: Colors.black54)),
                                  const SizedBox(height: 12),
                                ],
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            sliver: SliverGrid(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final t = _tiposInforme[index];
                                  return _InformeTile(
                                    tipo: t,
                                    ultimo: _ultimosInformes[t.codigo],
                                    onDescargado: _cargar,
                                  );
                                },
                                childCount: _tiposInforme.length,
                              ),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossCount,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: crossCount == 1 ? 1.9 : 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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
  final String? endpointExcel;
  final IconData icon;
  final bool conFechas;
  const _TipoInforme({
    required this.codigo,
    required this.label,
    required this.endpoint,
    this.endpointExcel,
    required this.icon,
    this.conFechas = true,
  });
}

const _tiposInforme = [
  _TipoInforme(
    codigo:        'INVENTARIO',
    label:         'Inventario',
    endpoint:      'academico/informes/inventario/',
    endpointExcel: 'academico/informes/inventario-excel/',
    icon:          Icons.inventory_2_outlined,
    conFechas:     false,
  ),
  _TipoInforme(
    codigo:        'PRESTAMOS',
    label:         'Préstamos',
    endpoint:      'academico/informes/prestamos/',
    endpointExcel: 'academico/informes/prestamos-excel/',
    icon:          Icons.swap_horiz_outlined,
  ),
  _TipoInforme(
    codigo:        'BITACORA',
    label:         'Bitácora de movimientos',
    endpoint:      'academico/informes/bitacora/',
    endpointExcel: 'academico/informes/bitacora-excel/',
    icon:          Icons.history_outlined,
  ),
  _TipoInforme(
    codigo:        'HORAS_MONITOR',
    label:         'Horas de monitor',
    endpoint:      'academico/informes/horas-monitor/',
    endpointExcel: 'academico/informes/horas-monitor-excel/',
    icon:          Icons.timer_outlined,
  ),
  _TipoInforme(
    codigo:        'PRACTICAS',
    label:         'Prácticas de laboratorio',
    endpoint:      'academico/informes/practicas/',
    endpointExcel: 'academico/informes/practicas-excel/',
    icon:          Icons.science_outlined,
  ),
  _TipoInforme(
    codigo:        'DEUDORES',
    label:         'Deudores morosos',
    endpoint:      'academico/informes/deudores/',
    endpointExcel: 'academico/informes/deudores-excel/',
    icon:          Icons.report_outlined,
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
  bool _descargando      = false;
  bool _descargandoExcel = false;

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

  Map<String, dynamic> get _params {
    final p = <String, dynamic>{};
    if (widget.tipo.conFechas) {
      if (_desde != null) p['fecha_desde'] = _iso(_desde!);
      if (_hasta  != null) p['fecha_hasta'] = _iso(_hasta!);
    }
    return p;
  }

  Future<void> _descargarArchivo(String endpoint, String extension, void Function(bool) setLoading) async {
    final auth = context.read<AuthProvider>();
    setLoading(true);
    try {
      final params = _params;
      final dio    = ApiClient.instance.authenticatedDio(auth.token!);
      final response = await dio.get<List<int>>(
        endpoint,
        queryParameters: params.isNotEmpty ? params : null,
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data!;
      final fname = '${widget.tipo.codigo.toLowerCase()}_${_iso(DateTime.now())}.$extension';
      final msg = await saveAndOpenFile(bytes, fname);
      if (msg != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
      if (mounted) setLoading(false);
    }
  }

  Future<void> _descargar() => _descargarArchivo(
        widget.tipo.endpoint, 'pdf',
        (v) => setState(() => _descargando = v));

  Future<void> _descargarExcel() => _descargarArchivo(
        widget.tipo.endpointExcel!, 'xlsx',
        (v) => setState(() => _descargandoExcel = v));

  @override
  Widget build(BuildContext context) {
    final ultimaVez  = _formatUltimo(widget.ultimo?['generado_en']?.toString());
    final nunca      = widget.ultimo?['generado_en'] == null;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header azul ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: kPrimary,
            child: Row(children: [
              Icon(widget.tipo.icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.tipo.label,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis)),
            ]),
          ),
          // ── Cuerpo ────────────────────────────────────────────────────
          Expanded(child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Último generado
                Row(children: [
                  Icon(Icons.access_time_outlined, size: 13,
                      color: nunca ? kTextMuted : kPrimary),
                  const SizedBox(width: 4),
                  Expanded(child: Text(
                    'Último: $ultimaVez',
                    style: TextStyle(
                        fontSize: 11,
                        color: nunca ? kTextMuted : const Color(0xFF223542),
                        fontStyle: nunca ? FontStyle.italic : FontStyle.normal),
                    overflow: TextOverflow.ellipsis,
                  )),
                ]),
                const Spacer(),

                // Filtros de fecha (si aplica)
                if (widget.tipo.conFechas) ...[
                  Row(children: [
                    Expanded(child: _fechaBtn(
                        _desde != null ? _label(_desde!) : 'Desde',
                        () => _seleccionarFecha(true),
                        _desde != null)),
                    const SizedBox(width: 6),
                    Expanded(child: _fechaBtn(
                        _hasta != null ? _label(_hasta!) : 'Hasta',
                        () => _seleccionarFecha(false),
                        _hasta != null)),
                  ]),
                  const SizedBox(height: 8),
                ],

                // Botones PDF + Excel
                Row(children: [
                  Expanded(child: _btnDescarga(
                    label: 'PDF',
                    icon: Icons.picture_as_pdf_outlined,
                    color: kDanger,
                    loading: _descargando,
                    onTap: _descargar,
                  )),
                  if (widget.tipo.endpointExcel != null) ...[
                    const SizedBox(width: 6),
                    Expanded(child: _btnDescarga(
                      label: 'Excel',
                      icon: Icons.table_chart_outlined,
                      color: kSemaforoVerde,
                      loading: _descargandoExcel,
                      onTap: _descargarExcel,
                    )),
                  ],
                ]),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _fechaBtn(String label, VoidCallback onTap, bool activo) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: activo ? kPrimary.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: activo ? kPrimary : const Color(0xFFCED4DA)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.calendar_today_outlined, size: 12,
                color: activo ? kPrimary : kTextMuted),
            const SizedBox(width: 4),
            Flexible(child: Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: activo ? kPrimary : kTextMuted,
                    fontWeight: activo ? FontWeight.w600 : FontWeight.normal),
                overflow: TextOverflow.ellipsis)),
          ]),
        ),
      );

  Widget _btnDescarga({
    required String label,
    required IconData icon,
    required Color color,
    required bool loading,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: loading ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
          child: loading
              ? const Center(child: SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icon, color: Colors.white, size: 14),
                  const SizedBox(width: 5),
                  Text(label, style: const TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ]),
        ),
      );

}
