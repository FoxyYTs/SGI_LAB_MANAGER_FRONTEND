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
  final _formKey  = GlobalKey<FormState>();
  final _nitCtrl  = TextEditingController();
  final _nomCtrl  = TextEditingController();
  final _corrCtrl = TextEditingController();
  final _obsCtrl  = TextEditingController();

  List<Map<String, dynamic>> _insumos = [];
  final List<_ItemSolicitud>  _items   = [_ItemSolicitud()];
  bool _cargandoInsumos = true;
  bool _enviando        = false;
  bool _enviado         = false;

  @override
  void initState() {
    super.initState();
    _cargarInsumos();
  }

  @override
  void dispose() {
    _nitCtrl.dispose();
    _nomCtrl.dispose();
    _corrCtrl.dispose();
    _obsCtrl.dispose();
    for (final i in _items) i.dispose();
    super.dispose();
  }

  Future<void> _cargarInsumos() async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: ApiClient.instance.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final r = await dio.get('inventario/lista/');
      final data = r.data;
      setState(() {
        _insumos = List<Map<String, dynamic>>.from(
          data is List ? data : (data['results'] ?? []));
        _cargandoInsumos = false;
      });
    } catch (_) {
      setState(() => _cargandoInsumos = false);
    }
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);
    try {
      final dio = Dio(BaseOptions(
        baseUrl: ApiClient.instance.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      await dio.post('operaciones/prestamos/', data: {
        'nit_estudiante':    _nitCtrl.text.trim(),
        'nombre_estudiante': _nomCtrl.text.trim(),
        'correo_estudiante': _corrCtrl.text.trim(),
        'observaciones':     _obsCtrl.text.trim(),
        'detalles': _items.map((i) => {
          'insumo':           i.insumoId,
          'cantidad_prestada': double.tryParse(i.cantCtrl.text) ?? 1,
        }).toList(),
      });
      setState(() => _enviado = true);
    } catch (e) {
      String msg = 'Error al enviar la solicitud. Intenta de nuevo.';
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
        backgroundColor: kPrimary,
        title: const Text(
          'Solicitud de Préstamo',
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
          const Icon(Icons.check_circle_outline,
              size: 80, color: kSuccess),
          const SizedBox(height: 16),
          const Text(
            '¡Solicitud enviada!',
            style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: kPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            'El personal del laboratorio revisará tu solicitud y te notificará cuando esté aprobada.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary, foregroundColor: Colors.white),
            onPressed: () => setState(() {
              _enviado = false;
              _nitCtrl.clear();
              _nomCtrl.clear();
              _corrCtrl.clear();
              _obsCtrl.clear();
              for (final i in _items) i.dispose();
              _items
                ..clear()
                ..add(_ItemSolicitud());
            }),
            child: const Text('Nueva solicitud'),
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
            'Completa el formulario para solicitar material del laboratorio.',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 20),

          // Datos personales
          _seccion('Datos del solicitante'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nitCtrl,
            keyboardType: TextInputType.number,
            decoration: _deco('Cédula / Carnet *', Icons.badge_outlined),
            validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _nomCtrl,
            decoration: _deco('Nombre completo *', Icons.person_outline),
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
          const SizedBox(height: 20),

          // Ítems
          _seccion('Materiales a solicitar'),
          const SizedBox(height: 8),
          if (_cargandoInsumos)
            const Center(child: CircularProgressIndicator(color: kPrimary))
          else if (_insumos.isEmpty)
            const Text(
              'No se pudieron cargar los materiales disponibles.',
              style: TextStyle(color: Colors.red),
            )
          else
            ...List.generate(_items.length,
                (i) => _buildItemRow(i)),
          TextButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Agregar ítem'),
            onPressed: () => setState(() => _items.add(_ItemSolicitud())),
          ),
          const SizedBox(height: 12),

          // Observaciones
          TextFormField(
            controller: _obsCtrl,
            maxLines: 2,
            decoration: _deco(
                'Observaciones (opcional)', Icons.notes_outlined),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _enviando ? null : _enviar,
              icon: _enviando
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_outlined),
              label: const Text('Enviar solicitud'),
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
  );

  Widget _buildItemRow(int i) {
    final item = _items[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<String>(
            value: item.insumoId,
            decoration: _deco('Material', Icons.inventory_2_outlined),
            items: _insumos.map<DropdownMenuItem<String>>((ins) =>
              DropdownMenuItem(
                value: ins['id']?.toString(),
                child: Text(
                  ins['nombre_insumo']?.toString() ?? '',
                  overflow: TextOverflow.ellipsis,
                ),
              )).toList(),
            onChanged: (v) => setState(() => item.insumoId = v),
            validator: (v) => v == null ? 'Selecciona un material' : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: item.cantCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: _deco('Cant.', Icons.numbers),
            validator: (v) =>
                (double.tryParse(v ?? '') ?? 0) <= 0 ? '>0' : null,
          ),
        ),
        if (_items.length > 1)
          IconButton(
            icon: const Icon(Icons.remove_circle_outline,
                color: Colors.red, size: 20),
            onPressed: () => setState(() {
              _items[i].dispose();
              _items.removeAt(i);
            }),
          ),
      ]),
    );
  }

  Widget _seccion(String title) => Text(
    title,
    style: const TextStyle(
      fontWeight: FontWeight.bold, color: kPrimary, fontSize: 14),
  );

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: kPrimary, size: 18),
    border: const OutlineInputBorder(),
    focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: kPrimary)),
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    isDense: true,
  );
}
