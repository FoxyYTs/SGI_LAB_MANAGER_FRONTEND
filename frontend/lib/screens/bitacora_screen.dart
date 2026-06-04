import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api/api_client.dart';
import '../core/theme/colors.dart';
import '../core/cache/cache_service.dart';
import '../providers/auth_provider.dart';

class BitacoraContent extends StatefulWidget {
  const BitacoraContent({super.key});

  @override
  State<BitacoraContent> createState() => _BitacoraContentState();
}

class _BitacoraContentState extends State<BitacoraContent> {
  List<Map<String, dynamic>> _movimientos = [];
  bool      _cargando   = true;
  bool      _desdeCache = false;
  DateTime? _cachedAt;
  String    _filtroTipo = 'Todos';

  static const _tipos = [
    'Todos', 'ENTRADA', 'SALIDA', 'AJUSTE', 'ROTURA', 'CONSUMO_PRACTICA',
  ];

  static const _labels = {
    'ENTRADA':           'Entrada',
    'SALIDA':            'Salida',
    'AJUSTE':            'Ajuste',
    'ROTURA':            'Rotura',
    'CONSUMO_PRACTICA':  'Consumo práctica',
  };

  @override
  void initState() {
    super.initState();
    Future.microtask(_cargar);
  }

  String get _cacheKey => 'bitacora_$_filtroTipo';

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final auth   = context.read<AuthProvider>();
      final dio    = ApiClient.instance.authenticatedDio(auth.token);
      final params = _filtroTipo == 'Todos' ? '' : '?tipo=$_filtroTipo';
      final r      = await dio.get('operaciones/bitacora/$params');
      final data   = r.data;
      final lista  = List<Map<String, dynamic>>.from(
          data is List ? data : (data['results'] ?? []));
      await CacheService.instance.set(_cacheKey, lista);
      if (mounted) setState(() {
        _movimientos = lista;
        _desdeCache  = false;
        _cachedAt    = null;
        _cargando    = false;
      });
    } catch (_) {
      final cached = await CacheService.instance.get(_cacheKey);
      if (mounted) setState(() {
        _movimientos = cached != null
            ? List<Map<String, dynamic>>.from(cached.data as List)
            : [];
        _desdeCache  = cached != null;
        _cachedAt    = cached?.cachedAt;
        _cargando    = false;
      });
    }
  }

  Color _colorTipo(String tipo) => switch (tipo) {
    'ENTRADA'           => kSuccess,
    'SALIDA'            => kDanger,
    'AJUSTE'            => kPrimary,
    'ROTURA'            => kWarning,
    'CONSUMO_PRACTICA'  => const Color(0xFF9C27B0),
    _                   => kTextMuted,
  };

  IconData _iconTipo(String tipo) => switch (tipo) {
    'ENTRADA'           => Icons.arrow_downward,
    'SALIDA'            => Icons.arrow_upward,
    'AJUSTE'            => Icons.tune,
    'ROTURA'            => Icons.broken_image_outlined,
    'CONSUMO_PRACTICA'  => Icons.science_outlined,
    _                   => Icons.swap_horiz,
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = constraints.maxWidth < 650 ? 14.0 : 24.0;
        return Padding(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Banner caché ──────────────────────────────────────────────
          if (_desdeCache) ...[
            Container(
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
                  'Datos guardados (${_cachedAt != null ? CacheService.formatEdad(_cachedAt!) : "—"})',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFE65100)),
                )),
              ]),
            ),
            const SizedBox(height: 10),
          ],
          // ── Encabezado ────────────────────────────────────────────────
          Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Bitácora de movimientos',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Text('Historial de entradas, salidas y ajustes de stock',
                  style: TextStyle(fontSize: 12, color: kTextMuted)),
            ]),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh, color: kPrimary, size: 20),
              tooltip: 'Actualizar',
              onPressed: _cargar,
            ),
          ]),
          const SizedBox(height: 12),

          // ── Chips de filtro pill ──────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _tipos.map((tipo) {
                final sel   = _filtroTipo == tipo;
                final color = tipo == 'Todos' ? kPrimary : _colorTipo(tipo);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _filtroTipo = tipo);
                      _cargar();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel ? color : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? color : const Color(0xFFDEE2E6)),
                      ),
                      child: Text(
                        _labels[tipo] ?? tipo,
                        style: TextStyle(
                          fontSize: 12,
                          color: sel ? Colors.white : kTextMuted,
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // ── Lista ─────────────────────────────────────────────────────
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator(color: kPrimary))
                : _movimientos.isEmpty
                    ? Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.history, size: 64, color: kTextMuted),
                          const SizedBox(height: 12),
                          Text(
                            _filtroTipo == 'Todos'
                                ? 'No hay movimientos registrados'
                                : 'Sin movimientos de tipo "${_labels[_filtroTipo] ?? _filtroTipo}"',
                            style: const TextStyle(color: kTextMuted),
                          ),
                        ]),
                      )
                    : Column(children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SingleChildScrollView(child: _buildTabla()),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Mostrando ${_movimientos.length} movimiento${_movimientos.length != 1 ? "s" : ""}',
                            style: const TextStyle(fontSize: 12, color: kTextMuted),
                          ),
                        ),
                      ]),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildTabla() {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(2),
        2: FixedColumnWidth(110),
        3: FixedColumnWidth(80),
        4: FlexColumnWidth(1.5),
      },
      border: const TableBorder(
          horizontalInside: BorderSide(color: Color(0xFFDEE2E6))),
      children: [
        _headerRow(['Insumo', 'Tipo', 'Fecha', 'Cantidad', 'Usuario']),
        ..._movimientos.asMap().entries.map((e) {
          final idx = e.key;
          final m   = e.value;
          final tipo  = m['tipo_movimiento']?.toString() ?? '';
          final color = _colorTipo(tipo);
          final fecha = (m['fecha_hora']?.toString() ?? '')
              .replaceFirst('T', ' ')
              .substring(0, (m['fecha_hora']?.toString().length ?? 16).clamp(0, 16));

          return TableRow(
            decoration: BoxDecoration(
                color: idx.isOdd ? const Color(0xFFF8F9FA) : Colors.white),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Text(m['nombre_insumo']?.toString() ?? '—',
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: _chipTipo(tipo),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Text(fecha,
                    style: const TextStyle(fontSize: 12, color: kTextMuted)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Text(
                  '${tipo == 'ENTRADA' ? '+' : tipo == 'SALIDA' || tipo == 'ROTURA' || tipo == 'CONSUMO_PRACTICA' ? '-' : '±'}${m['cantidad']}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Text(m['username']?.toString() ?? '—',
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _chipTipo(String tipo) {
    final color = _colorTipo(tipo);
    final bg    = switch (tipo) {
      'ENTRADA'          => const Color(0xFFE8F5E9),
      'SALIDA'           => const Color(0xFFFFEBEE),
      'AJUSTE'           => const Color(0xFFE3F2FD),
      'ROTURA'           => const Color(0xFFFFF8E1),
      'CONSUMO_PRACTICA' => const Color(0xFFF3E5F5),
      _                  => const Color(0xFFF5F5F5),
    };
    final label = _labels[tipo] ?? tipo;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_iconTipo(tipo), size: 12, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  TableRow _headerRow(List<String> cols) => TableRow(
    decoration: const BoxDecoration(color: kPrimary),
    children: cols.map((h) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Text(h,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
    )).toList(),
  );
}
