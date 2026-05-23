import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api/api_client.dart';
import '../core/theme/colors.dart';
import '../providers/auth_provider.dart';

class MiPerfilScreen extends StatefulWidget {
  const MiPerfilScreen({super.key});

  @override
  State<MiPerfilScreen> createState() => _MiPerfilScreenState();
}

class _MiPerfilScreenState extends State<MiPerfilScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _telefonoCtrl  = TextEditingController();
  final _semestreCtrl  = TextEditingController();

  String? _programaSeleccionado; // UUID
  List<Map<String, dynamic>> _programas = [];

  bool _loading    = true;
  bool _guardando  = false;
  String? _rol;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    _semestreCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final dio  = ApiClient.instance.authenticatedDio(auth.token);

    try {
      final results = await Future.wait([
        dio.get('usuarios/perfil/'),
        dio.get('academico/programas/'),
      ]);

      final perfil   = results[0].data as Map<String, dynamic>;
      final progData = results[1].data;
      final programas = List<Map<String, dynamic>>.from(
        progData is List ? progData : (progData['results'] ?? []),
      );

      final p = perfil['perfil'] as Map<String, dynamic>? ?? {};

      setState(() {
        _firstNameCtrl.text   = perfil['first_name'] ?? '';
        _lastNameCtrl.text    = perfil['last_name']  ?? '';
        _emailCtrl.text       = perfil['email']      ?? '';
        _telefonoCtrl.text    = p['telefono']         ?? '';
        _semestreCtrl.text    = (p['semestre'] ?? '').toString();
        _programaSeleccionado = p['programa'] as String?;
        _rol                  = p['rol'] as String?;
        _programas            = programas;
        _loading              = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar perfil: $e'),
            backgroundColor: kDanger,
          ),
        );
      }
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final auth = context.read<AuthProvider>();
    final dio  = ApiClient.instance.authenticatedDio(auth.token);

    final data = <String, dynamic>{
      'first_name': _firstNameCtrl.text.trim(),
      'last_name':  _lastNameCtrl.text.trim(),
      'email':      _emailCtrl.text.trim(),
      'telefono':   _telefonoCtrl.text.trim(),
    };

    if (_programaSeleccionado != null) {
      data['programa'] = _programaSeleccionado;
    }

    final semestreText = _semestreCtrl.text.trim();
    if (semestreText.isNotEmpty) {
      data['semestre'] = int.tryParse(semestreText);
    }

    try {
      await dio.patch('usuarios/perfil/', data: data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil actualizado correctamente'),
            backgroundColor: kSuccess,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: kDanger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'Mi Perfil',
          style: TextStyle(color: kPrimary, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: kPrimary),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar + username
                        Center(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 36,
                                backgroundColor: kPrimary.withValues(alpha: 0.15),
                                child: const Icon(
                                  Icons.person,
                                  size: 40,
                                  color: kPrimary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (_rol != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: kPrimary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _rol!,
                                    style: const TextStyle(
                                        color: kPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ── Datos personales ──────────────────────────────
                        _seccionLabel('Datos personales'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _firstNameCtrl,
                                decoration: _inputDec('Nombre', Icons.person_outline),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Requerido'
                                        : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _lastNameCtrl,
                                decoration: _inputDec('Apellido', Icons.person_outline),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Requerido'
                                        : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _inputDec('Correo electrónico', Icons.email_outlined),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Requerido';
                            if (!v.contains('@')) return 'Correo inválido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _telefonoCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: _inputDec('Teléfono / Celular', Icons.phone_outlined),
                        ),
                        const SizedBox(height: 28),

                        // ── Información académica ─────────────────────────
                        _seccionLabel('Información académica'),
                        const SizedBox(height: 12),

                        // Programa
                        DropdownButtonFormField<String>(
                          value: _programaSeleccionado,
                          decoration: _inputDec('Programa académico', Icons.school_outlined),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Sin programa',
                                  style: TextStyle(color: kTextMuted)),
                            ),
                            ..._programas.map((p) => DropdownMenuItem<String>(
                              value: p['id'].toString(),
                              child: Text(
                                p['nombre'] as String? ?? p['id'].toString(),
                                overflow: TextOverflow.ellipsis,
                              ),
                            )),
                          ],
                          onChanged: (v) => setState(() => _programaSeleccionado = v),
                        ),
                        const SizedBox(height: 14),

                        // Semestre (solo relevante para monitores, pero visible para todos)
                        TextFormField(
                          controller: _semestreCtrl,
                          keyboardType: TextInputType.number,
                          decoration: _inputDec('Semestre (1–10)', Icons.format_list_numbered_outlined),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final n = int.tryParse(v.trim());
                            if (n == null || n < 1 || n > 10) {
                              return 'Semestre debe ser entre 1 y 10';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),

                        // ── Botón guardar ─────────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton.icon(
                            onPressed: _guardando ? null : _guardar,
                            icon: _guardando
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.save_outlined, size: 18),
                            label: Text(
                              _guardando ? 'Guardando...' : 'Guardar cambios',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _seccionLabel(String texto) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          texto,
          style: const TextStyle(
              color: kPrimary, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const Divider(height: 8),
      ],
    );
  }

  InputDecoration _inputDec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18, color: kPrimary),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kPrimary, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: Colors.white,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog reutilizable para editar el perfil de OTRO usuario (desde permisos)
// ─────────────────────────────────────────────────────────────────────────────

class EditarPerfilUsuarioDialog extends StatefulWidget {
  final Map<String, dynamic> usuario;
  const EditarPerfilUsuarioDialog({super.key, required this.usuario});

  @override
  State<EditarPerfilUsuarioDialog> createState() =>
      _EditarPerfilUsuarioDialogState();
}

class _EditarPerfilUsuarioDialogState
    extends State<EditarPerfilUsuarioDialog> {
  final _formKey     = GlobalKey<FormState>();
  final _firstCtrl   = TextEditingController();
  final _lastCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _telCtrl     = TextEditingController();
  final _semCtrl     = TextEditingController();

  String? _programaSeleccionado;
  List<Map<String, dynamic>> _programas = [];
  bool _cargandoProgramas = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final u = widget.usuario;
    final p = u['perfil'] as Map<String, dynamic>? ?? {};
    _firstCtrl.text  = u['first_name'] ?? '';
    _lastCtrl.text   = u['last_name']  ?? '';
    _emailCtrl.text  = u['email']      ?? '';
    _telCtrl.text    = p['telefono']   ?? '';
    _semCtrl.text    = (p['semestre'] ?? '').toString();
    _programaSeleccionado = p['programa'] as String?;
    _cargarProgramas();
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _emailCtrl.dispose();
    _telCtrl.dispose();
    _semCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarProgramas() async {
    final auth = context.read<AuthProvider>();
    final dio  = ApiClient.instance.authenticatedDio(auth.token);
    try {
      final resp  = await dio.get('academico/programas/');
      final data  = resp.data;
      final lista = List<Map<String, dynamic>>.from(
          data is List ? data : (data['results'] ?? []));
      setState(() { _programas = lista; _cargandoProgramas = false; });
    } catch (_) {
      setState(() => _cargandoProgramas = false);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final auth = context.read<AuthProvider>();
    final dio  = ApiClient.instance.authenticatedDio(auth.token);
    final uid  = widget.usuario['id'];

    final data = <String, dynamic>{
      'first_name': _firstCtrl.text.trim(),
      'last_name':  _lastCtrl.text.trim(),
      'email':      _emailCtrl.text.trim(),
      'telefono':   _telCtrl.text.trim(),
    };
    if (_programaSeleccionado != null) data['programa'] = _programaSeleccionado;
    final semText = _semCtrl.text.trim();
    if (semText.isNotEmpty) data['semestre'] = int.tryParse(semText);

    try {
      await dio.patch('usuarios/perfil/$uid/', data: data);
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil actualizado'),
            backgroundColor: kSuccess,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: kDanger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  InputDecoration _inputDec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18, color: kPrimary),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kPrimary, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombre = '${widget.usuario['first_name'] ?? ''} '
        '${widget.usuario['last_name'] ?? ''}'.trim();
    final username = widget.usuario['username'] as String? ?? '';

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.edit_outlined, color: kPrimary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Editar perfil — ${nombre.isEmpty ? username : nombre}',
              style: const TextStyle(fontSize: 15, color: kPrimary),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: _cargandoProgramas
            ? const SizedBox(
                height: 100,
                child: Center(
                    child: CircularProgressIndicator(color: kPrimary)))
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _firstCtrl,
                              decoration:
                                  _inputDec('Nombre', Icons.person_outline),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Requerido'
                                      : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _lastCtrl,
                              decoration:
                                  _inputDec('Apellido', Icons.person_outline),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Requerido'
                                      : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration:
                            _inputDec('Correo', Icons.email_outlined),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Requerido';
                          if (!v.contains('@')) return 'Correo inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _telCtrl,
                        keyboardType: TextInputType.phone,
                        decoration:
                            _inputDec('Teléfono', Icons.phone_outlined),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _programaSeleccionado,
                        decoration: _inputDec(
                            'Programa', Icons.school_outlined),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Sin programa',
                                style: TextStyle(color: kTextMuted)),
                          ),
                          ..._programas.map((p) => DropdownMenuItem<String>(
                            value: p['id'].toString(),
                            child: Text(
                              p['nombre'] as String? ?? p['id'].toString(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                        ],
                        onChanged: (v) =>
                            setState(() => _programaSeleccionado = v),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _semCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            _inputDec('Semestre (1–10)', Icons.format_list_numbered_outlined),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final n = int.tryParse(v.trim());
                          if (n == null || n < 1 || n > 10) {
                            return 'Entre 1 y 10';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar', style: TextStyle(color: kTextMuted)),
        ),
        ElevatedButton.icon(
          onPressed: _guardando ? null : _guardar,
          icon: _guardando
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.save_outlined, size: 16),
          label: Text(_guardando ? 'Guardando...' : 'Guardar'),
        ),
      ],
    );
  }
}
