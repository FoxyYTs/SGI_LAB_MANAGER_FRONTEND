import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api/api_client.dart';
import '../core/theme/colors.dart';
import '../core/permissions.dart';
import '../providers/auth_provider.dart';
import '../providers/inventario_provider.dart';
import '../models/insumo_model.dart';

class MovimientosContent extends StatefulWidget {
  const MovimientosContent({super.key});

  @override
  State<MovimientosContent> createState() => _MovimientosContentState();
}

class _MovimientosContentState extends State<MovimientosContent> {
  List<Map<String, dynamic>> _prestamos = [];
  bool _cargando = true;
  bool _mostrarForm = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
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
      final dio = ApiClient.instance.authenticatedDio(auth.token);
      final r = await dio.get('operaciones/prestamos/');
      final data = r.data;
      setState(() {
        _prestamos = List<Map<String, dynamic>>.from(
          data is List ? data : (data['results'] ?? []));
        _cargando = false;
      });
    } catch (_) {
      setState(() => _cargando = false);
    }
  }

  Future<void> _aprobar(String id) async {
    try {
      final auth = context.read<AuthProvider>();
      final dio = ApiClient.instance.authenticatedDio(auth.token);
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
              child: const Text('Rechazar',
                  style: TextStyle(color: kDanger))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final auth = context.read<AuthProvider>();
      final dio = ApiClient.instance.authenticatedDio(auth.token);
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Encabezado ───────────────────────────────────────────────────
          Row(children: [
            const Text('Movimientos y Préstamos',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh, color: kPrimary),
              tooltip: 'Actualizar',
              onPressed: _fetchPrestamos,
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => setState(() => _mostrarForm = !_mostrarForm),
              icon: Icon(_mostrarForm ? Icons.close : Icons.add, size: 18),
              label: Text(_mostrarForm
                  ? 'Cancelar'
                  : 'Registrar Préstamo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _mostrarForm ? kTextMuted : kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ]),
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
                ? const Center(
                    child: CircularProgressIndicator(color: kPrimary))
                : _prestamos.isEmpty
                    ? _buildEmpty()
                    : ListView.separated(
                        itemCount: _prestamos.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (ctx, i) => _PrestamoCard(
                          prestamo: _prestamos[i],
                          puedeGestionar:
                              auth.can(Perm.prestamosGestionar),
                          onAprobar: _aprobar,
                          onRechazar: _rechazar,
                          onDevuelto: _fetchPrestamos,
                        ),
                      ),
          ),
        ],
      ),
    );
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
          child: DropdownButtonFormField<String>(
            value: item.insumoId,
            decoration: _deco('Insumo', Icons.inventory_2_outlined),
            items: insumos
                .map<DropdownMenuItem<String>>((ins) =>
                    DropdownMenuItem(
                      value: ins.id,
                      child: Text(ins.nombre,
                          overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (v) => setState(() => item.insumoId = v),
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
    'ACTIVO':    kSuccess,
    'DEVUELTO':  kTextMuted,
    'RECHAZADO': kDanger,
  };

  static const _estadoLabels = {
    'PENDIENTE': 'Pendiente aprobación',
    'ACTIVO':    'Activo',
    'DEVUELTO':  'Devuelto',
    'RECHAZADO': 'Rechazado',
  };

  @override
  Widget build(BuildContext context) {
    final id     = prestamo['id']?.toString() ?? '';
    final estado = prestamo['estado']?.toString() ?? '';
    final color  = _estadoColors[estado] ?? kTextMuted;
    final label  = _estadoLabels[estado] ?? estado;
    final detalles = (prestamo['detalles'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final fecha = (prestamo['fecha_solicitud']?.toString() ?? '')
        .replaceFirst('T', ' ')
        .substring(0, 16);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado
            Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                    prestamo['nombre_estudiante']?.toString() ?? '—',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Text(
                    'NIT: ${prestamo['nit_estudiante'] ?? '—'}  ·  $fecha',
                    style: const TextStyle(
                        color: kTextMuted, fontSize: 12),
                  ),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color),
                ),
                child: Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 10),

            // Ítems
            ...detalles.map((d) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    const Icon(Icons.circle, size: 6, color: kTextMuted),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                      d['nombre_insumo']?.toString() ?? '?',
                      style: const TextStyle(fontSize: 13),
                    )),
                    Text(
                      'x${d['cantidad_prestada']}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    if ((d['pendiente_devolucion'] != null &&
                        double.tryParse(
                                d['pendiente_devolucion'].toString()) !=
                            d['cantidad_prestada']))
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          '(pend. ${d['pendiente_devolucion']})',
                          style: const TextStyle(
                              color: kWarning, fontSize: 11),
                        ),
                      ),
                  ]),
                )),

            if (prestamo['observaciones']?.toString().isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  prestamo['observaciones'].toString(),
                  style: const TextStyle(
                      color: kTextMuted, fontSize: 12,
                      fontStyle: FontStyle.italic),
                ),
              ),

            // Acciones
            if (puedeGestionar && (estado == 'PENDIENTE' || estado == 'ACTIVO')) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(children: [
                if (estado == 'PENDIENTE') ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.check, size: 16,
                        color: kSuccess),
                    label: const Text('Aprobar',
                        style: TextStyle(color: kSuccess)),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kSuccess),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6)),
                    onPressed: () => onAprobar(id),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.close, size: 16,
                        color: kDanger),
                    label: const Text('Rechazar',
                        style: TextStyle(color: kDanger)),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kDanger),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6)),
                    onPressed: () => onRechazar(id),
                  ),
                ],
                if (estado == 'ACTIVO')
                  OutlinedButton.icon(
                    icon: const Icon(Icons.assignment_return_outlined,
                        size: 16, color: kPrimary),
                    label: const Text('Registrar devolución',
                        style: TextStyle(color: kPrimary)),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kPrimary),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6)),
                    onPressed: () => _abrirDevolucion(context, detalles),
                  ),
              ]),
            ],
          ],
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
