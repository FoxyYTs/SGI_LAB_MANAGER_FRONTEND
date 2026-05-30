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
    } on DioException catch (e) {
      final String msg;
      if (e.response?.statusCode == 429) {
        msg = 'Se excedió la cantidad de registros que puedes hacer por hora. Por favor, intenta más tarde.';
      } else {
        final data = e.response?.data;
        if (data is Map && data.isNotEmpty) {
          msg = data.values.first.toString();
        } else {
          msg = 'Error al registrar. Intenta de nuevo.';
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
        child: const Icon(Icons.access_time_outlined, color: Colors.white, size: 32),
      ),
      const SizedBox(height: 12),
      const Text(
        'Registro de Horas Monitor',
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
        const Text('¡Actividad registrada!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kPrimary)),
        const SizedBox(height: 8),
        Text(_monitorSel!['nombre']?.toString() ?? '',
            style: const TextStyle(fontSize: 16, color: Colors.black54)),
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
            'Registra las actividades realizadas durante tu turno en el laboratorio.',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 20),

          _seccionLabel('Monitor'),
          if (_cargando)
            const Center(child: CircularProgressIndicator(color: kPrimary))
          else if (_monitores.isEmpty)
            const Text('No se pudieron cargar los monitores.',
                style: TextStyle(color: kDanger))
          else
            DropdownButtonFormField<Map<String, dynamic>>(
              initialValue: _monitorSel,
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
          _seccionLabel('Actividad'),

          // Fecha selector
          FormField<DateTime>(
            initialValue: _fechaActividad,
            validator: (_) => _fechaActividad == null ? 'Selecciona la fecha' : null,
            builder: (state) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              InkWell(
                onTap: _seleccionarFecha,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    border: Border.all(
                        color: state.hasError ? kDanger : const Color(0xFFDEE2E6)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_outlined, color: kPrimary, size: 18),
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
                        style: const TextStyle(color: kDanger, fontSize: 12))),
            ]),
          ),
          const SizedBox(height: 12),

          if (wide) ...[
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: TextFormField(
                controller: _durCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _deco('Duración (horas) *', Icons.timer_outlined),
                validator: (v) {
                  final d = double.tryParse(v ?? '');
                  if (d == null || d <= 0) return 'Ingresa la duración en horas (ej: 2.5)';
                  return null;
                },
              )),
              const SizedBox(width: 16),
              const Expanded(child: SizedBox.shrink()),
            ]),
            const SizedBox(height: 12),
          ] else ...[
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
            const SizedBox(height: 12),
          ],

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
              label: const Text('Registrar horas',
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
}
