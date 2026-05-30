import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/api/api_client.dart';
import '../core/theme/colors.dart';

class _ItemSolicitud {
  String? insumoId;
  final cantCtrl = TextEditingController(text: '1');
  void dispose() => cantCtrl.dispose();
}

class SolicitudPrestamoScreen extends StatefulWidget {
  const SolicitudPrestamoScreen({super.key});

  @override
  State<SolicitudPrestamoScreen> createState() =>
      _SolicitudPrestamoScreenState();
}

class _SolicitudPrestamoScreenState extends State<SolicitudPrestamoScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _nitCtrl   = TextEditingController();
  final _nomCtrl   = TextEditingController();
  final _corrCtrl  = TextEditingController();
  final _celCtrl   = TextEditingController();
  final _asgCtrl   = TextEditingController();
  final _obsCtrl   = TextEditingController();

  List<Map<String, dynamic>> _insumos   = [];
  List<Map<String, dynamic>> _programas = [];
  String? _programaId;
  final List<_ItemSolicitud> _items = [_ItemSolicitud()];

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
    _nitCtrl.dispose(); _nomCtrl.dispose(); _corrCtrl.dispose();
    _celCtrl.dispose(); _asgCtrl.dispose(); _obsCtrl.dispose();
    for (final i in _items) { i.dispose(); }
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final results = await Future.wait([
        _dio.get('inventario/lista/'),
        _dio.get('academico/programas-publico/'),
      ]);
      final d = results[0].data;
      setState(() {
        _insumos   = List<Map<String, dynamic>>.from(d is List ? d : (d['results'] ?? []));
        _programas = List<Map<String, dynamic>>.from(results[1].data);
        _cargando  = false;
      });
    } catch (_) {
      setState(() => _cargando = false);
    }
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);
    try {
      await _dio.post('operaciones/prestamos/', data: {
        'nit_estudiante':      _nitCtrl.text.trim(),
        'nombre_estudiante':   _nomCtrl.text.trim(),
        'correo_estudiante':   _corrCtrl.text.trim(),
        'celular_solicitante': _celCtrl.text.trim(),
        'programa':            _programaId,
        'asignatura_texto':    _asgCtrl.text.trim(),
        'observaciones':       _obsCtrl.text.trim(),
        'detalles': _items.map((i) => {
          'insumo':            i.insumoId,
          'cantidad_prestada': double.tryParse(i.cantCtrl.text) ?? 1,
        }).toList(),
      });
      setState(() => _enviado = true);
    } on DioException catch (e) {
      final String msg;
      if (e.response?.statusCode == 429) {
        msg = 'Se excedió la cantidad de registros que puedes hacer por hora. Por favor, intenta más tarde.';
      } else {
        final data = e.response?.data;
        if (data is Map && data.isNotEmpty) {
          msg = data.values.first.toString();
        } else {
          msg = 'Error al enviar la solicitud. Intenta de nuevo.';
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: kDanger),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  // ── UI helpers ──────────────────────────────────────────────────────────────

  Widget _header() => Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      color: kPrimary,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(12),
        topRight: Radius.circular(12),
      ),
    ),
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
    child: Column(children: [
      Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.science_outlined, color: Colors.white, size: 32),
      ),
      const SizedBox(height: 12),
      const Text(
        'Solicitud de Préstamo',
        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 4),
      Text(
        'Laboratorios de Ciencias Básicas — Politécnico Colombiano Jaime Isaza Cadavid',
        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
        textAlign: TextAlign.center,
      ),
    ]),
  );

  Widget _seccionLabel(String title) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: kPrimary, fontSize: 13)),
      const Divider(height: 8, thickness: 1, color: Color(0xFFDEE2E6)),
    ]),
  );

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
    prefixIcon: Icon(icon, color: kPrimary, size: 18),
    filled: true,
    fillColor: const Color(0xFFF8F9FA),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFDEE2E6)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFDEE2E6)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: kPrimary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: kDanger),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: kDanger, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    isDense: true,
  );

  // ── build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 700;
    return Scaffold(
      backgroundColor: wide ? const Color(0xFFE9ECEF) : kBackground,
      body: SafeArea(
        child: _enviado ? _buildConfirmacion() : _buildScrollBody(wide),
      ),
    );
  }

  Widget _buildScrollBody(bool wide) {
    final content = Column(children: [
      _header(),
      _buildFormBody(wide),
    ]);

    if (!wide) {
      return SingleChildScrollView(child: content);
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Card(
            elevation: 3,
            shadowColor: Colors.black26,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmacion() {
    final wide = MediaQuery.of(context).size.width >= 700;
    final inner = Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.check_circle, size: 80, color: kSuccess),
        const SizedBox(height: 16),
        const Text('¡Solicitud enviada!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kPrimary)),
        const SizedBox(height: 8),
        const Text(
          'El personal del laboratorio revisará tu solicitud y te notificará cuando esté aprobada.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54, fontSize: 14),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => setState(() {
              _enviado = false;
              _nitCtrl.clear(); _nomCtrl.clear(); _corrCtrl.clear();
              _celCtrl.clear(); _asgCtrl.clear(); _obsCtrl.clear();
              _programaId = null;
              for (final i in _items) { i.dispose(); }
              _items..clear()..add(_ItemSolicitud());
            }),
            child: const Text('Nueva solicitud'),
          ),
        ),
      ]),
    );

    if (!wide) return Center(child: inner);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: inner,
        ),
      ),
    );
  }

  Widget _buildFormBody(bool wide) {
    final padding = wide
        ? const EdgeInsets.fromLTRB(28, 24, 28, 28)
        : const EdgeInsets.all(16);

    return Padding(
      padding: padding,
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            'Completa el formulario para solicitar material del laboratorio.',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 20),

          _seccionLabel('Datos del solicitante'),

          if (wide) ...[
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: TextFormField(
                controller: _nitCtrl,
                keyboardType: TextInputType.number,
                decoration: _deco('Cédula / Carnet *', Icons.badge_outlined),
                validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
              )),
              const SizedBox(width: 16),
              Expanded(child: TextFormField(
                controller: _nomCtrl,
                decoration: _deco('Nombre y apellido *', Icons.person_outline),
                validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
              )),
            ]),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: TextFormField(
                controller: _corrCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: _deco('Correo electrónico *', Icons.email_outlined),
                validator: (v) {
                  if (v!.trim().isEmpty) return 'Requerido';
                  if (!v.contains('@')) return 'Correo inválido';
                  return null;
                },
              )),
              const SizedBox(width: 16),
              Expanded(child: TextFormField(
                controller: _celCtrl,
                keyboardType: TextInputType.phone,
                decoration: _deco('Número de celular *', Icons.phone_outlined),
                validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
              )),
            ]),
          ] else ...[
            TextFormField(
              controller: _nitCtrl,
              keyboardType: TextInputType.number,
              decoration: _deco('Cédula / Carnet *', Icons.badge_outlined),
              validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _nomCtrl,
              decoration: _deco('Nombre y apellido *', Icons.person_outline),
              validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _corrCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: _deco('Correo electrónico *', Icons.email_outlined),
              validator: (v) {
                if (v!.trim().isEmpty) return 'Requerido';
                if (!v.contains('@')) return 'Correo inválido';
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _celCtrl,
              keyboardType: TextInputType.phone,
              decoration: _deco('Número de celular *', Icons.phone_outlined),
              validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
            ),
          ],

          const SizedBox(height: 12),
          if (_programas.isEmpty && !_cargando)
            const SizedBox.shrink()
          else
            DropdownButtonFormField<String>(
              initialValue: _programaId,
              decoration: _deco('Programa académico *', Icons.school_outlined),
              items: _programas.map((p) => DropdownMenuItem(
                value: p['id'].toString(),
                child: Text(p['nombre'] ?? '', style: const TextStyle(fontSize: 13)),
              )).toList(),
              onChanged: (v) => setState(() => _programaId = v),
              validator: (_) => _programaId == null ? 'Selecciona tu programa' : null,
            ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _asgCtrl,
            decoration: _deco('Asignatura', Icons.menu_book_outlined),
          ),
          const SizedBox(height: 20),

          _seccionLabel('Materiales a solicitar'),
          if (_cargando)
            const Center(child: CircularProgressIndicator(color: kPrimary))
          else if (_insumos.isEmpty)
            const Text('No se pudieron cargar los materiales.',
                style: TextStyle(color: kDanger))
          else
            ...List.generate(_items.length, (i) => _buildItemRow(i)),
          TextButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Agregar ítem'),
            onPressed: () => setState(() => _items.add(_ItemSolicitud())),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _obsCtrl,
            maxLines: 2,
            decoration: _deco('Observaciones (opcional)', Icons.notes_outlined),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_enviando || _cargando) ? null : _enviar,
              icon: _enviando
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_outlined),
              label: const Text('Enviar solicitud',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildItemRow(int i) {
    final item = _items[i];
    final nombre = item.insumoId == null ? null
        : _insumos.where((x) => x['id']?.toString() == item.insumoId)
            .map((x) => x['nombre_insumo']?.toString() ?? '').firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: FormField<String>(
            initialValue: item.insumoId,
            validator: (_) => item.insumoId == null ? 'Selecciona un material' : null,
            builder: (state) => InkWell(
              onTap: () async {
                final sel = await showDialog<Map<String, dynamic>>(
                  context: context,
                  builder: (_) => _DialogMaterial(insumos: _insumos),
                );
                if (sel != null) {
                  setState(() => item.insumoId = sel['id']?.toString());
                  state.didChange(item.insumoId);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  border: Border.all(
                      color: state.hasError ? kDanger : const Color(0xFFDEE2E6)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    const Icon(Icons.inventory_2_outlined, color: kPrimary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(nombre ?? 'Seleccionar material...',
                        style: TextStyle(color: nombre != null ? Colors.black87 : Colors.grey, fontSize: 14),
                        overflow: TextOverflow.ellipsis)),
                    const Icon(Icons.search, color: kTextMuted, size: 16),
                  ]),
                  if (state.hasError)
                    Padding(padding: const EdgeInsets.only(top: 4),
                        child: Text(state.errorText!, style: const TextStyle(color: kDanger, fontSize: 12))),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: item.cantCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _deco('Cant.', Icons.numbers),
            validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? '>0' : null,
          ),
        ),
        if (_items.length > 1)
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: kDanger, size: 20),
            onPressed: () => setState(() { _items[i].dispose(); _items.removeAt(i); }),
          ),
      ]),
    );
  }
}

class _DialogMaterial extends StatefulWidget {
  final List<Map<String, dynamic>> insumos;
  const _DialogMaterial({required this.insumos});
  @override
  State<_DialogMaterial> createState() => _DialogMaterialState();
}

class _DialogMaterialState extends State<_DialogMaterial> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtrados = widget.insumos
        .where((i) => (i['nombre_insumo']?.toString() ?? '').toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return AlertDialog(
      title: const Text('Seleccionar material', style: TextStyle(color: kPrimary, fontSize: 16)),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      content: SizedBox(width: 380, height: 360, child: Column(children: [
        TextField(
          autofocus: true,
          onChanged: (v) => setState(() => _query = v),
          decoration: const InputDecoration(
            hintText: 'Buscar material...',
            prefixIcon: Icon(Icons.search, color: kPrimary, size: 18),
            border: OutlineInputBorder(),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: kPrimary)),
            isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: filtrados.isEmpty
            ? const Center(child: Text('Sin resultados', style: TextStyle(color: kTextMuted)))
            : ListView.builder(
                itemCount: filtrados.length,
                itemBuilder: (_, i) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.inventory_2_outlined, color: kPrimary, size: 20),
                  title: Text(filtrados[i]['nombre_insumo']?.toString() ?? '',
                      style: const TextStyle(fontSize: 13)),
                  onTap: () => Navigator.pop(context, filtrados[i]),
                ),
              )),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar'))],
    );
  }
}
