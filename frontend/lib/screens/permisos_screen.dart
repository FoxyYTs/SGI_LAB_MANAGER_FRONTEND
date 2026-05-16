import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api/api_client.dart';
import '../core/theme/colors.dart';
import '../core/permissions.dart';
import '../providers/auth_provider.dart';

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
      final lista = List<Map<String, dynamic>>.from(resp.data['results'] ?? resp.data);

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
  List<Map<String, dynamic>> _usuarios = [];
  Map<String, dynamic>?      _seleccionado;
  Set<String>                _rolPermisos   = {};
  Set<String>                _extraPermisos = {};
  // codigo → id del PermisoUsuario
  Map<String, int>           _extraIds      = {};
  bool _loadingUsuarios = true;
  bool _loadingPermisos = false;

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
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

      final rolList   = List<Map<String, dynamic>>.from(results[0].data['results'] ?? results[0].data);
      final userList  = List<Map<String, dynamic>>.from(results[1].data['results'] ?? results[1].data);

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
          child: ListView.builder(
            itemCount: _usuarios.length,
            itemBuilder: (_, i) {
              final u       = _usuarios[i];
              final activo  = _seleccionado?['id'] == u['id'];
              final rol     = u['perfil']?['rol'] ?? '';
              return ListTile(
                selected: activo,
                selectedTileColor: kPrimary.withOpacity(0.08),
                leading: CircleAvatar(
                  backgroundColor: activo ? kPrimary : kPrimary.withOpacity(0.15),
                  child: Text(
                    (u['username'] as String).substring(0, 1).toUpperCase(),
                    style: TextStyle(
                        color: activo ? Colors.white : kPrimary,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(u['username'],
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text(rol, style: const TextStyle(fontSize: 11, color: kTextMuted)),
                onTap: () => _cargarPermisosUsuario(u),
              );
            },
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
    final nombre = '${_seleccionado!['first_name'] ?? ''} ${_seleccionado!['last_name'] ?? ''}'.trim();
    final username = _seleccionado!['username'];
    final rol      = _seleccionado!['perfil']?['rol'] ?? '';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(children: [
          const Icon(Icons.person_outline, color: kPrimary),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nombre.isEmpty ? username : nombre,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text('@$username · $rol',
                style: const TextStyle(color: kTextMuted, fontSize: 12)),
          ]),
        ]),
        const Divider(height: 24),
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
            // Si ya lo tiene por rol, no tiene sentido marcar extra (aunque no rompe nada)
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
