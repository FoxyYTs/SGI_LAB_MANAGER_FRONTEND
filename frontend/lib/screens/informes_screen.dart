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
                                // Tarjetas más compactas en multi-columna
                                childAspectRatio: crossCount == 1 ? 2.2 : 1.65,
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
    final ultimaVez = _formatUltimo(widget.ultimo?['generado_en']?.toString());

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabecera: icono + título ───────────────────────────────
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(widget.tipo.icon, color: kPrimary, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.tipo.label,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('Último: $ultimaVez',
                      style: const TextStyle(color: Colors.black38, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              )),
            ]),

            const Spacer(),

            // ── Filtros de fecha (si aplica) ──────────────────────────
            if (widget.tipo.conFechas) ...[
              Row(children: [
                Expanded(child: _FechaBtn(
                  label: _desde != null ? _label(_desde!) : 'Desde',
                  onTap: () => _seleccionarFecha(true),
                  onClear: _desde != null ? () => setState(() => _desde = null) : null,
                )),
                const SizedBox(width: 6),
                Expanded(child: _FechaBtn(
                  label: _hasta != null ? _label(_hasta!) : 'Hasta',
                  onTap: () => _seleccionarFecha(false),
                  onClear: _hasta != null ? () => setState(() => _hasta = null) : null,
                )),
              ]),
              const SizedBox(height: 8),
            ],

            // ── Botones de descarga ───────────────────────────────────
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _descargando ? null : _descargar,
                  icon: _descargando
                      ? const SizedBox(width: 12, height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.picture_as_pdf_outlined, size: 14),
                  label: Text(_descargando ? '…' : 'PDF',
                      style: const TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
              if (widget.tipo.endpointExcel != null) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _descargandoExcel ? null : _descargarExcel,
                    icon: _descargandoExcel
                        ? const SizedBox(width: 12, height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.table_chart_outlined, size: 14),
                    label: Text(_descargandoExcel ? '…' : 'Excel',
                        style: const TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF217346),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
              ],
            ]),
          ],
        ),
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
