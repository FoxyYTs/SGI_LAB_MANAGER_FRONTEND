import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/api/api_client.dart';
import '../core/theme/colors.dart';

class RegistroPracticaScreen extends StatefulWidget {
  const RegistroPracticaScreen({super.key});

  @override
  State<RegistroPracticaScreen> createState() => _RegistroPracticaScreenState();
}

class _RegistroPracticaScreenState extends State<RegistroPracticaScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _celDocenteCtrl = TextEditingController();
  final _practCtrl      = TextEditingController();
  final _necesCtrl      = TextEditingController();
  final _grupoCtrl      = TextEditingController();
  final _estudCtrl      = TextEditingController(text: '0');
  final _obsCtrl        = TextEditingController();

  List<Map<String, dynamic>> _docentes    = [];
  List<Map<String, dynamic>> _programas   = [];
  List<Map<String, dynamic>> _asignaturas = [];
  List<Map<String, dynamic>> _guias       = [];

  Map<String, dynamic>? _docenteSel;
  Map<String, dynamic>? _programaSel;
  Map<String, dynamic>? _asignaturaSel;
  Map<String, dynamic>? _guiaSel;

  DateTime? _fechaPractica;
  TimeOfDay? _horaIngreso;
  TimeOfDay? _horaSalida;

  bool _cargando  = true;
  bool _enviando  = false;
  bool _enviado   = false;
  bool _cargGuias = false;

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
    _celDocenteCtrl.dispose();
    _practCtrl.dispose();
    _necesCtrl.dispose();
    _grupoCtrl.dispose();
    _estudCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final results = await Future.wait([
        _dio.get('academico/docentes-publico/'),
        _dio.get('academico/programas-publico/'),
        _dio.get('academico/asignaturas-publico/'),
      ]);
      setState(() {
        _docentes    = List<Map<String, dynamic>>.from(results[0].data);
        _programas   = List<Map<String, dynamic>>.from(results[1].data);
        _asignaturas = List<Map<String, dynamic>>.from(results[2].data);
        _cargando    = false;
      });
    } catch (_) {
      setState(() => _cargando = false);
    }
  }

  Future<void> _cargarGuias(String asignaturaId) async {
    setState(() { _cargGuias = true; _guias = []; _guiaSel = null; });
    try {
      final r = await _dio.get('academico/guias-publico/',
          queryParameters: {'asignatura': asignaturaId});
      setState(() => _guias = List<Map<String, dynamic>>.from(r.data));
    } catch (_) {}
    if (mounted) setState(() => _cargGuias = false);
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaPractica ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: kPrimary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _fechaPractica = picked);
  }

  Future<void> _seleccionarHora(bool esIngreso) async {
    final initial = esIngreso
        ? (_horaIngreso ?? const TimeOfDay(hour: 7, minute: 0))
        : (_horaSalida ?? const TimeOfDay(hour: 8, minute: 0));
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: kPrimary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() {
      if (esIngreso) _horaIngreso = picked; else _horaSalida = picked;
    });
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);
    try {
      await _dio.post('academico/registro-practica/', data: {
        'docente':          _docenteSel?['id'],
        'nombre_docente':   _docenteSel?['nombre_completo'] ?? '',
        'celular_docente':  _celDocenteCtrl.text.trim(),
        'programa':         _programaSel?['id'],
        'asignatura':       _asignaturaSel!['id'],
        'guia':             _guiaSel?['id'],
        'nombre_practica':  _practCtrl.text.trim(),
        'necesidades':      _necesCtrl.text.trim(),
        'grupo':            _grupoCtrl.text.trim(),
        'n_estudiantes':    int.tryParse(_estudCtrl.text) ?? 0,
        'fecha_practica':   _fechaPractica != null ? _isoDate(_fechaPractica!) : null,
        'hora_ingreso':     _horaIngreso != null ? '${_formatTime(_horaIngreso!)}:00' : null,
        'hora_salida':      _horaSalida != null ? '${_formatTime(_horaSalida!)}:00' : null,
        'observaciones':    _obsCtrl.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: kPrimary,
        title: const Text('Registro de Práctica',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _enviado ? _buildConfirmacion() : _buildForm(),
    );
  }

  Widget _buildConfirmacion() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.science_outlined, size: 80, color: kSuccess),
        const SizedBox(height: 16),
        const Text('¡Práctica registrada!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kPrimary)),
        const SizedBox(height: 8),
        Text(_asignaturaSel?['nombre'] ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Colors.black54)),
        const SizedBox(height: 24),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
          onPressed: () => setState(() {
            _enviado     = false;
            _docenteSel  = null;
            _programaSel = null;
            _asignaturaSel = null;
            _guiaSel     = null;
            _fechaPractica = null;
            _horaIngreso = null;
            _horaSalida  = null;
            _guias       = [];
            _celDocenteCtrl.clear();
            _practCtrl.clear();
            _necesCtrl.clear();
            _grupoCtrl.clear();
            _estudCtrl.text = '0';
            _obsCtrl.clear();
          }),
          child: const Text('Nueva práctica'),
        ),
      ]),
    ),
  );

  Widget _buildForm() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Registra la práctica que estás realizando.',
            style: TextStyle(fontSize: 14, color: Colors.black54)),
        const SizedBox(height: 20),

        _seccion('Docente'),
        const SizedBox(height: 8),
        if (_cargando)
          const Center(child: CircularProgressIndicator(color: kPrimary))
        else ...[
          if (_docentes.isNotEmpty)
            DropdownButtonFormField<Map<String, dynamic>>(
              value: _docenteSel,
              decoration: _deco('Docente *', Icons.person_outline),
              items: _docentes.map((d) => DropdownMenuItem(
                value: d,
                child: Text(d['nombre_completo']?.toString() ?? ''),
              )).toList(),
              onChanged: (v) {
                setState(() {
                  _docenteSel = v;
                  _celDocenteCtrl.clear();
                });
              },
              validator: (_) => _docenteSel == null ? 'Selecciona el docente' : null,
            ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _celDocenteCtrl,
            keyboardType: TextInputType.phone,
            decoration: _deco('Celular del docente *', Icons.phone_outlined),
            validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
          ),
        ],
        const SizedBox(height: 16),

        _seccion('Información académica'),
        const SizedBox(height: 8),
        if (!_cargando) ...[
          if (_programas.isNotEmpty)
            DropdownButtonFormField<Map<String, dynamic>>(
              value: _programaSel,
              decoration: _deco('Programa académico *', Icons.school_outlined),
              items: _programas.map((p) => DropdownMenuItem(
                value: p,
                child: Text(p['nombre']?.toString() ?? '',
                    style: const TextStyle(fontSize: 13)),
              )).toList(),
              onChanged: (v) => setState(() => _programaSel = v),
              validator: (_) => _programaSel == null ? 'Selecciona el programa' : null,
            ),
          const SizedBox(height: 10),

          if (_asignaturas.isNotEmpty)
            DropdownButtonFormField<Map<String, dynamic>>(
              value: _asignaturaSel,
              decoration: _deco('Asignatura *', Icons.menu_book_outlined),
              items: _asignaturas.map((a) => DropdownMenuItem(
                value: a,
                child: Text(a['nombre']?.toString() ?? ''),
              )).toList(),
              onChanged: (v) {
                setState(() { _asignaturaSel = v; _guiaSel = null; });
                if (v != null) { _cargarGuias(v['id'].toString()); }
              },
              validator: (_) => _asignaturaSel == null ? 'Selecciona la asignatura' : null,
            ),
          const SizedBox(height: 10),

          if (_cargGuias)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator(color: kPrimary)),
            )
          else if (_asignaturaSel != null)
            DropdownButtonFormField<Map<String, dynamic>>(
              value: _guiaSel,
              decoration: _deco('Guía (opcional)', Icons.description_outlined),
              items: [
                const DropdownMenuItem(value: null, child: Text('Sin guía específica')),
                ..._guias.map((g) => DropdownMenuItem(
                  value: g,
                  child: Text(g['nombre']?.toString() ?? ''),
                )),
              ],
              onChanged: (v) => setState(() => _guiaSel = v),
            ),
        ],
        const SizedBox(height: 10),

        TextFormField(
          controller: _practCtrl,
          decoration: _deco('Nombre de la práctica *', Icons.science_outlined),
          validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
        ),
        const SizedBox(height: 10),

        TextFormField(
          controller: _necesCtrl,
          maxLines: 2,
          decoration: _deco('Necesidades / materiales requeridos', Icons.checklist_outlined),
        ),
        const SizedBox(height: 16),

        _seccion('Grupo y fecha'),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: _grupoCtrl,
              decoration: _deco('Grupo *', Icons.group_outlined),
              validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: _estudCtrl,
              keyboardType: TextInputType.number,
              decoration: _deco('N° Est.', Icons.people_outline),
              validator: (v) => (int.tryParse(v ?? '') ?? -1) < 0 ? 'Inválido' : null,
            ),
          ),
        ]),
        const SizedBox(height: 10),

        // Fecha
        FormField<DateTime>(
          initialValue: _fechaPractica,
          validator: (_) => _fechaPractica == null ? 'Selecciona la fecha de la práctica' : null,
          builder: (state) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InkWell(
              onTap: _seleccionarFecha,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: state.hasError ? Colors.red : const Color(0xFFAAAAAA)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined, color: kPrimary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _fechaPractica != null
                        ? _formatDate(_fechaPractica!)
                        : 'Fecha de la práctica *',
                    style: TextStyle(
                      color: _fechaPractica != null ? Colors.black87 : Colors.grey,
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

        // Horas ingreso/salida
        Row(children: [
          Expanded(child: _buildTimePicker(
            label: 'Hora ingreso',
            time: _horaIngreso,
            onTap: () => _seleccionarHora(true),
          )),
          const SizedBox(width: 10),
          Expanded(child: _buildTimePicker(
            label: 'Hora salida',
            time: _horaSalida,
            onTap: () => _seleccionarHora(false),
          )),
        ]),
        const SizedBox(height: 10),

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
            label: const Text('Registrar práctica'),
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

  Widget _buildTimePicker({
    required String label,
    required TimeOfDay? time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFAAAAAA)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(children: [
          const Icon(Icons.access_time_outlined, color: kPrimary, size: 18),
          const SizedBox(width: 8),
          Text(
            time != null ? _formatTime(time) : label,
            style: TextStyle(
              color: time != null ? Colors.black87 : Colors.grey,
              fontSize: 14,
            ),
          ),
        ]),
      ),
    );
  }

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
