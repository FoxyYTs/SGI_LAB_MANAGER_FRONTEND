import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/api/api_client.dart';
import '../core/theme/colors.dart';

class ReporteRoturaScreen extends StatefulWidget {
  const ReporteRoturaScreen({super.key});

  @override
  State<ReporteRoturaScreen> createState() => _ReporteRoturaScreenState();
}

class _ReporteRoturaScreenState extends State<ReporteRoturaScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _nomCtrl   = TextEditingController();
  final _nitCtrl   = TextEditingController();
  final _cantCtrl  = TextEditingController(text: '1');
  final _obsCtrl   = TextEditingController();

  List<Map<String, dynamic>> _insumos = [];
  String? _insumoId;
  bool _cargando = true;
  bool _enviando = false;
  bool _enviado  = false;

  late final Dio _dio;

  @override
  void initState() {
    super.initState();
    _dio = Dio(BaseOptions(
      baseUrl: ApiClient.instance.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
    _cargar();
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _nitCtrl.dispose();
    _cantCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final r = await _dio.get('inventario/lista/');
      final data = r.data;
      setState(() {
        _insumos = List<Map<String, dynamic>>.from(
          data is List ? data : (data['results'] ?? []));
        _cargando = false;
      });
    } catch (_) {
      setState(() => _cargando = false);
    }
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);
    try {
      await _dio.post('operaciones/reporte-rotura/', data: {
        'nombre_estudiante': _nomCtrl.text.trim(),
        'nit_estudiante':    _nitCtrl.text.trim(),
        'insumo':            _insumoId,
        'cantidad':          double.tryParse(_cantCtrl.text) ?? 1,
        'observaciones':     _obsCtrl.text.trim(),
      });
      setState(() => _enviado = true);
    } catch (e) {
      String msg = 'Error al enviar. Intenta de nuevo.';
      try {
        final data = (e as dynamic).response?.data;
        if (data is Map) msg = data.values.first.toString();
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red[700]),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: kDanger,
        title: const Text(
          'Reporte de Rotura',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _enviado ? _buildConfirmacion() : _buildForm(),
    );
  }

  Widget _buildConfirmacion() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, size: 80, color: kSuccess),
          const SizedBox(height: 16),
          const Text(
            '¡Reporte enviado!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            'El personal del laboratorio revisará el reporte.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary, foregroundColor: Colors.white),
            onPressed: () => setState(() {
              _enviado = false;
              _nomCtrl.clear();
              _nitCtrl.clear();
              _cantCtrl.text = '1';
              _obsCtrl.clear();
              _insumoId = null;
            }),
            child: const Text('Nuevo reporte'),
          ),
        ],
      ),
    ),
  );

  Widget _buildForm() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Completa este formulario si rompiste o perdiste un implemento del laboratorio.',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 20),

          _seccion('Tus datos'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nomCtrl,
            decoration: _deco('Nombre completo *', Icons.person_outline),
            validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _nitCtrl,
            keyboardType: TextInputType.number,
            decoration: _deco('Cédula / Carnet *', Icons.badge_outlined),
            validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
          ),

          const SizedBox(height: 20),
          _seccion('Implemento roto o perdido'),
          const SizedBox(height: 8),

          if (_cargando)
            const Center(child: CircularProgressIndicator(color: kPrimary))
          else if (_insumos.isEmpty)
            const Text(
              'No se pudo cargar la lista de implementos.',
              style: TextStyle(color: Colors.red),
            )
          else
            FormField<String>(
              initialValue: _insumoId,
              validator: (_) => _insumoId == null ? 'Selecciona el implemento' : null,
              builder: (state) {
                final nombre = _insumoId == null
                    ? null
                    : _insumos
                        .where((x) => x['id']?.toString() == _insumoId)
                        .map((x) => x['nombre_insumo']?.toString() ?? '')
                        .firstOrNull;
                return InkWell(
                  onTap: () async {
                    final sel = await showDialog<Map<String, dynamic>>(
                      context: context,
                      builder: (_) => _DialogImplemento(insumos: _insumos),
                    );
                    if (sel != null) {
                      setState(() => _insumoId = sel['id']?.toString());
                      state.didChange(_insumoId);
                    }
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: state.hasError ? Colors.red : const Color(0xFFAAAAAA)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(children: [
                          const Icon(Icons.inventory_2_outlined, color: kPrimary, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              nombre ?? 'Seleccionar implemento...',
                              style: TextStyle(
                                color: nombre != null ? Colors.black87 : Colors.grey,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.search, color: kTextMuted, size: 16),
                        ]),
                        if (state.hasError)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(state.errorText!,
                                style: const TextStyle(color: Colors.red, fontSize: 12)),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),

          const SizedBox(height: 12),
          TextFormField(
            controller: _cantCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _deco('Cantidad *', Icons.numbers),
            validator: (v) =>
                (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Debe ser mayor a 0' : null,
          ),

          const SizedBox(height: 12),
          TextFormField(
            controller: _obsCtrl,
            maxLines: 3,
            decoration: _deco('¿Qué sucedió? (opcional)', Icons.notes_outlined),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_enviando || _cargando) ? null : _enviar,
              icon: _enviando
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.report_outlined),
              label: const Text('Enviar reporte'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kDanger,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _seccion(String title) => Text(
    title,
    style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimary, fontSize: 14),
  );

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: kPrimary, size: 18),
    border: const OutlineInputBorder(),
    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: kPrimary)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    isDense: true,
  );
}

// ── Diálogo de búsqueda de implementos ───────────────────────────────────────

class _DialogImplemento extends StatefulWidget {
  final List<Map<String, dynamic>> insumos;
  const _DialogImplemento({required this.insumos});

  @override
  State<_DialogImplemento> createState() => _DialogImplementoState();
}

class _DialogImplementoState extends State<_DialogImplemento> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtrados = widget.insumos
        .where((i) => (i['nombre_insumo']?.toString() ?? '')
            .toLowerCase()
            .contains(_query.toLowerCase()))
        .toList();

    return AlertDialog(
      title: const Text('Seleccionar implemento',
          style: TextStyle(color: kPrimary, fontSize: 16)),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      content: SizedBox(
        width: 380,
        height: 360,
        child: Column(children: [
          TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: 'Buscar implemento...',
              prefixIcon: Icon(Icons.search, color: kPrimary, size: 18),
              border: OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: kPrimary)),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                        leading: const Icon(Icons.inventory_2_outlined,
                            color: kPrimary, size: 20),
                        title: Text(
                            ins['nombre_insumo']?.toString() ?? '',
                            style: const TextStyle(fontSize: 13)),
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
