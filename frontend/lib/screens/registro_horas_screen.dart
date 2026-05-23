import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/api/api_client.dart';
import '../core/theme/colors.dart';

class RegistroHorasScreen extends StatefulWidget {
  const RegistroHorasScreen({super.key});

  @override
  State<RegistroHorasScreen> createState() => _RegistroHorasScreenState();
}

class _RegistroHorasScreenState extends State<RegistroHorasScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _celCtrl     = TextEditingController();
  final _descCtrl    = TextEditingController();
  final _durCtrl     = TextEditingController();

  List<Map<String, dynamic>> _monitores = [];
  Map<String, dynamic>? _monitorSel;

  // Auto-filled from profile
  String? _programaId;
  String  _programaNombre = '';
  int?    _semestre;

  DateTime? _fechaActividad;

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
    _celCtrl.dispose();
    _descCtrl.dispose();
    _durCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final r = await _dio.get('academico/monitores-publico/');
      setState(() {
        _monitores = List<Map<String, dynamic>>.from(r.data);
        _cargando  = false;
      });
    } catch (_) {
      setState(() => _cargando = false);
    }
  }

  void _onMonitorChanged(Map<String, dynamic>? m) {
    if (m == null) return;
    setState(() {
      _monitorSel     = m;
      _celCtrl.text   = m['celular']?.toString() ?? '';
      _programaId     = m['programa_id']?.toString();
      _programaNombre = m['programa_nombre']?.toString() ?? '';
      _semestre       = m['semestre'] as int?;
    });
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaActividad ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: kPrimary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _fechaActividad = picked);
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);
    try {
      await _dio.post('academico/registro-horas/', data: {
        'nombre_monitor':  _monitorSel!['nombre'],
        'nit_monitor':     _monitorSel!['nit']?.toString() ?? '',
        'programa':        _programaId,
        'semestre':        _semestre,
        'celular':         _celCtrl.text.trim(),
        'descripcion':     _descCtrl.text.trim(),
        'fecha_actividad': _fechaActividad != null
            ? '${_fechaActividad!.year}-${_fechaActividad!.month.toString().padLeft(2, '0')}-${_fechaActividad!.day.toString().padLeft(2, '0')}'
            : null,
        'duracion_horas':  double.tryParse(_durCtrl.text) ?? 0,
      });
      setState(() => _enviado = true);
    } catch (e) {
      String msg = 'Error al registrar. Intenta de nuevo.';
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
        title: const Text('Registro de Horas Monitor',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _enviado ? _buildConfirmacion() : _buildForm(),
    );
  }

  Widget _buildConfirmacion() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.check_circle_outline, size: 80, color: kSuccess),
        const SizedBox(height: 16),
        const Text('¡Actividad registrada!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kPrimary)),
        const SizedBox(height: 8),
        Text(_monitorSel!['nombre']?.toString() ?? '',
            style: const TextStyle(fontSize: 16, color: Colors.black54)),
        const SizedBox(height: 24),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
          onPressed: () => setState(() {
            _enviado     = false;
            _monitorSel  = null;
            _programaId  = null;
            _programaNombre = '';
            _semestre    = null;
            _fechaActividad = null;
            _celCtrl.clear();
            _descCtrl.clear();
            _durCtrl.clear();
          }),
          child: const Text('Nuevo registro'),
        ),
      ]),
    ),
  );

  Widget _buildForm() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Registra las actividades realizadas durante tu turno en el laboratorio.',
            style: TextStyle(fontSize: 14, color: Colors.black54)),
        const SizedBox(height: 20),

        _seccion('Monitor'),
        const SizedBox(height: 8),
        if (_cargando)
          const Center(child: CircularProgressIndicator(color: kPrimary))
        else if (_monitores.isEmpty)
          const Text('No se pudieron cargar los monitores.',
              style: TextStyle(color: Colors.red))
        else
          DropdownButtonFormField<Map<String, dynamic>>(
            value: _monitorSel,
            decoration: _deco('Selecciona tu nombre *', Icons.person_outline),
            items: _monitores.map((m) => DropdownMenuItem(
              value: m,
              child: Text(m['nombre']?.toString() ?? ''),
            )).toList(),
            onChanged: _onMonitorChanged,
            validator: (_) => _monitorSel == null ? 'Selecciona tu nombre' : null,
          ),

        if (_monitorSel != null) ...[
          const SizedBox(height: 10),
          // Read-only programa chip
          if (_programaNombre.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                const Icon(Icons.school_outlined, color: kPrimary, size: 16),
                const SizedBox(width: 6),
                Text(_programaNombre,
                    style: const TextStyle(color: kPrimary, fontSize: 13)),
                if (_semestre != null) ...[
                  const SizedBox(width: 8),
                  Text('· Semestre $_semestre',
                      style: const TextStyle(color: Colors.black54, fontSize: 13)),
                ],
              ]),
            ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _celCtrl,
            keyboardType: TextInputType.phone,
            decoration: _deco('Celular *', Icons.phone_outlined),
            validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
          ),
        ],

        const SizedBox(height: 20),
        _seccion('Actividad'),
        const SizedBox(height: 8),

        // Fecha selector
        FormField<DateTime>(
          initialValue: _fechaActividad,
          validator: (_) => _fechaActividad == null ? 'Selecciona la fecha' : null,
          builder: (state) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InkWell(
              onTap: _seleccionarFecha,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
                decoration: BoxDecoration(
                  border: Border.all(color: state.hasError ? Colors.red : const Color(0xFFAAAAAA)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(children: [
                  Icon(Icons.calendar_today_outlined, color: kPrimary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _fechaActividad != null
                        ? '${_fechaActividad!.day.toString().padLeft(2,'0')}/${_fechaActividad!.month.toString().padLeft(2,'0')}/${_fechaActividad!.year}'
                        : 'Fecha de la actividad *',
                    style: TextStyle(
                      color: _fechaActividad != null ? Colors.black87 : Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ]),
              ),
            ),
            if (state.hasError)
              Padding(padding: const EdgeInsets.only(top: 4, left: 12),
                  child: Text(state.errorText!,
                      style: const TextStyle(color: Colors.red, fontSize: 12))),
          ]),
        ),
        const SizedBox(height: 10),

        TextFormField(
          controller: _durCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: _deco('Duración (horas) *', Icons.timer_outlined),
          validator: (v) {
            final d = double.tryParse(v ?? '');
            if (d == null || d <= 0) return 'Ingresa la duración en horas (ej: 2.5)';
            return null;
          },
        ),
        const SizedBox(height: 10),

        TextFormField(
          controller: _descCtrl,
          maxLines: 3,
          decoration: _deco('Descripción de actividades *', Icons.notes_outlined),
          validator: (v) => v!.trim().isEmpty ? 'Describe las actividades realizadas' : null,
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (_enviando || _cargando || _monitores.isEmpty) ? null : _enviar,
            icon: _enviando
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_outlined),
            label: const Text('Registrar actividad'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ),
      ]),
    ),
  );

  Widget _seccion(String title) => Text(title,
      style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimary, fontSize: 14));

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: kPrimary, size: 18),
    border: const OutlineInputBorder(),
    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: kPrimary)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    isDense: true,
  );
}
