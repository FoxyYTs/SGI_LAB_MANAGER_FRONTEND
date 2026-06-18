import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api/api_client.dart';
import '../core/theme/colors.dart';
import '../providers/auth_provider.dart';

// ── Modelo local para una presentación en el formulario ──────────────────────

class _PresentacionRow {
  String? id; // null = nueva, String = existente
  final TextEditingController stockCtrl;
  final TextEditingController fotoCtrl;
  String? unidadId;

  _PresentacionRow({this.id, String stock = '0', String foto = '', this.unidadId})
      : stockCtrl = TextEditingController(text: stock),
        fotoCtrl  = TextEditingController(text: foto);

  void dispose() {
    stockCtrl.dispose();
    fotoCtrl.dispose();
  }
}

// ── Pantalla ─────────────────────────────────────────────────────────────────

class InsumoFormScreen extends StatefulWidget {
  final Map<String, dynamic>? insumo;
  const InsumoFormScreen({super.key, this.insumo});

  @override
  State<InsumoFormScreen> createState() => _InsumoFormScreenState();
}

class _InsumoFormScreenState extends State<InsumoFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Campos del insumo
  final _nombreCtrl      = TextEditingController();
  final _stockMinimoCtrl = TextEditingController(text: '0');
  final _observCtrl      = TextEditingController();

  // Detalle químico
  final _formulaCtrl     = TextEditingController();
  final _casCtrl         = TextEditingController();
  final _concCtrl        = TextEditingController();

  // Detalle material
  final _marcaCtrl     = TextEditingController();
  final _capacidadCtrl = TextEditingController();
  final _materialCtrl  = TextEditingController();
  bool  _esGraduado    = false;

  // Catálogos
  List<Map<String, dynamic>> _tipos       = [];
  List<Map<String, dynamic>> _ubicaciones = [];
  List<Map<String, dynamic>> _unidades    = [];

  String? _tipoId;
  String? _ubicacionId;
  String  _tipoNombre = '';

  // Presentaciones dinámicas
  final List<_PresentacionRow> _presentaciones = [];
  final List<String> _presentacionesEliminar   = []; // ids a borrar en edición

  bool _loading   = true;
  bool _guardando = false;

  bool get _esQuimico  => _tipoNombre == 'Químico';
  bool get _esMaterial => _tipoNombre == 'Implemento' || _tipoNombre == 'Vidriería';

  @override
  void initState() {
    super.initState();
    _cargarOpciones();
  }

  @override
  void dispose() {
    for (final c in [_nombreCtrl, _stockMinimoCtrl, _observCtrl,
        _formulaCtrl, _casCtrl, _concCtrl,
        _marcaCtrl, _capacidadCtrl, _materialCtrl]) {
      c.dispose();
    }
    for (final p in _presentaciones) { p.dispose(); }
    super.dispose();
  }

  Future<void> _cargarOpciones() async {
    final auth = context.read<AuthProvider>();
    final dio  = ApiClient.instance.authenticatedDio(auth.token);
    try {
      final results = await Future.wait([
        dio.get('inventario/tipos/'),
        dio.get('inventario/ubicaciones/'),
        dio.get('inventario/unidades/'),
      ]);
      List<Map<String, dynamic>> parse(dynamic d) =>
          List<Map<String, dynamic>>.from(d is List ? d : (d['results'] ?? []));
      if (!mounted) return;
      setState(() {
        _tipos       = parse(results[0].data);
        _ubicaciones = parse(results[1].data);
        _unidades    = parse(results[2].data);
        _loading     = false;
      });
      _precargarEdicion();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _precargarEdicion() {
    final ins = widget.insumo;
    if (ins == null) {
      // En creación agregamos una presentación vacía por defecto
      _presentaciones.add(_PresentacionRow());
      return;
    }
    _nombreCtrl.text      = ins['nombre_insumo'] ?? '';
    _stockMinimoCtrl.text = ins['stock_minimo']?.toString() ?? '0';
    _observCtrl.text      = ins['observaciones'] ?? '';
    _tipoId      = ins['tipo_insumo']?.toString();
    _ubicacionId = ins['ubicacion']?.toString();
    _tipoNombre  = ins['tipo_nombre'] ?? '';

    // Cargar presentaciones existentes
    final pres = ins['presentaciones'] as List? ?? [];
    for (final p in pres) {
      _presentaciones.add(_PresentacionRow(
        id:       p['id']?.toString(),
        stock:    p['stock_actual']?.toString() ?? '0',
        foto:     p['foto'] as String? ?? '',
        unidadId: p['unidad_medida']?.toString(),
      ));
    }
    if (_presentaciones.isEmpty) {
      _presentaciones.add(_PresentacionRow());
    }
    setState(() {});
  }

  void _agregarPresentacion() {
    setState(() => _presentaciones.add(_PresentacionRow()));
  }

  void _eliminarPresentacion(int index) {
    final row = _presentaciones[index];
    if (row.id != null) _presentacionesEliminar.add(row.id!);
    row.dispose();
    setState(() => _presentaciones.removeAt(index));
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_presentaciones.isEmpty) {
      _snack('Agrega al menos una presentación.', kDanger);
      return;
    }
    setState(() => _guardando = true);

    final auth = context.read<AuthProvider>();
    final dio  = ApiClient.instance.authenticatedDio(auth.token);

    final body = {
      'nombre_insumo': _nombreCtrl.text.trim(),
      'tipo_insumo':   _tipoId,
      'ubicacion':     _ubicacionId,
      'stock_minimo':  double.tryParse(_stockMinimoCtrl.text) ?? 0,
      'observaciones': _observCtrl.text.trim(),
    };

    try {
      Map<String, dynamic> insumo;
      if (widget.insumo != null) {
        final id = widget.insumo!['id'];
        final r  = await dio.patch('inventario/lista/$id/', data: body);
        insumo   = Map<String, dynamic>.from(r.data);
      } else {
        final r = await dio.post('inventario/lista/', data: body);
        insumo  = Map<String, dynamic>.from(r.data);
      }

      final id = insumo['id'];

      // Eliminar presentaciones borradas
      for (final presId in _presentacionesEliminar) {
        await dio.delete('inventario/lista/$id/presentaciones/$presId/');
      }

      // Guardar presentaciones
      for (final p in _presentaciones) {
        final presBody = {
          'stock_actual':  double.tryParse(p.stockCtrl.text) ?? 0,
          'unidad_medida': p.unidadId,
          'foto':          p.fotoCtrl.text.trim().isEmpty ? null : p.fotoCtrl.text.trim(),
        };
        if (p.id != null) {
          await dio.patch('inventario/lista/$id/presentaciones/${p.id}/', data: presBody);
        } else {
          await dio.post('inventario/lista/$id/presentaciones/', data: presBody);
        }
      }

      // Guardar detalle según tipo
      if (_esQuimico) {
        await dio.post('inventario/lista/$id/quimico/', data: {
          'formula_quimica': _formulaCtrl.text.trim(),
          'numero_cas':      _casCtrl.text.trim(),
          'concentracion':   _concCtrl.text.trim(),
        });
      } else if (_esMaterial) {
        await dio.post('inventario/lista/$id/material/', data: {
          'marca':                _marcaCtrl.text.trim(),
          'capacidad_volumetrica': _capacidadCtrl.text.trim(),
          'material':             _materialCtrl.text.trim(),
          'es_graduado':          _esGraduado,
        });
      }

      if (mounted) {
        _snack('Insumo guardado correctamente.', kSuccess);
        Navigator.pop(context, true);
      }
    } catch (e) {
      String msg = 'Error al guardar el insumo.';
      try {
        final data = (e as dynamic).response?.data;
        if (data is Map) msg = data.values.first.toString();
      } catch (_) {}
      if (mounted) _snack(msg, kDanger);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.insumo != null;

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(esEdicion ? 'Editar insumo' : 'Nuevo insumo',
            style: const TextStyle(color: kPrimary, fontWeight: FontWeight.bold)),
        elevation: 1,
        actions: [
          if (_guardando)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2)),
            )
          else
            TextButton.icon(
              onPressed: _guardar,
              icon: const Icon(Icons.save_outlined, color: kPrimary),
              label: const Text('Guardar', style: TextStyle(color: kPrimary)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [

                  // ── Información general ──────────────────────────────────
                  _seccion('Información general'),
                  TextFormField(
                    controller: _nombreCtrl,
                    decoration: _deco('Nombre del insumo *', Icons.inventory_2_outlined),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                  ),
                  const SizedBox(height: 14),
                  _dropdown<String>(
                    label: 'Tipo de insumo *',
                    icon: Icons.category_outlined,
                    value: _tipoId,
                    items: _tipos.map((t) => DropdownMenuItem(
                      value: t['id'].toString(),
                      child: Text(t['nombre_tipo']),
                    )).toList(),
                    onChanged: (v) {
                      final tipo = _tipos.firstWhere(
                          (t) => t['id'].toString() == v, orElse: () => {});
                      setState(() {
                        _tipoId     = v;
                        _tipoNombre = tipo['nombre_tipo'] ?? '';
                      });
                    },
                    validator: (v) => v == null ? 'Selecciona un tipo' : null,
                  ),
                  const SizedBox(height: 14),
                  _dropdown<String>(
                    label: 'Ubicación',
                    icon: Icons.place_outlined,
                    value: _ubicacionId,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Sin ubicación')),
                      ..._ubicaciones.map((u) => DropdownMenuItem(
                        value: u['id'].toString(),
                        child: Text(u['codigo_ubicacion']),
                      )),
                    ],
                    onChanged: (v) => setState(() => _ubicacionId = v),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _stockMinimoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _deco('Stock crítico mínimo', Icons.warning_amber_outlined),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _observCtrl,
                    maxLines: 2,
                    decoration: _deco('Observaciones', Icons.notes_outlined),
                  ),

                  // ── Presentaciones ───────────────────────────────────────
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(child: _seccion('Presentaciones / Stock')),
                      TextButton.icon(
                        onPressed: _agregarPresentacion,
                        icon: const Icon(Icons.add, color: kPrimary, size: 18),
                        label: const Text('Agregar',
                            style: TextStyle(color: kPrimary, fontSize: 13)),
                      ),
                    ],
                  ),
                  if (_presentaciones.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: kSemaforoAmarillo.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: kSemaforoAmarillo.withValues(alpha: 0.4)),
                      ),
                      child: const Text(
                        'Agrega al menos una presentación con su stock y unidad.',
                        style: TextStyle(color: kSemaforoAmarillo, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ...List.generate(_presentaciones.length, (i) =>
                        _buildPresentacionRow(i)),

                  // ── Detalle Químico ──────────────────────────────────────
                  if (_esQuimico) ...[
                    const SizedBox(height: 28),
                    _seccion('Información química (SGA)'),
                    Row(children: [
                      Expanded(child: TextFormField(
                          controller: _formulaCtrl,
                          decoration: _deco('Fórmula química', Icons.science_outlined))),
                      const SizedBox(width: 12),
                      Expanded(child: TextFormField(
                          controller: _casCtrl,
                          decoration: _deco('N.º CAS', Icons.tag))),
                    ]),
                    const SizedBox(height: 14),
                    TextFormField(controller: _concCtrl,
                        decoration: _deco('Concentración', Icons.opacity)),
                  ],

                  // ── Detalle Material ─────────────────────────────────────
                  if (_esMaterial) ...[
                    const SizedBox(height: 28),
                    _seccion('Información del material'),
                    Row(children: [
                      Expanded(child: TextFormField(controller: _marcaCtrl,
                          decoration: _deco('Marca', Icons.label_outline))),
                      const SizedBox(width: 12),
                      Expanded(child: TextFormField(controller: _capacidadCtrl,
                          decoration: _deco('Capacidad', Icons.water_drop_outlined))),
                    ]),
                    const SizedBox(height: 14),
                    TextFormField(controller: _materialCtrl,
                        decoration: _deco('Material', Icons.texture_outlined)),
                    const SizedBox(height: 14),
                    SwitchListTile(
                      value: _esGraduado,
                      onChanged: (v) => setState(() => _esGraduado = v),
                      title: const Text('¿Es graduado?'),
                      activeThumbColor: kPrimary,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildPresentacionRow(int index) {
    final p = _presentaciones[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDEE2E6)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Presentación ${index + 1}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: kPrimary, fontSize: 13)),
              const Spacer(),
              if (_presentaciones.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: kDanger, size: 20),
                  tooltip: 'Eliminar presentación',
                  onPressed: () => _eliminarPresentacion(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: p.stockCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: _deco('Stock actual *', Icons.numbers),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: StatefulBuilder(
                builder: (ctx, setSub) => DropdownButtonFormField<String>(
                  initialValue: p.unidadId,
                  decoration: InputDecoration(
                    labelText: 'Unidad *',
                    prefixIcon: const Icon(Icons.straighten_outlined,
                        color: kPrimary),
                    border: const OutlineInputBorder(),
                    focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: kPrimary, width: 2)),
                  ),
                  items: _unidades.map((u) => DropdownMenuItem(
                    value: u['id'].toString(),
                    child: Text(u['nombre_unidad']),
                  )).toList(),
                  onChanged: (v) {
                    p.unidadId = v;
                    setSub(() {});
                  },
                  validator: (v) => v == null ? 'Selecciona' : null,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          TextFormField(
            controller: p.fotoCtrl,
            decoration: _deco('URL de imagen (opcional)', Icons.image_outlined),
            keyboardType: TextInputType.url,
            onChanged: (_) => setState(() {}),
          ),
          if (p.fotoCtrl.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                p.fotoCtrl.text.trim(),
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _seccion(String titulo) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(titulo,
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.bold, color: kPrimary)),
  );

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: kPrimary),
    border: const OutlineInputBorder(),
    focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: kPrimary, width: 2)),
  );

  Widget _dropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    String? Function(T?)? validator,
  }) =>
      DropdownButtonFormField<T>(
        initialValue: value,
        items: items,
        onChanged: onChanged,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: kPrimary),
          border: const OutlineInputBorder(),
          focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: kPrimary, width: 2)),
        ),
      );
}
