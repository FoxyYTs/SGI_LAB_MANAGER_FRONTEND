import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api/api_client.dart';
import '../core/theme/colors.dart';
import '../core/permissions.dart';
import '../providers/auth_provider.dart';
import 'mi_perfil_screen.dart';

class PermisosScreen extends StatefulWidget {
  const PermisosScreen({super.key});

  @override
  State<PermisosScreen> createState() => _PermisosScreenState();
}

class _PermisosScreenState extends State<PermisosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Gestión de permisos',
            style: TextStyle(color: kPrimary, fontWeight: FontWeight.bold)),
        elevation: 1,
        bottom: TabBar(
          controller: _tab,
          labelColor: kPrimary,
          unselectedLabelColor: kTextMuted,
          indicatorColor: kPrimary,
          tabs: const [
            Tab(icon: Icon(Icons.groups_outlined),      text: 'Por rol'),
            Tab(icon: Icon(Icons.person_outline),        text: 'Por usuario'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _PermisosPorRol(),
          _PermisosPorUsuario(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Tab: Permisos por rol
// ─────────────────────────────────────────
class _PermisosPorRol extends StatefulWidget {
  const _PermisosPorRol();

  @override
  State<_PermisosPorRol> createState() => _PermisosPorRolState();
}

class _PermisosPorRolState extends State<_PermisosPorRol> {
  static const _roles = ['ADMIN', 'LAB', 'MONITOR', 'ESTUDIANTE'];

  // { rol: Set<codigo> }
  Map<String, Set<String>> _asignados = {};
  // { codigo: id_PermisoRol } para poder eliminar
  Map<String, Map<String, int>> _ids = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final dio  = ApiClient.instance.authenticatedDio(auth.token);
    try {
      final resp = await dio.get('usuarios/permisos-rol/');
      final d     = resp.data;
      final lista = List<Map<String, dynamic>>.from(d is List ? d : (d['results'] ?? []));

      final Map<String, Set<String>>    asignados = {for (final r in _roles) r: {}};
      final Map<String, Map<String, int>> ids     = {for (final r in _roles) r: {}};

      for (final pr in lista) {
        final rol    = pr['rol']    as String;
        final codigo = pr['codigo'] as String;
        final id     = pr['id']     as int;
        asignados[rol]?.add(codigo);
        ids[rol]?[codigo] = id;
      }
      setState(() { _asignados = asignados; _ids = ids; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggle(String rol, String codigo, bool activo) async {
    final auth = context.read<AuthProvider>();
    final dio  = ApiClient.instance.authenticatedDio(auth.token);
    try {
      if (activo) {
        // Asignar
        final resp = await dio.post('usuarios/permisos-rol/', data: {
          'rol':     rol,
          'permiso': await _idPermiso(codigo, dio),
        });
        setState(() {
          _asignados[rol]!.add(codigo);
          _ids[rol]![codigo] = resp.data['id'];
        });
      } else {
        // Quitar
        final id = _ids[rol]?[codigo];
        if (id != null) {
          await dio.delete('usuarios/permisos-rol/$id/');
          setState(() {
            _asignados[rol]!.remove(codigo);
            _ids[rol]!.remove(codigo);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al actualizar permiso'), backgroundColor: kDanger));
      }
    }
  }

  Future<int> _idPermiso(String codigo, dynamic dio) async {
    final resp = await dio.get('usuarios/todos-permisos/');
    final lista = List<Map<String, dynamic>>.from(resp.data);
    return lista.firstWhere((p) => p['codigo'] == codigo)['id'];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: kPrimary));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ADMIN siempre tiene todos los permisos y no puede modificarse.',
              style: TextStyle(color: kTextMuted, fontSize: 12)),
          const SizedBox(height: 16),
          Card(
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(2.5),
                1: FixedColumnWidth(70),
                2: FixedColumnWidth(70),
                3: FixedColumnWidth(70),
                4: FixedColumnWidth(70),
              },
              children: [
                // Cabecera
                TableRow(
                  decoration: const BoxDecoration(color: kPrimary),
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(10),
                      child: Text('Permiso',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    ..._roles.map((r) => Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(r,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    )),
                  ],
                ),
                // Filas de permisos
                ...Perm.todos.map((codigo) => TableRow(
                  decoration: BoxDecoration(
                    color: Perm.todos.indexOf(codigo).isEven
                        ? Colors.white
                        : const Color(0xFFF8F9FA),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(Perm.nombre(codigo),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          Text(codigo,
                              style: const TextStyle(fontSize: 10, color: kTextMuted)),
                        ],
                      ),
                    ),
                    ..._roles.map((rol) {
                      final esAdmin   = rol == 'ADMIN';
                      final tienePermiso = esAdmin || (_asignados[rol]?.contains(codigo) ?? false);
                      return Padding(
                        padding: const EdgeInsets.all(4),
                        child: Checkbox(
                          value: tienePermiso,
                          activeColor: kPrimary,
                          // ADMIN siempre marcado y no editable
                          onChanged: esAdmin
                              ? null
                              : (v) => _toggle(rol, codigo, v!),
                        ),
                      );
                    }),
                  ],
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Tab: Permisos extra por usuario
// ─────────────────────────────────────────
class _PermisosPorUsuario extends StatefulWidget {
  const _PermisosPorUsuario();

  @override
  State<_PermisosPorUsuario> createState() => _PermisosPorUsuarioState();
}

class _PermisosPorUsuarioState extends State<_PermisosPorUsuario> {
  static const _rolesDisponibles = ['ADMIN', 'LAB', 'MONITOR', 'ESTUDIANTE'];

  List<Map<String, dynamic>> _usuarios = [];
  Map<String, dynamic>?      _seleccionado;
  Set<String>                _rolPermisos   = {};
  Set<String>                _extraPermisos = {};
  // codigo → id del PermisoUsuario
  Map<String, int>           _extraIds      = {};
  bool _loadingUsuarios = true;
  bool _loadingPermisos = false;
  bool _cambiandoRol    = false;
  bool _toggling        = false;

  final TextEditingController _busquedaCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
    _busquedaCtrl.addListener(() => setState(() => _query = _busquedaCtrl.text.toLowerCase()));
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _usuariosFiltrados {
    if (_query.isEmpty) return _usuarios;
    return _usuarios.where((u) {
      final username = (u['username'] as String? ?? '').toLowerCase();
      final email    = (u['email']    as String? ?? '').toLowerCase();
      final nombre   = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.toLowerCase();
      return username.contains(_query) || email.contains(_query) || nombre.contains(_query);
    }).toList();
  }

  Future<void> _cargarUsuarios() async {
    final auth = context.read<AuthProvider>();
    final dio  = ApiClient.instance.authenticatedDio(auth.token);
    try {
      final resp = await dio.get('usuarios/lista/');
      setState(() {
        _usuarios        = List<Map<String, dynamic>>.from(resp.data);
        _loadingUsuarios = false;
      });
    } catch (_) {
      setState(() => _loadingUsuarios = false);
    }
  }

  Future<void> _cargarPermisosUsuario(Map<String, dynamic> usuario) async {
    setState(() { _seleccionado = usuario; _loadingPermisos = true; });
    final auth = context.read<AuthProvider>();
    final dio  = ApiClient.instance.authenticatedDio(auth.token);

    final rol = (usuario['perfil']?['rol'] ?? '') as String;

    try {
      final results = await Future.wait([
        dio.get('usuarios/permisos-rol/?rol=$rol'),
        dio.get('usuarios/permisos-usuario/?user=${usuario['id']}'),
      ]);

      List<Map<String, dynamic>> _parse(dynamic d) =>
          List<Map<String, dynamic>>.from(d is List ? d : (d['results'] ?? []));
      final rolList   = _parse(results[0].data);
      final userList  = _parse(results[1].data);

      setState(() {
        _rolPermisos   = Set<String>.from(rolList.map((p) => p['codigo']));
        _extraPermisos = Set<String>.from(userList.map((p) => p['codigo']));
        _extraIds      = {for (final p in userList) p['codigo'] as String: p['id'] as int};
        _loadingPermisos = false;
      });
    } catch (_) {
      setState(() => _loadingPermisos = false);
    }
  }

  Future<void> _cambiarRol(String nuevoRol) async {
    final auth = context.read<AuthProvider>();
    final dio  = ApiClient.instance.authenticatedDio(auth.token);
    setState(() => _cambiandoRol = true);
    try {
      await dio.patch('usuarios/rol/${_seleccionado!['id']}/', data: {'rol': nuevoRol});
      // Actualizar el mapa local del usuario seleccionado
      setState(() {
        _seleccionado = {
          ..._seleccionado!,
          'perfil': {
            ...(_seleccionado!['perfil'] as Map? ?? {}),
            'rol': nuevoRol,
          },
        };
        // Actualizar también en la lista lateral
        final idx = _usuarios.indexWhere((u) => u['id'] == _seleccionado!['id']);
        if (idx != -1) {
          _usuarios[idx] = _seleccionado!;
        }
      });
      // Recargar los permisos del rol nuevo
      await _cargarPermisosUsuario(_seleccionado!);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al cambiar el rol'), backgroundColor: kDanger));
      }
    } finally {
      if (mounted) setState(() => _cambiandoRol = false);
    }
  }

  Future<void> _toggleActivo(Map<String, dynamic> usuario) async {
    final esActivo  = usuario['is_active'] as bool? ?? true;
    final username  = usuario['username'] as String? ?? '';
    final uid       = usuario['id'];

    // Confirmación solo al desactivar
    if (esActivo) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Desactivar cuenta'),
          content: Text(
              '¿Seguro que deseas desactivar la cuenta de "$username"?\n'
              'El usuario no podrá iniciar sesión.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar', style: TextStyle(color: kTextMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kDanger),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Desactivar'),
            ),
          ],
        ),
      );
      if (confirmar != true) return;
    }

    if (!mounted) return;
    setState(() => _toggling = true);
    final auth = context.read<AuthProvider>();
    final dio  = ApiClient.instance.authenticatedDio(auth.token);
    try {
      final resp = await dio.patch('usuarios/toggle-activo/$uid/');
      final nuevoEstado = resp.data['is_active'] as bool;
      final mensaje     = resp.data['mensaje'] as String? ?? '';

      setState(() {
        final idx = _usuarios.indexWhere((u) => u['id'] == uid);
        if (idx != -1) {
          _usuarios[idx] = {..._usuarios[idx], 'is_active': nuevoEstado};
        }
        if (_seleccionado?['id'] == uid) {
          _seleccionado = {..._seleccionado!, 'is_active': nuevoEstado};
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(mensaje.isNotEmpty ? mensaje : 'Estado actualizado'),
          backgroundColor: nuevoEstado ? kSuccess : kDanger,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Error al cambiar estado'),
                backgroundColor: kDanger));
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _abrirEditarPerfil(Map<String, dynamic> usuario) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditarPerfilUsuarioDialog(usuario: usuario),
    );
    // Recargar lista para reflejar cambios de nombre
    await _cargarUsuarios();
    if (_seleccionado != null) {
      final uid = _seleccionado!['id'];
      final actualizado = _usuarios.firstWhere(
          (u) => u['id'] == uid,
          orElse: () => _seleccionado!);
      if (mounted) setState(() => _seleccionado = actualizado);
    }
  }

  Future<void> _toggleExtra(String codigo, bool activo) async {
    final auth = context.read<AuthProvider>();
    final dio  = ApiClient.instance.authenticatedDio(auth.token);
    try {
      if (activo) {
        // Obtener id del Permiso
        final resp  = await dio.get('usuarios/todos-permisos/');
        final lista = List<Map<String, dynamic>>.from(resp.data);
        final pid   = lista.firstWhere((p) => p['codigo'] == codigo)['id'];
        final r2    = await dio.post('usuarios/permisos-usuario/', data: {
          'user':    _seleccionado!['id'],
          'permiso': pid,
        });
        setState(() {
          _extraPermisos.add(codigo);
          _extraIds[codigo] = r2.data['id'];
        });
      } else {
        final id = _extraIds[codigo];
        if (id != null) {
          await dio.delete('usuarios/permisos-usuario/$id/');
          setState(() {
            _extraPermisos.remove(codigo);
            _extraIds.remove(codigo);
          });
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al actualizar'), backgroundColor: kDanger));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingUsuarios) return const Center(child: CircularProgressIndicator(color: kPrimary));

    return Row(
      children: [
        // Panel izquierdo: lista de usuarios
        Container(
          width: 220,
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: Color(0xFFDEE2E6))),
          ),
          child: Column(
            children: [
              // Barra de búsqueda
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  controller: _busquedaCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Buscar usuario...',
                    hintStyle: const TextStyle(fontSize: 13, color: kTextMuted),
                    prefixIcon: const Icon(Icons.search, size: 18, color: kTextMuted),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16, color: kTextMuted),
                            onPressed: () => _busquedaCtrl.clear(),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                  ),
                ),
              ),
              if (_usuariosFiltrados.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Sin resultados', style: TextStyle(color: kTextMuted, fontSize: 12)),
                )
              else
              Expanded(
                child: ListView.builder(
                  itemCount: _usuariosFiltrados.length,
                  itemBuilder: (_, i) {
                    final u = _usuariosFiltrados[i];
              final seleccionado = _seleccionado?['id'] == u['id'];
              final rol        = u['perfil']?['rol'] ?? '';
              final isActivo   = u['is_active'] as bool? ?? true;
              final auth       = context.read<AuthProvider>();
              final esMiUsuario = auth.username == (u['username'] as String? ?? '');

              return Opacity(
                opacity: isActivo ? 1.0 : 0.5,
                child: ListTile(
                  selected: seleccionado,
                  selectedTileColor: kPrimary.withValues(alpha: 0.08),
                  leading: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        backgroundColor: seleccionado
                            ? kPrimary
                            : kPrimary.withValues(alpha: 0.15),
                        child: Text(
                          (u['username'] as String).substring(0, 1).toUpperCase(),
                          style: TextStyle(
                              color: seleccionado ? Colors.white : kPrimary,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (!isActivo)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: kDanger,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          u['username'],
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (!isActivo)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: kDanger.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Inactivo',
                            style: TextStyle(
                                fontSize: 9,
                                color: kDanger,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(rol,
                      style: const TextStyle(fontSize: 11, color: kTextMuted)),
                  trailing: !esMiUsuario
                      ? PopupMenuButton<String>(
                          iconSize: 18,
                          padding: EdgeInsets.zero,
                          tooltip: 'Acciones',
                          onSelected: (action) {
                            if (action == 'toggle') _toggleActivo(u);
                            if (action == 'editar') _abrirEditarPerfil(u);
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'editar',
                              child: Row(children: [
                                const Icon(Icons.edit_outlined,
                                    size: 16, color: kPrimary),
                                const SizedBox(width: 8),
                                const Text('Editar perfil',
                                    style: TextStyle(fontSize: 13)),
                              ]),
                            ),
                            PopupMenuItem(
                              value: 'toggle',
                              child: Row(children: [
                                Icon(
                                  isActivo
                                      ? Icons.person_off_outlined
                                      : Icons.person_outlined,
                                  size: 16,
                                  color: isActivo ? kDanger : kSuccess,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isActivo ? 'Desactivar' : 'Activar',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: isActivo ? kDanger : kSuccess),
                                ),
                              ]),
                            ),
                          ],
                        )
                      : null,
                  onTap: () => _cargarPermisosUsuario(u),
                ),
              );
            },
                ),
              ),
            ],
          ),
        ),

        // Panel derecho: permisos del usuario seleccionado
        Expanded(
          child: _seleccionado == null
              ? const Center(
                  child: Text('Selecciona un usuario',
                      style: TextStyle(color: kTextMuted)))
              : _loadingPermisos
                  ? const Center(child: CircularProgressIndicator(color: kPrimary))
                  : _buildPermisosPanel(),
        ),
      ],
    );
  }

  Widget _buildPermisosPanel() {
    final auth       = context.watch<AuthProvider>();
    final nombre     = '${_seleccionado!['first_name'] ?? ''} ${_seleccionado!['last_name'] ?? ''}'.trim();
    final username   = _seleccionado!['username'] as String;
    final rol        = (_seleccionado!['perfil']?['rol'] ?? '') as String;
    final esMiUsuario = auth.username == username;
    final isActivo   = _seleccionado!['is_active'] as bool? ?? true;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Encabezado del usuario ──────────────────────────────────────
        Row(children: [
          const Icon(Icons.person_outline, color: kPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(nombre.isEmpty ? username : nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                if (!isActivo) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: kDanger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Inactivo',
                      style: TextStyle(
                          fontSize: 10, color: kDanger, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ]),
              Text('@$username',
                  style: const TextStyle(color: kTextMuted, fontSize: 12)),
            ]),
          ),
          if (!esMiUsuario) ...[
            IconButton(
              tooltip: 'Editar perfil',
              onPressed: () => _abrirEditarPerfil(_seleccionado!),
              icon: const Icon(Icons.edit_outlined, size: 18, color: kPrimary),
            ),
            _toggling
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: kDanger, strokeWidth: 2))
                : IconButton(
                    tooltip: isActivo ? 'Desactivar cuenta' : 'Activar cuenta',
                    onPressed: () => _toggleActivo(_seleccionado!),
                    icon: Icon(
                      isActivo
                          ? Icons.person_off_outlined
                          : Icons.person_outlined,
                      size: 18,
                      color: isActivo ? kDanger : kSuccess,
                    ),
                  ),
          ],
        ]),
        const Divider(height: 24),

        // ── Selector de rol ─────────────────────────────────────────────
        Row(children: [
          const Icon(Icons.badge_outlined, size: 18, color: kPrimary),
          const SizedBox(width: 8),
          const Text('Rol:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          if (_cambiandoRol)
            const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2))
          else if (esMiUsuario)
            Text(rol, style: const TextStyle(color: kTextMuted))
          else
            DropdownButton<String>(
              value: rol.isEmpty ? null : rol,
              underline: const SizedBox.shrink(),
              isDense: true,
              items: _rolesDisponibles.map((r) => DropdownMenuItem(
                value: r,
                child: Text(r, style: const TextStyle(fontSize: 13)),
              )).toList(),
              onChanged: (v) {
                if (v != null && v != rol) _cambiarRol(v);
              },
            ),
          if (esMiUsuario) ...[
            const SizedBox(width: 8),
            const Text('(tu cuenta)', style: TextStyle(fontSize: 11, color: kTextMuted)),
          ],
        ]),
        const SizedBox(height: 16),

        // ── Permisos del rol ────────────────────────────────────────────
        const Text('Permisos del rol (solo lectura)',
            style: TextStyle(fontSize: 12, color: kTextMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...Perm.todos.where((c) => _rolPermisos.contains(c)).map((c) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            const Icon(Icons.check_circle, color: kSuccess, size: 16),
            const SizedBox(width: 8),
            Text(Perm.nombre(c), style: const TextStyle(fontSize: 13)),
          ]),
        )),
        const SizedBox(height: 20),

        // ── Permisos extra ──────────────────────────────────────────────
        const Text('Permisos adicionales (editables)',
            style: TextStyle(fontSize: 12, color: kPrimary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text('Estos permisos se suman a los del rol.',
            style: TextStyle(fontSize: 11, color: kTextMuted)),
        const SizedBox(height: 8),
        ...Perm.todos.map((codigo) {
          final delRol = _rolPermisos.contains(codigo);
          final extra  = _extraPermisos.contains(codigo);
          return CheckboxListTile(
            value: extra,
            dense: true,
            activeColor: kPrimary,
            subtitle: delRol
                ? const Text('Ya incluido en el rol',
                    style: TextStyle(fontSize: 10, color: kTextMuted))
                : null,
            title: Text(Perm.nombre(codigo), style: const TextStyle(fontSize: 13)),
            secondary: Text(codigo, style: const TextStyle(fontSize: 10, color: kTextMuted)),
            onChanged: delRol ? null : (v) => _toggleExtra(codigo, v!),
          );
        }),
      ],
    );
  }
}
