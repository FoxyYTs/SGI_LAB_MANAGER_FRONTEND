import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api/api_client.dart';
import '../core/api/paginacion.dart';
import '../core/theme/colors.dart';
import '../providers/auth_provider.dart';

// ── Modelo local para una presentación en el formulario ──────────────────────

class _PresentacionRow {
  String? id; // null = nueva, String = existente
  final TextEditingController stockCtrl;
  final TextEditingController fotoCtrl;
  String? unidadId;
  /// Stock que tenía la presentación en el servidor cuando se cargó (o tras
  /// el último guardado). El backend ya no acepta `stock_actual` "a ciegas":
  /// para cambiarlo hay que mandar también este valor (`stock_anterior`) y
  /// el servidor registra la diferencia como AJUSTE en la bitácora, o
  /// responde 409 si alguien movió el stock mientras se editaba.
  String? stockServidor;
  /// false = desactivada en el servidor (no se presta ni cuenta en el total).
  bool activa;

  _PresentacionRow({this.id, String stock = '0', String foto = '', this.unidadId,
      this.stockServidor, this.activa = true})
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
  // Unidad de cada presentación marcada para borrar (para el aviso si el
  // backend no deja borrarla por tener historial).
  final Map<String, String> _unidadEliminada = {};
  // Presentación cuyo estado activa/inactiva se está cambiando.
  String? _cambiandoEstado;

  bool _loading   = true;
  bool _guardando = false;
  // id del insumo ya creado en un intento anterior de "Guardar" que falló
  // a mitad (p. ej. en las presentaciones): los reintentos hacen PATCH sobre
  // él en vez de crear otro insumo duplicado.
  String? _insumoIdGuardado;

  static double? _numero(String? texto) =>
      double.tryParse((texto ?? '').trim().replaceAll(',', '.'));

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
        obtenerTodas(dio, 'inventario/tipos/'),
        obtenerTodas(dio, 'inventario/ubicaciones/'),
        obtenerTodas(dio, 'inventario/unidades/'),
      ]);
      if (!mounted) return;
      setState(() {
        _tipos       = results[0];
        _ubicaciones = results[1];
        _unidades    = results[2];
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
        stockServidor: p['stock_actual']?.toString(),
        activa:   p['activa'] != false,
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
    if (row.id != null) {
      _presentacionesEliminar.add(row.id!);
      _unidadEliminada[row.id!] = _nombreUnidad(row.unidadId);
    }
    row.dispose();
    setState(() => _presentaciones.removeAt(index));
  }

  String _nombreUnidad(String? unidadId) => _unidades
          .firstWhere((u) => u['id'].toString() == unidadId,
              orElse: () => const {})['nombre_unidad']
          ?.toString() ??
      '';

  String get _insumoId =>
      (widget.insumo?['id']?.toString() ?? _insumoIdGuardado)!;

  /// Desactiva / reactiva YA (no espera a "Guardar") una presentación
  /// existente. Es la alternativa a borrarla cuando tiene historial.
  Future<void> _cambiarEstado(_PresentacionRow p, bool activar) async {
    if (p.id == null || _cambiandoEstado != null) return;
    setState(() => _cambiandoEstado = p.id);
    try {
      final dio = ApiClient.instance
          .authenticatedDio(context.read<AuthProvider>().token);
      await dio.post('inventario/lista/$_insumoId/presentaciones/${p.id}/'
          '${activar ? 'activar' : 'desactivar'}/');
      if (!mounted) return;
      setState(() => p.activa = activar);
      _snack(activar ? 'Presentación reactivada.' : 'Presentación desactivada.',
          kSuccess);
    } on DioException catch (e) {
      final data = e.response?.data;
      _snack('No se pudo cambiar la presentación: '
          '${data is Map ? (data['error'] ?? data['detail'] ?? data.values.first) : e.message}',
          kDanger);
    } finally {
      if (mounted) setState(() => _cambiandoEstado = null);
    }
  }

  /// Borra una presentación marcada para eliminar. Si el backend responde
  /// 409 (tiene préstamos o movimientos) ofrece desactivarla en su lugar.
  /// Devuelve normalmente en ambos casos; otros errores se propagan.
  Future<void> _borrarPresentacion(Dio dio, String insumoId, String presId) async {
    try {
      await dio.delete('inventario/lista/$insumoId/presentaciones/$presId/');
    } on DioException catch (e) {
      if (e.response?.statusCode != 409 || !mounted) rethrow;
      final unidad = _unidadEliminada[presId] ?? '';
      final desactivar = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('No se puede eliminar'),
          content: Text(
              'La presentación${unidad.isEmpty ? '' : ' "$unidad"'} tiene '
              'préstamos o movimientos registrados y no se puede borrar.\n\n'
              '¿Quieres desactivarla? Dejará de ofrecerse para préstamos y su '
              'stock no contará en el total, pero conservará su historial.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Mantenerla activa')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Desactivar',
                    style: TextStyle(color: kDanger))),
          ],
        ),
      );
      if (desactivar == true) {
        await dio.post('inventario/lista/$insumoId/presentaciones/$presId/desactivar/');
      }
    }
  }

  Future<void> _guardar() async {
    if (_guardando) return; // doble tap antes de que se deshabilite
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
      final idExistente = widget.insumo?['id']?.toString() ?? _insumoIdGuardado;
      if (idExistente != null) {
        final r  = await dio.patch('inventario/lista/$idExistente/', data: body);
        insumo   = Map<String, dynamic>.from(r.data);
      } else {
        final r = await dio.post('inventario/lista/', data: body);
        insumo  = Map<String, dynamic>.from(r.data);
        _insumoIdGuardado = insumo['id']?.toString();
      }

      final id = insumo['id'];

      // Eliminar presentaciones borradas (se van quitando de la lista para
      // que un reintento no las vuelva a borrar)
      for (final presId in List<String>.from(_presentacionesEliminar)) {
        await _borrarPresentacion(dio, id.toString(), presId);
        _presentacionesEliminar.remove(presId);
      }

      // Guardar presentaciones
      for (final p in _presentaciones) {
        final presBody = <String, dynamic>{
          'unidad_medida': p.unidadId,
          'foto':          p.fotoCtrl.text.trim().isEmpty ? null : p.fotoCtrl.text.trim(),
        };
        final stock = _numero(p.stockCtrl.text) ?? 0;
        if (p.id != null) {
          // Solo se manda el stock si el usuario lo cambió, junto con el
          // valor que vio (stock_anterior): el backend lo registra como
          // AJUSTE o responde 409 si cambió mientras tanto.
          if (p.stockServidor != null && _numero(p.stockServidor) != stock) {
            presBody['stock_actual']   = stock;
            presBody['stock_anterior'] = p.stockServidor;
          }
          final r = await dio.patch('inventario/lista/$id/presentaciones/${p.id}/', data: presBody);
          p.stockServidor = r.data['stock_actual']?.toString() ?? p.stockServidor;
        } else {
          presBody['stock_actual'] = stock;
          final r = await dio.post('inventario/lista/$id/presentaciones/', data: presBody);
          // Recordar el id: si algo posterior falla, el reintento hace PATCH
          // en vez de crear la presentación (y su stock inicial) otra vez.
          p.id = r.data['id']?.toString();
          p.stockServidor = r.data['stock_actual']?.toString();
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
              if (!p.activa) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9ECEF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('INACTIVA',
                      style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold,
                          color: kTextMuted)),
                ),
              ],
              const Spacer(),
              if (p.id != null)
                _cambiandoEstado == p.id
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: kPrimary)))
                    : TextButton.icon(
                        onPressed: () => _cambiarEstado(p, !p.activa),
                        icon: Icon(p.activa ? Icons.block : Icons.restore,
                            size: 16,
                            color: p.activa ? kTextMuted : kSuccess),
                        label: Text(p.activa ? 'Desactivar' : 'Reactivar',
                            style: TextStyle(
                                fontSize: 12,
                                color: p.activa ? kTextMuted : kSuccess)),
                      ),
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
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requerido';
                  final n = _numero(v);
                  if (n == null) return 'Número inválido';
                  if (n < 0) return 'No puede ser negativo';
                  return null;
                },
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
