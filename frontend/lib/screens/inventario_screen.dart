import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/inventario_provider.dart';
import '../providers/auth_provider.dart';
import '../models/insumo_model.dart';
import '../core/theme/colors.dart';
import '../core/permissions.dart';
import 'insumo_form_screen.dart';
import 'insumo_detail_screen.dart';
import 'sga_screen.dart';

class InventarioContent extends StatefulWidget {
  const InventarioContent({super.key});

  @override
  State<InventarioContent> createState() => _InventarioContentState();
}

class _InventarioContentState extends State<InventarioContent> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _filtroTipo  = 'Todos';
  String _sortCol     = 'nombre';
  bool   _sortAsc     = true;

  static const _tipos = ['Todos', 'Implemento', 'Vidriería', 'Equipo', 'Químico'];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      Provider.of<InventarioProvider>(context, listen: false).fetchInsumos(auth.token);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _semaforoColor(String s) => switch (s) {
    'ROJO'    => kSemaforoRojo,
    'AMARILLO' => kSemaforoAmarillo,
    _          => kSemaforoVerde,
  };

  int _semaforoOrder(String s) => switch (s) {
    'ROJO'     => 0,
    'AMARILLO' => 1,
    _          => 2,
  };

  List<Insumo> _applySort(List<Insumo> list) {
    final sorted = [...list];
    sorted.sort((a, b) {
      final cmp = switch (_sortCol) {
        'tipo'      => a.tipo.compareTo(b.tipo),
        'ubicacion' => a.ubicacion.compareTo(b.ubicacion),
        'stock'     => a.stockActual.compareTo(b.stockActual),
        'stockMin'  => a.stockMinimo.compareTo(b.stockMinimo),
        'estado'    => _semaforoOrder(a.semaforo).compareTo(_semaforoOrder(b.semaforo)),
        _           => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
      };
      return _sortAsc ? cmp : -cmp;
    });
    return sorted;
  }

  Future<void> _abrirFormulario(BuildContext ctx, InventarioProvider prov, String? token) async {
    final ok = await Navigator.push<bool>(
      ctx, MaterialPageRoute(builder: (_) => const InsumoFormScreen()));
    if (ok == true) prov.fetchInsumos(token);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Consumer<InventarioProvider>(
      builder: (context, provider, _) {
        if (provider.cargando) {
          return const Center(child: CircularProgressIndicator(color: kPrimary));
        }

        final filtrados = _applySort(provider.insumos.where((i) {
          final matchTipo   = _filtroTipo == 'Todos' || i.tipo == _filtroTipo;
          final matchSearch = i.nombre.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                              i.tipo.toLowerCase().contains(_searchQuery.toLowerCase());
          return matchTipo && matchSearch;
        }).toList());

        final esQuimico = _filtroTipo == 'Químico';

        return Stack(children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Encabezado ───────────────────────────────────────────────
                Row(children: [
                  Text(
                    esQuimico ? 'Inventario de Químicos' : 'Inventario',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Buscar...',
                        prefixIcon: const Icon(Icons.search, color: kPrimary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                        focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: kPrimary)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => provider.fetchInsumos(auth.token),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Actualizar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                  ),
                ]),
                const SizedBox(height: 12),

                // ── Chips de filtro por tipo ──────────────────────────────────
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _tipos.map((tipo) {
                      final sel = _filtroTipo == tipo;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (tipo == 'Químico')
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(Icons.science_outlined, size: 14),
                              ),
                            Text(tipo),
                          ]),
                          selected: sel,
                          selectedColor: kPrimary,
                          labelStyle: TextStyle(
                              color: sel ? Colors.white : kTextMuted,
                              fontWeight: sel ? FontWeight.bold : FontWeight.normal),
                          onSelected: (_) => setState(() => _filtroTipo = tipo),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Tabla ─────────────────────────────────────────────────────
                Expanded(
                  child: filtrados.isEmpty
                      ? _buildEmpty()
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
                              child: esQuimico
                                  ? _buildTablaQuimicos(filtrados, context)
                                  : _buildTablaGeneral(filtrados, context),
                            ),
                          ),
                        ),
                ),

                // ── Leyenda ───────────────────────────────────────────────────
                if (filtrados.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    _leyenda(kSemaforoVerde,   'En stock'),
                    const SizedBox(width: 16),
                    _leyenda(kSemaforoAmarillo, 'Stock bajo'),
                    const SizedBox(width: 16),
                    _leyenda(kSemaforoRojo,    'Crítico'),
                    if (esQuimico) ...[
                      const SizedBox(width: 24),
                      const Icon(Icons.check_circle, size: 12, color: kSuccess),
                      const SizedBox(width: 4),
                      const Text('SGA cargado', style: TextStyle(fontSize: 12, color: kTextMuted)),
                      const SizedBox(width: 12),
                      const Icon(Icons.radio_button_unchecked, size: 12, color: kTextMuted),
                      const SizedBox(width: 4),
                      const Text('Sin datos SGA', style: TextStyle(fontSize: 12, color: kTextMuted)),
                    ],
                  ]),
                ],
              ],
            ),
          ),

          // ── FAB ───────────────────────────────────────────────────────────
          if (auth.can(Perm.inventarioGestionar))
            Positioned(
              bottom: 24, right: 24,
              child: FloatingActionButton.extended(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add),
                label: const Text('Nuevo insumo'),
                onPressed: () => _abrirFormulario(context, provider, auth.token),
              ),
            ),
        ]);
      },
    );
  }

  // ── Tabla general (Todos / Implemento / Vidriería / Equipo) ───────────────

  Widget _buildTablaGeneral(List<Insumo> items, BuildContext context) {
    // Solo mostrar columna SGA en vista "Todos" donde puede haber químicos
    final showSga = _filtroTipo == 'Todos';
    return Table(
      columnWidths: {
        0: const FlexColumnWidth(3),
        1: const FlexColumnWidth(1.4),
        2: const FlexColumnWidth(1.4),
        3: const FlexColumnWidth(0.9),
        4: const FlexColumnWidth(0.9),
        5: const FixedColumnWidth(58),
        if (showSga) 6: const FixedColumnWidth(48),
      },
      border: const TableBorder(
          horizontalInside: BorderSide(color: Color(0xFFDEE2E6))),
      children: [
        _headerRow(
          showSga
              ? ['Nombre', 'Tipo', 'Ubicación', 'Stock', 'Stock Mín.', 'Estado', 'SGA']
              : ['Nombre', 'Tipo', 'Ubicación', 'Stock', 'Stock Mín.', 'Estado'],
          showSga
              ? ['nombre', 'tipo', 'ubicacion', 'stock', 'stockMin', 'estado', '']
              : ['nombre', 'tipo', 'ubicacion', 'stock', 'stockMin', 'estado'],
        ),
        ...items.asMap().entries.map((e) {
          final idx    = e.key;
          final insumo = e.value;
          final rowBg  = idx.isOdd ? const Color(0xFFF8F9FA) : Colors.white;
          return TableRow(
            decoration: BoxDecoration(color: rowBg),
            children: [
              _cell(insumo.nombre, bold: true,
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => InsumoDetailScreen(
                        insumoId: insumo.id,
                        insumoNombre: insumo.nombre)))),
              _cell(insumo.tipo),
              _cell(insumo.ubicacion),
              _cell(insumo.stockActual.toStringAsFixed(0)),
              _cell(insumo.stockMinimo.toStringAsFixed(0)),
              _semaforo(insumo.semaforo),
              if (showSga)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: insumo.tipo == 'Químico'
                      ? _sgaBtn(context, insumo)
                      : const SizedBox.shrink(),
                ),
            ],
          );
        }),
      ],
    );
  }

  // ── Tabla especializada para Químicos ─────────────────────────────────────

  Widget _buildTablaQuimicos(List<Insumo> items, BuildContext context) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(1.4),
        2: FlexColumnWidth(0.9),
        3: FlexColumnWidth(0.9),
        4: FixedColumnWidth(58),
        5: FixedColumnWidth(48),
        6: FixedColumnWidth(48),
      },
      border: const TableBorder(
          horizontalInside: BorderSide(color: Color(0xFFDEE2E6))),
      children: [
        _headerRow(
          ['Nombre', 'Ubicación', 'Stock', 'Stock Mín.', 'Estado', 'SGA', 'Ficha'],
          ['nombre', 'ubicacion', 'stock', 'stockMin', 'estado', '', ''],
        ),
        ...items.asMap().entries.map((e) {
          final idx    = e.key;
          final insumo = e.value;
          final rowBg  = idx.isOdd ? const Color(0xFFF8F9FA) : Colors.white;
          return TableRow(
            decoration: BoxDecoration(color: rowBg),
            children: [
              _cell(insumo.nombre, bold: true,
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => InsumoDetailScreen(
                        insumoId: insumo.id,
                        insumoNombre: insumo.nombre)))),
              _cell(insumo.ubicacion),
              _cell(insumo.stockActual.toStringAsFixed(0)),
              _cell(insumo.stockMinimo.toStringAsFixed(0)),
              _semaforo(insumo.semaforo),
              // Indicador SGA
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Center(
                  child: insumo.tieneSga
                      ? const Tooltip(
                          message: 'Datos SGA cargados',
                          child: Icon(Icons.check_circle, size: 16, color: kSuccess))
                      : const Tooltip(
                          message: 'Sin datos SGA',
                          child: Icon(Icons.radio_button_unchecked, size: 16, color: kTextMuted)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: _sgaBtn(context, insumo),
              ),
            ],
          );
        }),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  TableRow _headerRow(List<String> cols, List<String> keys) {
    const padding = EdgeInsets.symmetric(horizontal: 8, vertical: 8);
    return TableRow(
      decoration: const BoxDecoration(color: kPrimary),
      children: List.generate(cols.length, (i) {
        final key      = keys[i];
        final isActive = key.isNotEmpty && _sortCol == key;
        final child    = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(cols[i],
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            if (isActive) ...[
              const SizedBox(width: 2),
              Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 10, color: Colors.white70),
            ],
          ],
        );
        if (key.isEmpty) return Padding(padding: padding, child: child);
        return InkWell(
          onTap: () => setState(() {
            if (_sortCol == key) {
              _sortAsc = !_sortAsc;
            } else {
              _sortCol = key;
              _sortAsc = true;
            }
          }),
          child: Padding(padding: padding, child: child),
        );
      }),
    );
  }

  Widget _cell(String text, {bool bold = false, VoidCallback? onTap}) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Text(text,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            color: onTap != null ? kPrimary : null,
            decoration: onTap != null ? TextDecoration.underline : null,
            decorationColor: kPrimary,
          )),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }

  Widget _semaforo(String s) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    child: Center(
      child: Container(
        width: 14, height: 14,
        decoration: BoxDecoration(
            color: _semaforoColor(s), shape: BoxShape.circle),
      ),
    ),
  );

  Widget _sgaBtn(BuildContext context, Insumo insumo) => Tooltip(
    message: 'Ver ficha SGA',
    child: IconButton(
      icon: Icon(
        Icons.science_outlined,
        size: 20,
        color: insumo.tieneSga ? kPrimary : kTextMuted,
      ),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SgaScreen(
            insumoId: insumo.id, insumoNombre: insumo.nombre)),
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(
        _filtroTipo == 'Químico'
            ? Icons.science_outlined
            : Icons.inventory_2_outlined,
        size: 64, color: kTextMuted,
      ),
      const SizedBox(height: 12),
      Text(
        _searchQuery.isEmpty
            ? (_filtroTipo == 'Todos'
                ? 'No hay insumos registrados'
                : 'No hay insumos de tipo "$_filtroTipo"')
            : 'Sin resultados para "$_searchQuery"',
        style: const TextStyle(color: kTextMuted),
      ),
    ]),
  );

  Widget _leyenda(Color color, String label) => Row(children: [
    Container(width: 12, height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 12, color: kTextMuted)),
  ]);
}
