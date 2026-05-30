import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api/api_client.dart';
import '../core/theme/colors.dart';
import '../core/cache/cache_service.dart';
import '../providers/auth_provider.dart';
import '../core/sync/sync_service.dart';
import '../widgets/qr_generator_dialog.dart';

class DashboardContent extends StatefulWidget {
  const DashboardContent({super.key});
  @override State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  static const _cacheKey = 'dashboard';

  Map<String, dynamic>? _data;
  bool      _cargando   = true;
  bool      _desdeCache = false;
  DateTime? _cachedAt;
  bool      _eraOnline  = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_cargar);
    _eraOnline = SyncService.instance.online;
    SyncService.instance.addListener(_onSync);
  }

  void _onSync() {
    final ahoraOnline = SyncService.instance.online;
    if (!_eraOnline && ahoraOnline && mounted) _cargar();
    _eraOnline = ahoraOnline;
  }

  @override
  void dispose() {
    SyncService.instance.removeListener(_onSync);
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final auth = context.read<AuthProvider>();
    final dio  = ApiClient.instance.authenticatedDio(auth.token);
    try {
      final r = await dio.get('academico/dashboard/');
      final data = Map<String, dynamic>.from(r.data);
      await CacheService.instance.set(_cacheKey, data);
      if (mounted) setState(() { _data = data; _desdeCache = false; _cachedAt = null; _cargando = false; });
    } catch (_) {
      final cached = await CacheService.instance.get(_cacheKey);
      if (mounted) setState(() {
        _data       = cached != null ? Map<String, dynamic>.from(cached.data as Map) : null;
        _desdeCache = cached != null;
        _cachedAt   = cached?.cachedAt;
        _cargando   = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;
        final hPad = isMobile ? 14.0 : 24.0;
        return SingleChildScrollView(
          padding: EdgeInsets.all(hPad),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_desdeCache)
                    _CacheBanner(cachedAt: _cachedAt, onRefresh: _cargar),
                  if (_desdeCache) SizedBox(height: isMobile ? 10 : 14),
                  _buildJumbotron(auth, isMobile),
                  SizedBox(height: isMobile ? 14 : 20),
                  if (_cargando)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: kPrimary),
                    ))
                  else if (_data != null) ...[
                    _buildStatCards(constraints.maxWidth, isMobile),
                    SizedBox(height: isMobile ? 14 : 24),
                    _buildCriticosTable(isMobile),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Jumbotron ─────────────────────────────────────────────────────────────

  Widget _buildJumbotron(AuthProvider auth, bool isMobile) {
    final texto = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hola, ${auth.username ?? 'bienvenido'}',
          style: TextStyle(
            fontSize: isMobile ? 20 : 26,
            fontWeight: FontWeight.w300,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'SGI LAB MANAGER — Laboratorios de Ciencias Basicas Poli Rionegro',
          style: TextStyle(fontSize: isMobile ? 12 : 14, color: kTextMuted),
        ),
      ],
    );

    final botonQr = ElevatedButton.icon(
      onPressed: () => showDialog(
        context: context,
        builder: (_) => const QrGeneratorDialog(),
      ),
      icon: const Icon(Icons.qr_code_2),
      label: const Text('Códigos QR'),
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 20 : 32,
        horizontal: isMobile ? 16 : 28,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: isMobile
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              texto,
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: botonQr),
            ])
          : Row(children: [
              Expanded(child: texto),
              botonQr,
            ]),
    );
  }

  // ── Tarjetas de estadísticas ───────────────────────────────────────────────

  Widget _buildStatCards(double availableWidth, bool isMobile) {
    final crossCount = isMobile ? 2 : (availableWidth < 900 ? 4 : 5);
    final aspectRatio = isMobile ? 1.5 : 1.9;

    final cards = [
      _statCard(Icons.warning_amber_rounded,  'Insumos críticos',   '${_data!['stock_critico']        ?? 0}', kSemaforoRojo,    const Color(0xFFFFEBEE)),
      _statCard(Icons.info_outline,           'Insumos bajos',      '${_data!['stock_bajo']           ?? 0}', const Color(0xFFE65100), const Color(0xFFFFF3E0)),
      _statCard(Icons.swap_horiz_outlined,    'Préstamos activos',  '${_data!['prestamos_activos']    ?? 0}', kPrimary,         const Color(0xFFE3F2FD)),
      _statCard(Icons.hourglass_top_outlined, 'Por aprobar',        '${_data!['prestamos_pendientes'] ?? 0}', const Color(0xFFE65100), const Color(0xFFFFF8E1)),
      if (!isMobile)
        _statCard(Icons.inventory_2_outlined, 'Total insumos',      '${_data!['total_insumos']        ?? 0}', kPrimary,         const Color(0xFFE8F5E9)),
    ];

    return GridView.count(
      crossAxisCount: crossCount,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: aspectRatio,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cards,
    );
  }

  Widget _statCard(IconData icon, String label, String value, Color color, Color bgColor) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const Spacer(),
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color, height: 1)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color.withValues(alpha: 0.75), fontSize: 11, fontWeight: FontWeight.w500),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      );

  // ── Tabla de stock crítico ─────────────────────────────────────────────────

  Widget _buildCriticosTable(bool isMobile) {
    final lista = _data!['lista_criticos'] as List?;
    if (lista?.isNotEmpty != true) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.check_circle_outline, size: 48, color: kSuccess),
            const SizedBox(height: 10),
            const Text('Todo el inventario tiene stock suficiente',
                style: TextStyle(color: kTextMuted)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Actualizar'),
            ),
          ]),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.warning_amber_rounded, color: kSemaforoRojo, size: 20),
        const SizedBox(width: 8),
        const Text('Insumos en stock crítico',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const Spacer(),
        TextButton.icon(
          onPressed: _cargar,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Actualizar'),
        ),
      ]),
      const SizedBox(height: 10),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          // Scroll horizontal en móvil para la tabla con columnas fijas
          child: SingleChildScrollView(
            scrollDirection: isMobile ? Axis.horizontal : Axis.vertical,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: isMobile ? 360 : 0,
              ),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(3),
                  1: FixedColumnWidth(100),
                  2: FixedColumnWidth(100),
                },
                border: const TableBorder(
                    horizontalInside: BorderSide(color: Color(0xFFDEE2E6))),
                children: [
                  _headerRow(['Insumo', 'Stock actual', 'Mínimo']),
                  ...lista!.asMap().entries.map((e) {
                    final idx  = e.key;
                    final ins  = e.value as Map<String, dynamic>;
                    final stock    = double.tryParse(ins['stock_actual'].toString()) ?? 0;
                    final stockMin = double.tryParse(ins['stock_minimo'].toString()) ?? 0;
                    return TableRow(
                      decoration: BoxDecoration(
                          color: idx.isOdd ? const Color(0xFFF8F9FA) : Colors.white),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(children: [
                            Container(width: 8, height: 8,
                                decoration: const BoxDecoration(
                                    color: kSemaforoRojo, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(ins['nombre_insumo']?.toString() ?? '',
                                style: const TextStyle(fontWeight: FontWeight.w500))),
                          ]),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Text(stock.toStringAsFixed(1),
                              style: const TextStyle(color: kSemaforoRojo, fontWeight: FontWeight.bold)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Text(stockMin.toStringAsFixed(1),
                              style: const TextStyle(color: kTextMuted)),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  TableRow _headerRow(List<String> cols) => TableRow(
    decoration: const BoxDecoration(color: kPrimary),
    children: cols.map((h) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(h,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
    )).toList(),
  );
}

class _CacheBanner extends StatelessWidget {
  final DateTime? cachedAt;
  final VoidCallback onRefresh;
  const _CacheBanner({required this.cachedAt, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final edad = cachedAt != null ? CacheService.formatEdad(cachedAt!) : 'desconocido';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kSemaforoAmarillo),
      ),
      child: Row(children: [
        const Icon(Icons.history, color: Color(0xFFE65100), size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(
          'Mostrando datos guardados ($edad)',
          style: const TextStyle(fontSize: 12, color: Color(0xFFE65100)),
        )),
        GestureDetector(
          onTap: onRefresh,
          child: const Icon(Icons.refresh, color: Color(0xFFE65100), size: 16),
        ),
      ]),
    );
  }
}
