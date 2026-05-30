import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
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

  String? _programaSeleccionado;
  List<Map<String, dynamic>> _programas = [];

  bool _loading    = true;
  bool _guardando  = false;
  bool _subiendoFoto = false;
  bool _cambiandoPass = false;
  String? _rol;
  String? _fotoUrl;

  // Controladores para cambio de contraseña
  final _passActualCtrl   = TextEditingController();
  final _passNuevaCtrl    = TextEditingController();
  final _passNueva2Ctrl   = TextEditingController();
  bool _verPassActual  = false;
  bool _verPassNueva   = false;
  bool _verPassNueva2  = false;

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
    _passActualCtrl.dispose();
    _passNuevaCtrl.dispose();
    _passNueva2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final dio  = ApiClient.instance.authenticatedDio(auth.token);

    try {
      final results = await Future.wait([
        dio.get('usuarios/perfil/'),
        dio.get('academico/programas-publico/'),
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
        _fotoUrl              = p['foto_url'] as String?;
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

  Future<void> _seleccionarFoto() async {
    final auth = context.read<AuthProvider>();

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    setState(() => _subiendoFoto = true);

    final dio = ApiClient.instance.authenticatedDio(auth.token);

    try {
      final formData = FormData.fromMap({
        'foto': MultipartFile.fromBytes(
          bytes,
          filename: file.name,
        ),
      });
      final resp = await dio.patch('usuarios/perfil/', data: formData);
      final perfil = (resp.data as Map<String, dynamic>)['perfil'] as Map<String, dynamic>? ?? {};
      if (mounted) {
        setState(() => _fotoUrl = perfil['foto_url'] as String?);
      }
      // Actualizar el avatar del topbar fuera del mounted check
      // ignore: use_build_context_synchronously
      if (mounted) await context.read<AuthProvider>().recargarFoto();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto actualizada'),
            backgroundColor: kSuccess,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir foto: $e'),
            backgroundColor: kDanger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }

  Future<void> _cambiarPassword() async {
    final actual  = _passActualCtrl.text.trim();
    final nueva   = _passNuevaCtrl.text.trim();
    final nueva2  = _passNueva2Ctrl.text.trim();

    if (actual.isEmpty || nueva.isEmpty || nueva2.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos de contraseña.'), backgroundColor: kDanger),
      );
      return;
    }
    if (nueva != nueva2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las contraseñas nuevas no coinciden.'), backgroundColor: kDanger),
      );
      return;
    }
    if (nueva.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La contraseña debe tener al menos 8 caracteres.'), backgroundColor: kDanger),
      );
      return;
    }

    setState(() => _cambiandoPass = true);
    final auth = context.read<AuthProvider>();
    final dio  = ApiClient.instance.authenticatedDio(auth.token);
    try {
      await dio.post('usuarios/cambiar-password/', data: {
        'password_actual': actual,
        'nueva_password':  nueva,
        'nueva_password2': nueva2,
      });
      _passActualCtrl.clear();
      _passNuevaCtrl.clear();
      _passNueva2Ctrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contraseña actualizada correctamente.'), backgroundColor: kSuccess),
        );
      }
    } on DioException catch (e) {
      final msg = (e.response?.data as Map?)?['error'] ?? 'Error al cambiar la contraseña.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg.toString()), backgroundColor: kDanger),
        );
      }
    } finally {
      if (mounted) setState(() => _cambiandoPass = false);
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
                              GestureDetector(
                                onTap: _subiendoFoto ? null : _seleccionarFoto,
                                child: Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    CircleAvatar(
                                      radius: 42,
                                      backgroundColor: kPrimary.withValues(alpha: 0.15),
                                      backgroundImage: _fotoUrl != null
                                          ? NetworkImage(_fotoUrl!)
                                          : null,
                                      child: _subiendoFoto
                                          ? const SizedBox(
                                              width: 28,
                                              height: 28,
                                              child: CircularProgressIndicator(
                                                  color: kPrimary, strokeWidth: 2.5),
                                            )
                                          : (_fotoUrl == null
                                              ? const Icon(Icons.person,
                                                  size: 44, color: kPrimary)
                                              : null),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: kPrimary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 2),
                                      ),
                                      padding: const EdgeInsets.all(4),
                                      child: const Icon(Icons.camera_alt,
                                          color: Colors.white, size: 14),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Toca para cambiar foto',
                                style: TextStyle(
                                    fontSize: 11, color: kTextMuted),
                              ),
                              const SizedBox(height: 6),
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
                          // ignore: deprecated_member_use
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

                        // Semestre
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

                        // ── Botón guardar datos ───────────────────────────
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
                        const SizedBox(height: 36),

                        // ── Sección cambio de contraseña ──────────────────
                        _seccionLabel('Cambiar contraseña'),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passActualCtrl,
                          obscureText: !_verPassActual,
                          decoration: _inputDec('Contraseña actual', Icons.lock_outline).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(_verPassActual ? Icons.visibility_off : Icons.visibility, size: 18),
                              onPressed: () => setState(() => _verPassActual = !_verPassActual),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _passNuevaCtrl,
                          obscureText: !_verPassNueva,
                          decoration: _inputDec('Nueva contraseña', Icons.lock_person_outlined).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(_verPassNueva ? Icons.visibility_off : Icons.visibility, size: 18),
                              onPressed: () => setState(() => _verPassNueva = !_verPassNueva),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _passNueva2Ctrl,
                          obscureText: !_verPassNueva2,
                          decoration: _inputDec('Confirmar nueva contraseña', Icons.lock_reset_outlined).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(_verPassNueva2 ? Icons.visibility_off : Icons.visibility, size: 18),
                              onPressed: () => setState(() => _verPassNueva2 = !_verPassNueva2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: OutlinedButton.icon(
                            onPressed: _cambiandoPass ? null : _cambiarPassword,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: kPrimary),
                              foregroundColor: kPrimary,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: _cambiandoPass
                                ? const SizedBox(
                                    width: 18, height: 18,
                                    child: CircularProgressIndicator(
                                        color: kPrimary, strokeWidth: 2),
                                  )
                                : const Icon(Icons.key_outlined, size: 18),
                            label: Text(
                              _cambiandoPass ? 'Actualizando...' : 'Cambiar contraseña',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
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
      final resp  = await dio.get('academico/programas-publico/');
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
                        // ignore: deprecated_member_use
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
