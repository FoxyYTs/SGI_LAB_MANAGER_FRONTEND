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
          LayoutBuilder(builder: (_, box) {
            const double kMin = 470;
            final w = box.maxWidth < kMin ? kMin : box.maxWidth;
            final colRole = box.maxWidth < kMin ? const FixedColumnWidth(76) : const FixedColumnWidth(70);
            Widget tableCard = Card(
              child: Table(
                columnWidths: {
                  0: const FlexColumnWidth(2.5),
                  1: colRole,
                  2: colRole,
                  3: colRole,
                  4: colRole,
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
          );
            if (box.maxWidth >= kMin) return tableCard;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: w, child: tableCard),
            );
          }),
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

    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 600;

      // Mobile: maestro-detalle — una columna a la vez
      if (isMobile && _seleccionado != null) {
        return Column(
          children: [
            // Barra de regreso al listado
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFDEE2E6))),
              ),
              child: ListTile(
                leading: const Icon(Icons.arrow_back, color: kPrimary),
                title: const Text('Volver al listado',
                    style: TextStyle(color: kPrimary, fontSize: 14)),
                onTap: () => setState(() => _seleccionado = null),
              ),
            ),
            Expanded(
              child: _loadingPermisos
                  ? const Center(child: CircularProgressIndicator(color: kPrimary))
                  : _buildPermisosPanel(),
            ),
          ],
        );
      }

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
    }); // LayoutBuilder
  }

  Widget _buildPermisosPanel() {
    final auth        = context.watch<AuthProvider>();
    final nombre      = '${_seleccionado!['first_name'] ?? ''} ${_seleccionado!['last_name'] ?? ''}'.trim();
    final username    = _seleccionado!['username'] as String;
    final email       = _seleccionado!['email'] as String? ?? '';
    final rol         = (_seleccionado!['perfil']?['rol'] ?? '') as String;
    final esMiUsuario = auth.username == username;
    final isActivo    = _seleccionado!['is_active'] as bool? ?? true;
    final esAdmin     = rol == 'ADMIN';
    // Cambiar el rol de un usuario es más sensible que gestionar permisos (puede
    // otorgar ADMIN) — el backend lo restringe solo a ADMIN aunque el usuario
    // actual tenga el permiso 'configuracion.roles'. El dropdown debe reflejar
    // esa misma restricción o el LAB vería un control que siempre falla.
    final puedeCambiarRol = auth.rol == 'ADMIN';
    final iniciales   = (nombre.isEmpty ? username : nombre)
        .split(' ').take(2).map((p) => p.isNotEmpty ? p[0].toUpperCase() : '').join();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Card usuario ──────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(10),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            // Avatar
            CircleAvatar(
              radius: 24, backgroundColor: kPrimary.withValues(alpha: 0.15),
              child: Text(iniciales, style: const TextStyle(
                  color: kPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(width: 14),
            // Nombre + email
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nombre.isEmpty ? username : nombre,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              if (email.isNotEmpty)
                Text(email, style: const TextStyle(color: kTextMuted, fontSize: 12)),
            ])),
            const SizedBox(width: 12),
            // Rol selector
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('ROL ASIGNADO',
                  style: TextStyle(fontSize: 9, color: kTextMuted, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              if (_cambiandoRol)
                const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2))
              else if (esMiUsuario || !puedeCambiarRol)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: kPrimary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(rol, style: const TextStyle(color: kPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFDEE2E6)),
                      borderRadius: BorderRadius.circular(8)),
                  child: DropdownButton<String>(
                    value: rol.isEmpty ? null : rol,
                    underline: const SizedBox.shrink(),
                    isDense: true,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF223542)),
                    items: _rolesDisponibles.map((r) => DropdownMenuItem(
                      value: r,
                      child: Text(r),
                    )).toList(),
                    onChanged: (v) { if (v != null && v != rol) _cambiarRol(v); },
                  ),
                ),
            ]),
            const SizedBox(width: 12),
            // Estado + acciones
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('ESTADO CUENTA',
                  style: TextStyle(fontSize: 9, color: kTextMuted, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                      color: isActivo ? kSemaforoVerde : kDanger,
                      shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text(isActivo ? 'Activo' : 'Inactivo',
                    style: TextStyle(
                        fontSize: 12,
                        color: isActivo ? kSemaforoVerde : kDanger,
                        fontWeight: FontWeight.w600)),
              ]),
            ]),
            if (!esMiUsuario) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _abrirEditarPerfil(_seleccionado!),
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: const Text('Editar perfil', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kPrimary,
                  side: const BorderSide(color: kPrimary),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 16),

        // ── Tabla de permisos ────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(10),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Column(children: [
              // Header azul
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: kPrimary,
                child: Row(children: [
                  Text('Permisos de $username',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const Spacer(),
                  const Text('Los permisos heredados del rol no pueden quitarse individualmente.',
                      style: TextStyle(color: Colors.white70, fontSize: 11)),
                ]),
              ),

              // Banner ADMIN
              if (esAdmin)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: kPrimary.withValues(alpha: 0.08),
                  child: const Row(children: [
                    Icon(Icons.info_outline, color: kPrimary, size: 16),
                    SizedBox(width: 8),
                    Expanded(child: Text(
                      'Este usuario tiene todos los permisos como ADMIN. Los permisos extra no aplican.',
                      style: TextStyle(color: kPrimary, fontSize: 12),
                    )),
                  ]),
                ),

              // Cabecera tabla
              Container(
                color: const Color(0xFFF8F9FA),
                child: const Row(children: [
                  Expanded(child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('PERMISO',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kTextMuted)),
                  )),
                  SizedBox(width: 80, child: Center(child: Text('DE ROL',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kTextMuted)))),
                  SizedBox(width: 80, child: Center(child: Text('EXTRA',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kTextMuted)))),
                ]),
              ),
              const Divider(height: 1, color: Color(0xFFDEE2E6)),

              // Filas de permisos
              ...Perm.todos.asMap().entries.map((e) {
                final idx    = e.key;
                final codigo = e.value;
                final delRol = esAdmin || _rolPermisos.contains(codigo);
                final extra  = _extraPermisos.contains(codigo);
                return Container(
                  decoration: BoxDecoration(
                    color: idx.isOdd ? const Color(0xFFF8F9FA) : Colors.white,
                    border: const Border(bottom: BorderSide(color: Color(0xFFDEE2E6))),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(Perm.nombre(codigo),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          Text(codigo,
                              style: const TextStyle(fontSize: 10, color: kTextMuted)),
                        ]),
                      ),
                    ),
                    // DE ROL
                    SizedBox(width: 80, child: Center(
                      child: delRol
                          ? const Icon(Icons.lock, size: 18, color: kPrimary)
                          : const Icon(Icons.remove, size: 16, color: Color(0xFFDEE2E6)),
                    )),
                    // EXTRA
                    SizedBox(width: 80, child: Center(
                      child: esAdmin || delRol
                          ? const Icon(Icons.remove, size: 16, color: Color(0xFFDEE2E6))
                          : Checkbox(
                              value: extra,
                              activeColor: kPrimary,
                              onChanged: (v) => _toggleExtra(codigo, v!),
                            ),
                    )),
                  ]),
                );
              }),
            ]),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
