import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api/api_client.dart';
import '../core/theme/colors.dart';
import '../core/permissions.dart';
import '../core/text_utils.dart';
import '../core/cache/cache_service.dart';
import '../core/sync/sync_service.dart';
import '../providers/auth_provider.dart';
import '../providers/inventario_provider.dart';
import '../models/insumo_model.dart';

class MovimientosContent extends StatefulWidget {
  const MovimientosContent({super.key});

  @override
  State<MovimientosContent> createState() => _MovimientosContentState();
}

class _MovimientosContentState extends State<MovimientosContent> {
  static const _cacheKey = 'prestamos';

  List<Map<String, dynamic>> _prestamos   = [];
  bool      _cargando    = true;
  bool      _mostrarForm = false;
  bool      _desdeCache  = false;
  DateTime? _cachedAt;
  String    _filtroEstado = 'Todos';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      Provider.of<InventarioProvider>(context, listen: false)
          .fetchInsumos(auth.token);
      _fetchPrestamos();
    });
  }

  Future<void> _fetchPrestamos() async {
    setState(() => _cargando = true);
    try {
      final auth = context.read<AuthProvider>();
      final dio  = ApiClient.instance.authenticatedDio(auth.token);
      final r    = await dio.get('operaciones/prestamos/');
      final data = r.data;
      final lista = List<Map<String, dynamic>>.from(
          data is List ? data : (data['results'] ?? []));
      await CacheService.instance.set(_cacheKey, lista);
      if (mounted) setState(() { _prestamos = lista; _desdeCache = false; _cachedAt = null; _cargando = false; });
    } catch (_) {
      final cached = await CacheService.instance.get(_cacheKey);
      if (mounted) setState(() {
        _prestamos  = cached != null
            ? List<Map<String, dynamic>>.from(cached.data as List)
            : [];
        _desdeCache = cached != null;
        _cachedAt   = cached?.cachedAt;
        _cargando   = false;
      });
    }
  }

  bool get _estaOnline => kIsWeb || SyncService.instance.online;

  Future<void> _aprobar(String id) async {
    if (!_estaOnline) {
      await SyncService.instance.encolar('APROBAR_PRESTAMO', {'prestamo_id': id});
      _showInfo('Sin conexión — la aprobación se enviará cuando vuelva la red.');
      return;
    }
    try {
      final auth = context.read<AuthProvider>();
      final dio  = ApiClient.instance.authenticatedDio(auth.token);
      await dio.post('operaciones/prestamos/$id/aprobar/');
      _fetchPrestamos();
    } catch (e) {
      _showError('Error al aprobar: $e');
    }
  }

  Future<void> _rechazar(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rechazar préstamo'),
        content: const Text('¿Confirmar el rechazo de esta solicitud?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Rechazar', style: TextStyle(color: kDanger))),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;

    if (!_estaOnline) {
      await SyncService.instance.encolar('RECHAZAR_PRESTAMO', {'prestamo_id': id});
      _showInfo('Sin conexión — el rechazo se enviará cuando vuelva la red.');
      return;
    }
    try {
      final auth = context.read<AuthProvider>();
      final dio  = ApiClient.instance.authenticatedDio(auth.token);
      await dio.post('operaciones/prestamos/$id/rechazar/');
      _fetchPrestamos();
    } catch (e) {
      _showError('Error al rechazar: $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: kDanger));
  }

  void _showInfo(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.sync, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor: const Color(0xFFE65100),
        duration: const Duration(seconds: 5),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return LayoutBuilder(builder: (context, constraints) {
    final pad = constraints.maxWidth < 650 ? 14.0 : 24.0;
    return Padding(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Banner caché ─────────────────────────────────────────────────
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
                const Icon(Icons.wifi_off, color: Color(0xFFE65100), size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Datos guardados (${_cachedAt != null ? CacheService.formatEdad(_cachedAt!) : "—"}) — aprobar/rechazar se encolará',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFE65100)),
                )),
              ]),
            ),
            const SizedBox(height: 10),
          ],
          // ── Encabezado ───────────────────────────────────────────────────
          Row(children: [
            Flexible(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Movimientos y Préstamos',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Text('Gestión de solicitudes de préstamo',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: kTextMuted)),
              ]),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh, color: kPrimary, size: 20),
              tooltip: 'Actualizar',
              onPressed: _fetchPrestamos,
            ),
            FilledButton.icon(
              onPressed: () => setState(() => _mostrarForm = !_mostrarForm),
              icon: Icon(_mostrarForm ? Icons.close : Icons.add, size: 16),
              label: Text(_mostrarForm ? 'Cancelar' : 'Nuevo Préstamo',
                  style: const TextStyle(fontSize: 13)),
              style: FilledButton.styleFrom(
                backgroundColor: _mostrarForm ? kTextMuted : kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // ── Chips de filtro por estado ────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              ..._buildFiltroChips(),
              const SizedBox(width: 16),
              Text(
                '${_prestamosFiltrados().length} préstamos',
                style: const TextStyle(fontSize: 12, color: kTextMuted),
              ),
            ]),
          ),
          const SizedBox(height: 12),

          // ── Formulario colapsable ────────────────────────────────────────
          if (_mostrarForm) ...[
            _PrestamoForm(
              onRegistrado: () {
                setState(() => _mostrarForm = false);
                _fetchPrestamos();
              },
            ),
            const SizedBox(height: 16),
          ],

          // ── Lista de préstamos ───────────────────────────────────────────
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator(color: kPrimary))
                : _prestamosFiltrados().isEmpty
                    ? _buildEmpty()
                    : ListView.separated(
                        itemCount: _prestamosFiltrados().length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) => _PrestamoCard(
                          prestamo: _prestamosFiltrados()[i],
                          puedeGestionar: auth.can(Perm.prestamosGestionar),
                          onAprobar: _aprobar,
                          onRechazar: _rechazar,
                          onDevuelto: _fetchPrestamos,
                        ),
                      ),
          ),
        ],
      ),
    );
    });
  }

  List<Map<String, dynamic>> _prestamosFiltrados() {
    if (_filtroEstado == 'Todos') return _prestamos;
    return _prestamos.where((p) => p['estado'] == _filtroEstado).toList();
  }

  static const _estadoFiltros = ['Todos', 'PENDIENTE', 'ACTIVO', 'DEVUELTO', 'RECHAZADO'];
  static const _estadoFiltroLabels = {
    'Todos':     'Todos',
    'PENDIENTE': 'PENDIENTE',
    'ACTIVO':    'ACTIVO',
    'DEVUELTO':  'DEVUELTO',
    'RECHAZADO': 'RECHAZADO',
  };
  static const _estadoFiltroColors = {
    'Todos':     kPrimary,
    'PENDIENTE': kWarning,
    'ACTIVO':    kPrimary,
    'DEVUELTO':  kSemaforoVerde,
    'RECHAZADO': kDanger,
  };

  List<Widget> _buildFiltroChips() {
    return _estadoFiltros.map((estado) {
      final sel   = _filtroEstado == estado;
      final color = _estadoFiltroColors[estado] ?? kPrimary;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => setState(() => _filtroEstado = estado),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: sel ? color : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: sel ? color : const Color(0xFFDEE2E6)),
            ),
            child: Text(
              _estadoFiltroLabels[estado] ?? estado,
              style: TextStyle(
                fontSize: 12,
                color: sel ? Colors.white : kTextMuted,
                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildEmpty() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.swap_horiz_outlined,
              size: 64, color: kTextMuted),
          const SizedBox(height: 12),
          const Text('Sin préstamos registrados',
              style: TextStyle(color: kTextMuted, fontSize: 16)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Registrar primer préstamo'),
            style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white),
            onPressed: () => setState(() => _mostrarForm = true),
          ),
        ]),
      );
}

// ── Formulario de nuevo préstamo ──────────────────────────────────────────────

class _PrestamoForm extends StatefulWidget {
  final VoidCallback onRegistrado;
  const _PrestamoForm({required this.onRegistrado});

  @override
  State<_PrestamoForm> createState() => _PrestamoFormState();
}

class _PrestamoFormState extends State<_PrestamoForm> {
  final _formKey = GlobalKey<FormState>();
  final _nitCtrl     = TextEditingController();
  final _nombreCtrl  = TextEditingController();
  final _correoCtrl  = TextEditingController();
  final _obsCtrl     = TextEditingController();

  // Cada ítem: {insumoId, cantCtrl}
  final List<_ItemPrestamo> _items = [_ItemPrestamo()];
  bool _guardando = false;

  @override
  void dispose() {
    _nitCtrl.dispose();
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _obsCtrl.dispose();
    for (final it in _items) it.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.any((i) => i.insumoId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Selecciona un insumo en cada ítem.'),
          backgroundColor: kDanger));
      return;
    }

    setState(() => _guardando = true);
    try {
      final auth = context.read<AuthProvider>();
      final dio = ApiClient.instance.authenticatedDio(auth.token);
      await dio.post('operaciones/prestamos/', data: {
        'nit_estudiante':    _nitCtrl.text.trim(),
        'nombre_estudiante': _nombreCtrl.text.trim(),
        'correo_estudiante': _correoCtrl.text.trim(),
        'observaciones':     _obsCtrl.text.trim(),
        'detalles': _items
            .where((i) => i.insumoId != null)
            .map((i) => {
                  'insumo': i.insumoId,
                  'cantidad_prestada':
                      double.tryParse(i.cantCtrl.text) ?? 1,
                })
            .toList(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Préstamo registrado correctamente.'),
            backgroundColor: kSuccess));
        widget.onRegistrado();
      }
    } catch (e) {
      String msg = 'Error al registrar el préstamo.';
      try {
        final data = (e as dynamic).response?.data;
        if (data is Map) msg = data.values.first.toString();
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: kDanger));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final insumos = context.read<InventarioProvider>().insumos;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              const Text('Nuevo Préstamo',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // Fila 1: NIT + Nombre
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _nitCtrl,
                    decoration: _deco('NIT / Identificación *',
                        Icons.badge_outlined),
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Requerido' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _nombreCtrl,
                    decoration: _deco(
                        'Nombre del solicitante *', Icons.person_outline),
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Requerido' : null,
                  ),
                ),
              ]),
              const SizedBox(height: 12),

              // Fila 2: Correo
              TextFormField(
                controller: _correoCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration:
                    _deco('Correo electrónico *', Icons.email_outlined),
                validator: (v) {
                  if (v!.trim().isEmpty) return 'Requerido';
                  if (!v.contains('@')) return 'Correo inválido';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Items
              const Text('Ítems a prestar',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: kPrimary,
                      fontSize: 13)),
              const SizedBox(height: 8),
              ...List.generate(_items.length, (i) => _buildItemRow(i, insumos)),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Agregar ítem'),
                onPressed: () => setState(() => _items.add(_ItemPrestamo())),
              ),
              const SizedBox(height: 12),

              // Observaciones
              TextFormField(
                controller: _obsCtrl,
                maxLines: 2,
                decoration:
                    _deco('Observaciones (opcional)', Icons.notes_outlined),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _guardando ? null : _registrar,
                  icon: _guardando
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_outlined),
                  label: const Text('Registrar préstamo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildItemRow(int i, List<Insumo> insumos) {
    final item = _items[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: _InsumoSelectorButton(
            insumos: insumos,
            selectedId: item.insumoId,
            onSelected: (id) => setState(() => item.insumoId = id),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: item.cantCtrl,
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true),
            decoration: _deco('Cantidad', Icons.numbers),
            validator: (v) =>
                (double.tryParse(v ?? '') ?? 0) <= 0
                    ? '>0'
                    : null,
          ),
        ),
        if (_items.length > 1)
          IconButton(
            icon: const Icon(Icons.remove_circle_outline,
                color: kDanger, size: 20),
            onPressed: () => setState(() {
              _items[i].dispose();
              _items.removeAt(i);
            }),
          ),
      ]),
    );
  }

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: kPrimary, size: 18),
        border: const OutlineInputBorder(),
        focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: kPrimary)),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 10),
        isDense: true,
      );
}

class _ItemPrestamo {
  String? insumoId;
  final cantCtrl = TextEditingController(text: '1');
  void dispose() => cantCtrl.dispose();
}

// ── Botón de selección de insumo con búsqueda ─────────────────────────────────

class _InsumoSelectorButton extends StatelessWidget {
  final List<Insumo> insumos;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  const _InsumoSelectorButton({
    required this.insumos,
    required this.selectedId,
    required this.onSelected,
  });

  String? get _nombre {
    if (selectedId == null) return null;
    for (final i in insumos) {
      if (i.id == selectedId) return i.nombre;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final nombre = _nombre;
    return InkWell(
      onTap: () async {
        final sel = await showDialog<Insumo>(
          context: context,
          builder: (_) => _SelectorInsumoDialog(insumos: insumos),
        );
        if (sel != null) onSelected(sel.id);
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFAAAAAA)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(children: [
          const Icon(Icons.inventory_2_outlined, color: kPrimary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              nombre ?? 'Seleccionar insumo...',
              style: TextStyle(
                color: nombre != null ? Colors.black87 : kTextMuted,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.search, color: kTextMuted, size: 16),
        ]),
      ),
    );
  }
}

// ── Diálogo de búsqueda de insumos ────────────────────────────────────────────

class _SelectorInsumoDialog extends StatefulWidget {
  final List<Insumo> insumos;
  const _SelectorInsumoDialog({required this.insumos});
  @override
  State<_SelectorInsumoDialog> createState() => _SelectorInsumoDialogState();
}

class _SelectorInsumoDialogState extends State<_SelectorInsumoDialog> {
  String _query = '';

  Color _semaforoColor(String s) => switch (s) {
    'ROJO'     => kSemaforoRojo,
    'AMARILLO' => kSemaforoAmarillo,
    _          => kSemaforoVerde,
  };

  @override
  Widget build(BuildContext context) {
    final query = normalizarBusqueda(_query);
    final filtrados = widget.insumos
        .where((i) =>
            normalizarBusqueda(i.nombre).contains(query) ||
            normalizarBusqueda(i.tipo).contains(query))
        .toList();

    return AlertDialog(
      title: const Text('Seleccionar insumo',
          style: TextStyle(color: kPrimary, fontSize: 16)),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      content: SizedBox(
        width: 420,
        height: 400,
        child: Column(children: [
          TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: 'Buscar por nombre o tipo...',
              prefixIcon: Icon(Icons.search, color: kPrimary, size: 18),
              border: OutlineInputBorder(),
              focusedBorder:
                  OutlineInputBorder(borderSide: BorderSide(color: kPrimary)),
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtrados.isEmpty
                ? const Center(
                    child: Text('Sin resultados',
                        style: TextStyle(color: kTextMuted)))
                : ListView.builder(
                    itemCount: filtrados.length,
                    itemBuilder: (_, i) {
                      final ins = filtrados[i];
                      return ListTile(
                        dense: true,
                        leading: Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: _semaforoColor(ins.semaforo),
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(ins.nombre,
                            style: const TextStyle(fontSize: 13)),
                        subtitle: Text(
                            '${ins.tipo} · Stock: ${ins.stockActual.toStringAsFixed(0)} ${ins.unidad}',
                            style: const TextStyle(fontSize: 11)),
                        onTap: () => Navigator.pop(context, ins),
                      );
                    },
                  ),
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
      ],
    );
  }
}

// ── Tarjeta de préstamo ───────────────────────────────────────────────────────

class _PrestamoCard extends StatelessWidget {
  final Map<String, dynamic> prestamo;
  final bool puedeGestionar;
  final void Function(String) onAprobar;
  final void Function(String) onRechazar;
  final VoidCallback onDevuelto;

  const _PrestamoCard({
    required this.prestamo,
    required this.puedeGestionar,
    required this.onAprobar,
    required this.onRechazar,
    required this.onDevuelto,
  });

  static const _estadoColors = {
    'PENDIENTE': kWarning,
    'ACTIVO':    kPrimary,
    'DEVUELTO':  kSemaforoVerde,
    'RECHAZADO': kDanger,
  };

  static const _estadoBorderColors = {
    'PENDIENTE': kWarning,
    'ACTIVO':    kPrimary,
    'DEVUELTO':  kSemaforoVerde,
    'RECHAZADO': kDanger,
  };

  static const _estadoBg = {
    'PENDIENTE': Color(0xFFFFF8E1),
    'ACTIVO':    Color(0xFFE3F2FD),
    'DEVUELTO':  Color(0xFFE8F5E9),
    'RECHAZADO': Color(0xFFFFEBEE),
  };

  static const _estadoLabels = {
    'PENDIENTE': 'PENDIENTE',
    'ACTIVO':    'ACTIVO',
    'DEVUELTO':  'DEVUELTO',
    'RECHAZADO': 'RECHAZADO',
  };

  @override
  Widget build(BuildContext context) {
    final id       = prestamo['id']?.toString() ?? '';
    final estado   = prestamo['estado']?.toString() ?? '';
    final color    = _estadoColors[estado] ?? kTextMuted;
    final bgColor  = _estadoBg[estado] ?? const Color(0xFFF5F5F5);
    final label    = _estadoLabels[estado] ?? estado;
    final detalles = (prestamo['detalles'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final fecha    = (prestamo['fecha_solicitud']?.toString() ?? '')
        .replaceFirst('T', ' ')
        .substring(0, 16);

    final borderColor = _estadoBorderColors[estado] ?? kTextMuted;
    final isInactive  = estado == 'DEVUELTO' || estado == 'RECHAZADO';

    return Material(
      color: isInactive ? Colors.white.withValues(alpha: 0.85) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      elevation: 1,
      shadowColor: Colors.black12,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: borderColor, width: 4)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Encabezado: ID + chip estado ──
            Row(children: [
              Flexible(
                child: Text(
                  'Préstamo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(label,
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 4),
            // ── Info del solicitante ──
            Text(prestamo['nombre_estudiante']?.toString() ?? '—',
                style: const TextStyle(color: kTextMuted, fontSize: 13)),
            Text(fecha,
                style: const TextStyle(color: kTextMuted, fontSize: 11)),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // ── Ítems ──
            ...detalles.map((d) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    const Icon(Icons.circle, size: 5, color: kTextMuted),
                    const SizedBox(width: 8),
                    Expanded(child: Text(d['nombre_insumo']?.toString() ?? '?',
                        style: const TextStyle(fontSize: 13))),
                    Text('×${d['cantidad_prestada']}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    if ((d['pendiente_devolucion'] != null &&
                        double.tryParse(d['pendiente_devolucion'].toString()) !=
                            d['cantidad_prestada']))
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text('(pend. ${d['pendiente_devolucion']})',
                            style: const TextStyle(color: kWarning, fontSize: 11)),
                      ),
                  ]),
                )),

            if (prestamo['observaciones']?.toString().isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(prestamo['observaciones'].toString(),
                    style: const TextStyle(
                        color: kTextMuted, fontSize: 12, fontStyle: FontStyle.italic)),
              ),

            // ── Acciones ──
            if (puedeGestionar && (estado == 'PENDIENTE' || estado == 'ACTIVO')) ...[
              const SizedBox(height: 10),
              Row(children: [
                if (estado == 'PENDIENTE') ...[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: kDanger,
                          side: const BorderSide(color: kDanger),
                          padding: const EdgeInsets.symmetric(vertical: 8)),
                      onPressed: () => onRechazar(id),
                      child: const Text('Rechazar', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary, foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 8)),
                      onPressed: () => onAprobar(id),
                      child: const Text('Aprobar', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
                if (estado == 'ACTIVO')
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.assignment_return_outlined, size: 16),
                      label: const Text('Registrar devolución', style: TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: kSemaforoVerde, foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 8)),
                      onPressed: () => _abrirDevolucion(context, detalles),
                    ),
                  ),
              ]),
            ],
          ],
        ),
      ),
      ),
    );
  }

  Future<void> _abrirDevolucion(
      BuildContext context, List<Map<String, dynamic>> detalles) async {
    final pendientes = detalles
        .where((d) =>
            (double.tryParse(d['pendiente_devolucion']?.toString() ?? '0') ?? 0) > 0)
        .toList();

    if (pendientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Todos los ítems ya fueron devueltos.')));
      return;
    }

    final ctrls = {
      for (final d in pendientes)
        d['id'].toString(): TextEditingController(
            text: d['pendiente_devolucion'].toString())
    };

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Registrar devolución'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: pendientes
                .map((d) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        Expanded(
                            child: Text(d['nombre_insumo']?.toString() ?? '?',
                                style: const TextStyle(fontSize: 13))),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: ctrls[d['id'].toString()],
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Cant.',
                              isDense: true,
                              border: const OutlineInputBorder(),
                              helperText:
                                  'máx: ${d['pendiente_devolucion']}',
                            ),
                          ),
                        ),
                      ]),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    for (final c in ctrls.values) c.dispose();
    if (ok != true || !context.mounted) return;

    try {
      final auth = context.read<AuthProvider>();
      final dio = ApiClient.instance.authenticatedDio(auth.token);
      for (final d in pendientes) {
        final ctrl = ctrls[d['id'].toString()];
        final cantidad = double.tryParse(ctrl?.text ?? '0') ?? 0;
        if (cantidad <= 0) continue;
        await dio.post('operaciones/devoluciones/', data: {
          'detalle_prestamo': d['id'],
          'cantidad_devuelta': cantidad,
        });
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Devolución registrada.'),
            backgroundColor: kSuccess));
        onDevuelto();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: kDanger));
      }
    }
  }
}
