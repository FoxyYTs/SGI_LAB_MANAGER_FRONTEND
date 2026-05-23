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
  final _formKey    = GlobalKey<FormState>();
  final _docenteCtrl  = TextEditingController();
  final _grupoCtrl    = TextEditingController();
  final _estudCtrl    = TextEditingController(text: '0');
  final _obsCtrl      = TextEditingController();

  List<Map<String, dynamic>> _asignaturas = [];
  List<Map<String, dynamic>> _guias       = [];
  Map<String, dynamic>? _asignaturaSel;
  Map<String, dynamic>? _guiaSel;
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
    _docenteCtrl.dispose();
    _grupoCtrl.dispose();
    _estudCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final r = await _dio.get('academico/asignaturas-publico/');
      setState(() {
        _asignaturas = List<Map<String, dynamic>>.from(r.data);
        _cargando    = false;
      });
    } catch (_) {
      setState(() => _cargando = false);
    }
  }

  Future<void> _cargarGuias(String asignaturaId) async {
    setState(() { _cargGuias = true; _guias = []; _guiaSel = null; });
    try {
      final r = await _dio.get('academico/guias-publico/', queryParameters: {'asignatura': asignaturaId});
      setState(() => _guias = List<Map<String, dynamic>>.from(r.data));
    } catch (_) {}
    if (mounted) setState(() => _cargGuias = false);
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);
    try {
      await _dio.post('academico/registro-practica/', data: {
        'nombre_docente': _docenteCtrl.text.trim(),
        'asignatura':     _asignaturaSel!['id'],
        'guia':           _guiaSel?['id'],
        'grupo':          _grupoCtrl.text.trim(),
        'n_estudiantes':  int.tryParse(_estudCtrl.text) ?? 0,
        'observaciones':  _obsCtrl.text.trim(),
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
        title: const Text(
          'Registro de Práctica',
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
          const Icon(Icons.science_outlined, size: 80, color: kSuccess),
          const SizedBox(height: 16),
          const Text(
            '¡Práctica registrada!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            _asignaturaSel?['nombre'] ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary, foregroundColor: Colors.white),
            onPressed: () => setState(() {
              _enviado = false;
              _docenteCtrl.clear();
              _grupoCtrl.clear();
              _estudCtrl.text = '0';
              _obsCtrl.clear();
              _asignaturaSel = null;
              _guiaSel       = null;
              _guias         = [];
            }),
            child: const Text('Nueva práctica'),
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
            'Registra la práctica que estás realizando hoy.',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 20),

          _seccion('Docente'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _docenteCtrl,
            decoration: _deco('Nombre del docente *', Icons.person_outline),
            validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 16),

          _seccion('Asignatura y guía'),
          const SizedBox(height: 8),
          if (_cargando)
            const Center(child: CircularProgressIndicator(color: kPrimary))
          else if (_asignaturas.isEmpty)
            const Text(
              'No se pudieron cargar las asignaturas.',
              style: TextStyle(color: Colors.red),
            )
          else ...[
            DropdownButtonFormField<Map<String, dynamic>>(
              value: _asignaturaSel,
              decoration: _deco('Asignatura *', Icons.school_outlined),
              items: _asignaturas.map((a) => DropdownMenuItem(
                value: a,
                child: Text('${a['nombre']} (${a['area']})'),
              )).toList(),
              onChanged: (v) {
                setState(() { _asignaturaSel = v; _guiaSel = null; });
                if (v != null) _cargarGuias(v['id'].toString());
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
                decoration: _deco('Guía (opcional)', Icons.menu_book_outlined),
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

          const SizedBox(height: 16),
          _seccion('Grupo y estudiantes'),
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
                decoration: _deco('N° Estudiantes', Icons.people_outline),
                validator: (v) =>
                    (int.tryParse(v ?? '') ?? -1) < 0 ? 'Inválido' : null,
              ),
            ),
          ]),

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
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_outlined),
              label: const Text('Registrar práctica'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
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
