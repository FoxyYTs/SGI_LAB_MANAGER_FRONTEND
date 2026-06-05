import 'dart:async';
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
import '../core/sync/sync_service.dart';

class InventarioContent extends StatefulWidget {
  const InventarioContent({super.key});

  @override
  State<InventarioContent> createState() => _InventarioContentState();
}

class _InventarioContentState extends State<InventarioContent> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;
  String _filtroTipo  = 'Todos';
  String _sortCol     = 'nombre';
  bool   _sortAsc     = true;
  bool   _eraOnline   = true;

  static const _tipos = ['Todos', 'Implemento', 'Vidriería', 'Equipo', 'Químico'];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      Provider.of<InventarioProvider>(context, listen: false).fetchInsumos(auth.token);
    });
    _eraOnline = SyncService.instance.online;
    SyncService.instance.addListener(_onSync);
  }

  void _onSync() {
    final ahoraOnline = SyncService.instance.online;
    if (!_eraOnline && ahoraOnline && mounted) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      Provider.of<InventarioProvider>(context, listen: false).fetchInsumos(auth.token);
    }
    _eraOnline = ahoraOnline;
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _searchQuery = value);
    });
  }

  @override
  void dispose() {
    SyncService.instance.removeListener(_onSync);
    _debounce?.cancel();
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

        return LayoutBuilder(builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;
        final pad = isMobile ? 14.0 : 24.0;
        return Stack(children: [
          Padding(
            padding: EdgeInsets.all(pad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner datos desde caché
                if (provider.desdeCache)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
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
                        provider.lastSync != null
                            ? 'Mostrando datos guardados (última sync: ${_formatFecha(provider.lastSync!)})'
                            : 'Mostrando datos guardados — sin conexión al servidor',
                        style: const TextStyle(fontSize: 12, color: Color(0xFFE65100)),
                      )),
                    ]),
                  ),
                // ── Encabezado ───────────────────────────────────────────────
                if (isMobile) ...[
                  Row(children: [
                    Expanded(child: Text(
                      esQuimico ? 'Inventario de Químicos' : 'Inventario',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    )),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: kPrimary),
                      tooltip: 'Actualizar',
                      onPressed: () => provider.fetchInsumos(auth.token),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar...',
                      prefixIcon: const Icon(Icons.search, color: kPrimary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: kPrimary)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ] else
                  Row(children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          esQuimico ? 'Inventario de Químicos' : 'Inventario',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const Text('Gestión de insumos del laboratorio',
                            style: TextStyle(fontSize: 12, color: kTextMuted)),
                      ],
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 240,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar insumo...',
                          prefixIcon: const Icon(Icons.search, color: kPrimary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: kPrimary)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          filled: true, fillColor: Colors.white,
                        ),
                        onChanged: _onSearchChanged,
                      ),
                    ),
                    if (auth.can(Perm.inventarioGestionar)) ...[
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () => _abrirFormulario(context, provider, auth.token),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Nuevo Insumo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary, foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      ),
                    ],
                  ]),
                const SizedBox(height: 12),

                // ── Fila: chips resumen + chips filtro ────────────────────────
                if (!isMobile)
                  Row(children: [
                    // Chips informativos
                    _resumenChip(Icons.inventory_2_outlined,
                        'Total: ${provider.insumos.length}',
                        const Color(0xFF6C757D), const Color(0xFFF0F0F0)),
                    const SizedBox(width: 8),
                    _resumenChip(Icons.circle, 'Críticos: ${provider.insumos.where((i) => i.semaforo == "ROJO").length}',
                        kSemaforoRojo, const Color(0xFFFFEBEE)),
                    const SizedBox(width: 8),
                    _resumenChip(Icons.circle, 'Bajos: ${provider.insumos.where((i) => i.semaforo == "AMARILLO").length}',
                        const Color(0xFFE65100), const Color(0xFFFFF8E1)),
                    const Spacer(),
                  ]),
                if (!isMobile) const SizedBox(height: 10),

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

                // ── Lista (móvil) / Tabla (desktop) ──────────────────────────
                Expanded(
                  child: filtrados.isEmpty
                      ? _buildEmpty()
                      : isMobile
                          ? _buildCardList(filtrados, context)
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
                                  scrollDirection: Axis.vertical,
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

        ]);
        }); // LayoutBuilder
      },
    );
  }

  // ── Vista de cards para móvil ─────────────────────────────────────────────

  Widget _buildCardList(List<Insumo> items, BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final insumo = items[i];
        final color  = _semaforoColor(insumo.semaforo);
        final (chipLabel, chipColor, chipBg) = switch (insumo.semaforo) {
          'ROJO'     => ('CRÍTICO', kSemaforoRojo,    const Color(0xFFFFEBEE)),
          'AMARILLO' => ('BAJO',    kSemaforoAmarillo, const Color(0xFFFFF8E1)),
          _          => ('OK',      kSemaforoVerde,    const Color(0xFFE8F5E9)),
        };
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          elevation: 1,
          shadowColor: Colors.black12,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => Navigator.push(ctx,
                MaterialPageRoute(builder: (_) => InsumoDetailScreen(
                    insumoId: insumo.id, insumoNombre: insumo.nombre))),
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: color, width: 4)),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(insumo.nombre,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('${insumo.tipo} · ${insumo.ubicacion}',
                          style: const TextStyle(color: kTextMuted, fontSize: 12),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${insumo.stockActual.toStringAsFixed(0)} ${insumo.unidad}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: chipBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(chipLabel,
                          style: TextStyle(color: chipColor, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                if (insumo.tipo == 'Químico') ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(Icons.science_outlined, size: 20,
                        color: insumo.tieneSga ? kPrimary : kTextMuted),
                    onPressed: () => Navigator.push(ctx,
                        MaterialPageRoute(builder: (_) => SgaScreen(
                            insumoId: insumo.id, insumoNombre: insumo.nombre))),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ]),
            ),
          ),
        );
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
              _cell('${insumo.stockActual.toStringAsFixed(0)} ${insumo.unidad}'),
              _cell('${insumo.stockMinimo.toStringAsFixed(0)} ${insumo.unidad}'),
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
              _cell('${insumo.stockActual.toStringAsFixed(0)} ${insumo.unidad}'),
              _cell('${insumo.stockMinimo.toStringAsFixed(0)} ${insumo.unidad}'),
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

  Widget _semaforo(String s) {
    final (label, color, bg) = switch (s) {
      'ROJO'     => ('CRÍTICO', kSemaforoRojo,    const Color(0xFFFFEBEE)),
      'AMARILLO' => ('BAJO',    const Color(0xFFE65100), const Color(0xFFFFF8E1)),
      _          => ('OK',      kSemaforoVerde,   const Color(0xFFE8F5E9)),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
          child: Text(label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

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

  String _formatFecha(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'justo ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24)   return 'hace ${diff.inHours} h';
    return 'hace ${diff.inDays} día(s)';
  }

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

  Widget _resumenChip(IconData icon, String label, Color color, Color bg) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ]),
      );
}
