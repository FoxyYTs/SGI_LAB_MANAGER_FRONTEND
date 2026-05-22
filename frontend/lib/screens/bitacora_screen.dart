import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api/api_client.dart';
import '../core/theme/colors.dart';
import '../providers/auth_provider.dart';

class BitacoraContent extends StatefulWidget {
  const BitacoraContent({super.key});

  @override
  State<BitacoraContent> createState() => _BitacoraContentState();
}

class _BitacoraContentState extends State<BitacoraContent> {
  List<Map<String, dynamic>> _movimientos = [];
  bool   _cargando  = true;
  String _filtroTipo = 'Todos';

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

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final auth = context.read<AuthProvider>();
      final dio  = ApiClient.instance.authenticatedDio(auth.token);
      final params = _filtroTipo == 'Todos' ? '' : '?tipo=$_filtroTipo';
      final r = await dio.get('operaciones/bitacora/$params');
      final data = r.data;
      setState(() {
        _movimientos = List<Map<String, dynamic>>.from(
            data is List ? data : (data['results'] ?? []));
        _cargando = false;
      });
    } catch (_) {
      setState(() => _cargando = false);
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Encabezado ────────────────────────────────────────────────
          Row(children: [
            const Text('Bitácora de movimientos',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Actualizar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
            ),
          ]),
          const SizedBox(height: 12),

          // ── Chips de filtro ───────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _tipos.map((tipo) {
                final sel = _filtroTipo == tipo;
                final color = tipo == 'Todos' ? kPrimary : _colorTipo(tipo);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_labels[tipo] ?? tipo),
                    selected: sel,
                    selectedColor: color,
                    labelStyle: TextStyle(
                      color: sel ? Colors.white : kTextMuted,
                      fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) {
                      setState(() => _filtroTipo = tipo);
                      _cargar();
                    },
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
                    : Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SingleChildScrollView(
                            child: _buildTabla(),
                          ),
                        ),
                      ),
          ),
        ],
      ),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_iconTipo(tipo), size: 14, color: color),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(_labels[tipo] ?? tipo,
                        style: TextStyle(color: color, fontSize: 12,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
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
