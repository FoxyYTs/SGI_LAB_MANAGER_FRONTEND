import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api/api_client.dart';
import '../core/theme/colors.dart';
import '../providers/auth_provider.dart';

class InsumoFormScreen extends StatefulWidget {
  /// Si [insumo] no es null, estamos editando; si es null, estamos creando.
  final Map<String, dynamic>? insumo;
  const InsumoFormScreen({super.key, this.insumo});

  @override
  State<InsumoFormScreen> createState() => _InsumoFormScreenState();
}

class _InsumoFormScreenState extends State<InsumoFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores de texto
  final _nombreCtrl      = TextEditingController();
  final _stockActualCtrl = TextEditingController(text: '0');
  final _stockMinimoCtrl = TextEditingController(text: '0');
  final _observCtrl      = TextEditingController();

  // Detalles químico
  final _formulaCtrl       = TextEditingController();
  final _casCtrl           = TextEditingController();
  final _concCtrl          = TextEditingController();
  final _pictogramasCtrl   = TextEditingController();
  final _frasesHCtrl       = TextEditingController();
  final _frasesPCtrl       = TextEditingController();

  // Detalles material
  final _marcaCtrl       = TextEditingController();
  final _capacidadCtrl   = TextEditingController();
  final _materialCtrl    = TextEditingController();
  bool  _esGraduado      = false;

  // Dropdowns
  List<Map<String, dynamic>> _tipos       = [];
  List<Map<String, dynamic>> _ubicaciones = [];
  List<Map<String, dynamic>> _unidades    = [];

  String? _tipoId;
  String? _ubicacionId;
  String? _unidadId;
  String  _tipoNombre = '';

  bool _loading    = true;
  bool _guardando  = false;

  // Foto (URL externa — imgur, drive, etc.)
  final _fotoCtrl = TextEditingController();

  bool get _esQuimico  => _tipoNombre == 'Químico';
  bool get _esMaterial => _tipoNombre == 'Implemento' || _tipoNombre == 'Vidriería';

  @override
  void initState() {
    super.initState();
    _cargarOpciones();
  }

  @override
  void dispose() {
    for (final c in [
      _nombreCtrl, _stockActualCtrl, _stockMinimoCtrl, _observCtrl, _fotoCtrl,
      _formulaCtrl, _casCtrl, _concCtrl, _pictogramasCtrl, _frasesHCtrl, _frasesPCtrl,
      _marcaCtrl, _capacidadCtrl, _materialCtrl,
    ]) {
      c.dispose();
    }
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
      setState(() {
        List<Map<String, dynamic>> _parse(dynamic d) =>
            List<Map<String, dynamic>>.from(d is List ? d : (d['results'] ?? []));
        _tipos       = _parse(results[0].data);
        _ubicaciones = _parse(results[1].data);
        _unidades    = _parse(results[2].data);
        _loading     = false;
      });
      _precargarEdicion();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _precargarEdicion() {
    final ins = widget.insumo;
    if (ins == null) return;
    _nombreCtrl.text      = ins['nombre_insumo'] ?? '';
    _stockActualCtrl.text = ins['stock_actual']?.toString() ?? '0';
    _stockMinimoCtrl.text = ins['stock_minimo']?.toString() ?? '0';
    _observCtrl.text      = ins['observaciones'] ?? '';
    _tipoId     = ins['tipo_insumo']?.toString();
    _ubicacionId = ins['ubicacion']?.toString();
    _unidadId   = ins['unidad_medida']?.toString();
    _tipoNombre     = ins['tipo_nombre'] ?? '';
    _fotoCtrl.text  = ins['foto'] as String? ?? '';
    setState(() {});
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final auth = context.read<AuthProvider>();
    final dio  = ApiClient.instance.authenticatedDio(auth.token);

    final body = {
      'nombre_insumo': _nombreCtrl.text.trim(),
      'tipo_insumo':   _tipoId,
      'unidad_medida': _unidadId,
      'ubicacion':     _ubicacionId,
      'stock_actual':  double.tryParse(_stockActualCtrl.text) ?? 0,
      'stock_minimo':  double.tryParse(_stockMinimoCtrl.text) ?? 0,
      'observaciones': _observCtrl.text.trim(),
      'foto':          _fotoCtrl.text.trim().isEmpty ? null : _fotoCtrl.text.trim(),
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

      // Guarda detalle según tipo
      if (_esQuimico) {
        await dio.post('inventario/lista/$id/quimico/', data: {
          'formula_quimica': _formulaCtrl.text.trim(),
          'numero_cas':      _casCtrl.text.trim(),
          'concentracion':   _concCtrl.text.trim(),
          'pictogramas_sga': _pictogramasCtrl.text.trim(),
          'frases_h':        _frasesHCtrl.text.trim(),
          'frases_p':        _frasesPCtrl.text.trim(),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Insumo guardado correctamente.'),
          backgroundColor: kSuccess,
        ));
        Navigator.pop(context, true);
      }
    } catch (e) {
      String msg = 'Error al guardar el insumo.';
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
                  _seccion('Información general'),
                  TextFormField(
                    controller: _nombreCtrl,
                    decoration: _deco('Nombre del insumo *', Icons.inventory_2_outlined),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: _dropdown<String>(
                      label: 'Tipo de insumo *',
                      icon: Icons.category_outlined,
                      value: _tipoId,
                      items: _tipos.map((t) => DropdownMenuItem(
                        value: t['id'].toString(),
                        child: Text(t['nombre_tipo']),
                      )).toList(),
                      onChanged: (v) {
                        final tipo = _tipos.firstWhere((t) => t['id'].toString() == v,
                            orElse: () => {});
                        setState(() {
                          _tipoId     = v;
                          _tipoNombre = tipo['nombre_tipo'] ?? '';
                        });
                      },
                      validator: (v) => v == null ? 'Selecciona un tipo' : null,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _dropdown<String>(
                      label: 'Unidad de medida *',
                      icon: Icons.straighten_outlined,
                      value: _unidadId,
                      items: _unidades.map((u) => DropdownMenuItem(
                        value: u['id'].toString(),
                        child: Text(u['nombre_unidad']),
                      )).toList(),
                      onChanged: (v) => setState(() => _unidadId = v),
                      validator: (v) => v == null ? 'Selecciona una unidad' : null,
                    )),
                  ]),
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
                  Row(children: [
                    Expanded(child: TextFormField(
                      controller: _stockActualCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _deco('Stock actual', Icons.numbers),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(
                      controller: _stockMinimoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _deco('Stock mínimo', Icons.warning_amber_outlined),
                    )),
                  ]),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _observCtrl,
                    maxLines: 2,
                    decoration: _deco('Observaciones', Icons.notes_outlined),
                  ),
                  const SizedBox(height: 20),

                  // ── Foto ──
                  _seccion('Foto del insumo'),
                  _buildFotoSelector(),

                  // ── Detalle Químico ──
                  if (_esQuimico) ...[
                    const SizedBox(height: 24),
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
                    const SizedBox(height: 14),
                    TextFormField(controller: _pictogramasCtrl,
                        decoration: _deco('Pictogramas GHS (JSON array)', Icons.warning_amber_outlined,
                            hintText: '["GHS01","GHS06"]')),
                    const SizedBox(height: 14),
                    TextFormField(controller: _frasesHCtrl, maxLines: 3,
                        decoration: _deco('Frases H', Icons.info_outline)),
                    const SizedBox(height: 14),
                    TextFormField(controller: _frasesPCtrl, maxLines: 3,
                        decoration: _deco('Frases P', Icons.health_and_safety_outlined)),
                  ],

                  // ── Detalle Material ──
                  if (_esMaterial) ...[
                    const SizedBox(height: 24),
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

  Widget _buildFotoSelector() {
    final url = _fotoCtrl.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (url.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('URL de imagen inválida o inaccesible',
                      style: TextStyle(color: kTextMuted, fontSize: 12)),
                ),
              ),
            ),
          ),
        TextFormField(
          controller: _fotoCtrl,
          decoration: _deco('URL de imagen (imgur, drive…)', Icons.image_outlined),
          keyboardType: TextInputType.url,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 4),
        const Text(
          'Pega el enlace directo a la imagen. Ej: https://i.imgur.com/abc123.jpg',
          style: TextStyle(fontSize: 11, color: kTextMuted),
        ),
      ],
    );
  }

  Widget _seccion(String titulo) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(titulo,
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.bold, color: kPrimary)),
  );

  InputDecoration _deco(String label, IconData icon, {String? hintText}) =>
      InputDecoration(
        labelText: label,
        hintText: hintText,
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
