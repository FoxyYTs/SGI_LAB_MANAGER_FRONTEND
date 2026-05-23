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
  final _formKey = GlobalKey<FormState>();
  final _obsCtrl = TextEditingController();

  List<Map<String, dynamic>> _monitores = [];
  Map<String, dynamic>? _monitorSel;
  String _tipo = 'ENTRADA';
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
    _obsCtrl.dispose();
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

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);
    try {
      await _dio.post('academico/registro-horas/', data: {
        'nombre_monitor': _monitorSel!['nombre'],
        'nit_monitor':    _monitorSel!['nit'] ?? '',
        'tipo':           _tipo,
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
          'Registro de Horas',
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
          Text(
            _tipo == 'ENTRADA' ? '¡Entrada registrada!' : '¡Salida registrada!',
            style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: kPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            _monitorSel!['nombre'],
            style: const TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary, foregroundColor: Colors.white),
            onPressed: () => setState(() {
              _enviado    = false;
              _monitorSel = null;
              _tipo       = 'ENTRADA';
              _obsCtrl.clear();
            }),
            child: const Text('Nuevo registro'),
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
            'Registra tu entrada o salida del laboratorio.',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 20),

          _seccion('Monitor / Laboratorista'),
          const SizedBox(height: 8),

          if (_cargando)
            const Center(child: CircularProgressIndicator(color: kPrimary))
          else if (_monitores.isEmpty)
            const Text(
              'No se pudieron cargar los monitores. Verifica la conexión.',
              style: TextStyle(color: Colors.red),
            )
          else
            FormField<Map<String, dynamic>>(
              initialValue: _monitorSel,
              validator: (_) => _monitorSel == null ? 'Selecciona tu nombre' : null,
              builder: (state) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: _monitorSel,
                    decoration: _deco('Selecciona tu nombre *', Icons.person_outline),
                    items: _monitores.map((m) => DropdownMenuItem(
                      value: m,
                      child: Text(m['nombre']?.toString() ?? ''),
                    )).toList(),
                    onChanged: (v) => setState(() {
                      _monitorSel = v;
                      state.didChange(v);
                    }),
                    validator: (_) => _monitorSel == null ? 'Selecciona tu nombre' : null,
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),
          _seccion('Tipo de registro'),
          const SizedBox(height: 8),

          Row(children: [
            Expanded(
              child: _TipoCard(
                label: 'Entrada',
                icon: Icons.login,
                selected: _tipo == 'ENTRADA',
                color: kSuccess,
                onTap: () => setState(() => _tipo = 'ENTRADA'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TipoCard(
                label: 'Salida',
                icon: Icons.logout,
                selected: _tipo == 'SALIDA',
                color: kDanger,
                onTap: () => setState(() => _tipo = 'SALIDA'),
              ),
            ),
          ]),

          const SizedBox(height: 16),
          TextFormField(
            controller: _obsCtrl,
            maxLines: 2,
            decoration: _deco('Observaciones (opcional)', Icons.notes_outlined),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_enviando || _cargando || _monitores.isEmpty) ? null : _enviar,
              icon: _enviando
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_outlined),
              label: const Text('Registrar'),
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

class _TipoCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TipoCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? color : Colors.grey.shade300, width: 2),
          color: selected ? color.withValues(alpha: 0.08) : Colors.white,
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : Colors.grey, size: 32),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: selected ? color : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
