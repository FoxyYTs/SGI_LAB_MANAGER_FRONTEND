import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api/api_client.dart';
import '../core/theme/colors.dart';
import '../core/theme/app_theme.dart';
import '../core/cache/cache_service.dart';
import '../providers/auth_provider.dart';
import '../core/sync/sync_service.dart';
import '../core/horario_utils.dart';
import '../core/permissions.dart';
import '../core/secciones.dart';
import '../widgets/qr_generator_dialog.dart';
import '../widgets/registrar_movimiento_dialog.dart';
import 'mi_semana_screen.dart';

String _horaAmPm(int hora) {
  if (hora == 12) return '12 PM';
  if (hora > 12) return '${hora - 12} PM';
  return '$hora AM';
}

/// Botones de la grilla de "Acciones rápidas" del inicio.
enum AccionRapida {
  registrarEntrada,
  registrarSalida,
  nuevoPrestamo,
  aprobarPrestamos,
  registrarDevolucion,
  buscarInsumo,
  verBitacora,
}

/// Acciones rápidas que ve un usuario con los permisos de [can]: cada una
/// exige lo mismo que el backend para la acción a la que lleva, y que la
/// pestaña de destino exista para él.
List<AccionRapida> accionesRapidasPara(bool Function(String permiso) can) {
  final inventario = can(Perm.inventarioVer);
  final prestamos  = can(Perm.prestamosVer);
  return [
    // POST operaciones/bitacora/ → bitacora.gestionar; el buscador lee el
    // inventario → inventario.ver.
    if (inventario && can(Perm.bitacoraGestionar)) ...[
      AccionRapida.registrarEntrada,
      AccionRapida.registrarSalida,
    ],
    // Crear un préstamo es público en el backend; el formulario vive en la
    // pestaña Movimientos (prestamos.ver).
    if (prestamos) AccionRapida.nuevoPrestamo,
    // Aprobar y registrar devoluciones → prestamos.gestionar.
    if (prestamos && can(Perm.prestamosGestionar)) ...[
      AccionRapida.aprobarPrestamos,
      AccionRapida.registrarDevolucion,
    ],
    if (inventario) AccionRapida.buscarInsumo,
    if (can(Perm.bitacoraVer)) AccionRapida.verBitacora,
  ];
}

/// Navega a otra pestaña de la pantalla principal por identidad (no por
/// índice: la posición de cada pestaña depende de los permisos).
typedef NavegarASeccion = void Function(Seccion seccion,
    {DestinoPrestamos? prestamos});

class DashboardContent extends StatefulWidget {
  final NavegarASeccion? onNavigateTo;
  const DashboardContent({super.key, this.onNavigateTo});
  @override State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  static const _cacheKey = 'dashboard';

  Map<String, dynamic>? _data;

  // dia(0-5) → hora(6-21) → lista de items
  Map<int, Map<int, List<Map<String, dynamic>>>> _encByDia = {};
  Map<int, Map<int, List<Map<String, dynamic>>>> _asgByDia = {};

  bool      _cargando   = true;
  bool      _desdeCache = false;
  DateTime? _cachedAt;
  bool      _eraOnline  = true;

  // Avance semanal del monitor logueado (solo si hace turnos de monitor).
  MiSemana? _miSemana;

  @override
  void initState() {
    super.initState();
    Future.microtask(_cargar);
    _eraOnline = SyncService.instance.online;
    SyncService.instance.addListener(_onSync);
  }

  void _onSync() {
    final ahoraOnline = SyncService.instance.online;
    if (!_eraOnline && ahoraOnline && mounted) _cargar();
    _eraOnline = ahoraOnline;
  }

  @override
  void dispose() {
    SyncService.instance.removeListener(_onSync);
    super.dispose();
  }

  /// Carga "Mi semana" aparte: si falla, el dashboard sigue igual.
  Future<void> _cargarMiSemana() async {
    final auth = context.read<AuthProvider>();
    if (!auth.haceTurnosMonitor) {
      if (_miSemana != null && mounted) setState(() => _miSemana = null);
      return;
    }
    try {
      final r = await ApiClient.instance.authenticatedDio(auth.token).get('academico/mi-semana/');
      if (!mounted) return;
      setState(() => _miSemana = MiSemana.desdeJson(Map<String, dynamic>.from(r.data as Map)));
    } catch (_) {}
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() => _cargando = true);
    final auth = context.read<AuthProvider>();
    final dio  = ApiClient.instance.authenticatedDio(auth.token);
    _cargarMiSemana();
    try {
      final results = await Future.wait([
        dio.get('academico/dashboard/'),
        dio.get('academico/horario-encargado/'),   // todos los días
        dio.get('academico/horario-asignatura/'),  // todos los días
      ]);
      final data = Map<String, dynamic>.from(results[0].data);
      await CacheService.instance.set(_cacheKey, data);

      // Indexar encargados por día y hora
      final encByDia = <int, Map<int, List<Map<String, dynamic>>>>{};
      // Horarios sin paginar en el backend; ApiListas también tolera {results}.
      final listaEnc = ApiListas.listaDe(results[1].data);
      for (final e in listaEnc) {
        final dia  = e['dia_semana'] as int? ?? -1;
        final hora = e['hora'] as int? ?? -1;
        if (dia < 0 || hora < 0) continue;
        encByDia.putIfAbsent(dia, () => {}).putIfAbsent(hora, () => []).add(e);
      }

      // Indexar asignaturas por día y hora
      final asgByDia = <int, Map<int, List<Map<String, dynamic>>>>{};
      final listaAsg = ApiListas.listaDe(results[2].data);
      for (final a in listaAsg) {
        final dia  = a['dia_semana'] as int? ?? -1;
        final hora = a['hora'] as int? ?? -1;
        if (dia < 0 || hora < 0) continue;
        asgByDia.putIfAbsent(dia, () => {}).putIfAbsent(hora, () => []).add(a);
      }

      if (!mounted) return;
      setState(() {
        _data       = data;
        _encByDia   = encByDia;
        _asgByDia   = asgByDia;
        _desdeCache = false;
        _cachedAt   = null;
        _cargando   = false;
      });
    } catch (_) {
      final cached = await CacheService.instance.get(_cacheKey);
      if (!mounted) return;
      setState(() {
        _data       = cached != null ? Map<String, dynamic>.from(cached.data as Map) : null;
        _desdeCache = cached != null;
        _cachedAt   = cached?.cachedAt;
        _cargando   = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // En landscape en móvil (ancho > alto pero pantalla pequeña) tratamos como móvil
      final screenSize = MediaQuery.of(context).size;
      final isLandscapePhone = screenSize.width < 900 &&
          screenSize.width > screenSize.height;
      final isMobile = constraints.maxWidth < 650 || isLandscapePhone;
      final pad = isMobile ? 14.0 : 24.0;
      return SingleChildScrollView(
        padding: EdgeInsets.all(pad),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner caché
                if (_desdeCache) ...[
                  _CacheBanner(cachedAt: _cachedAt, onRefresh: _cargar),
                  SizedBox(height: isMobile ? 10 : 14),
                ],

                // Stats
                if (_cargando)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(color: kPrimary),
                  ))
                else if (_data != null) ...[
                  _buildStatCards(constraints.maxWidth, isMobile),
                  SizedBox(height: isMobile ? 14 : 20),

                  if (_miSemana != null) ...[
                    MiSemanaResumenCard(
                      semana: _miSemana!,
                      compacta: true,
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const MiSemanaScreen()));
                        if (mounted) _cargarMiSemana();
                      },
                    ),
                    SizedBox(height: isMobile ? 14 : 20),
                  ],

                  // Horario + Acciones rápidas
                  if (isMobile)
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _buildAccionesRapidas(),
                      const SizedBox(height: 14),
                      _buildHorarioSemanal(isMobile),
                    ])
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 65, child: _buildHorarioSemanal(isMobile)),
                        const SizedBox(width: 16),
                        Expanded(flex: 35, child: _buildAccionesRapidas()),
                      ],
                    ),

                  SizedBox(height: isMobile ? 14 : 20),

                  // Tabla críticos (secundaria, al fondo)
                  _buildCriticosTable(isMobile),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        ),
      );
    });
  }

  // ── Stat cards ────────────────────────────────────────────────────────────

  Widget _buildStatCards(double availableWidth, bool isMobile) {
    final crossCount  = isMobile ? 2 : 4;
    final aspectRatio = isMobile ? 1.5 : 2.2;
    final cards = [
      _statCard(Icons.warning_amber_rounded,  'Insumos críticos',
          '${_data!['stock_critico'] ?? 0}',       kSemaforoRojo,           const Color(0xFFFFEBEE)),
      _statCard(Icons.info_outline,           'Insumos bajos',
          '${_data!['stock_bajo'] ?? 0}',           const Color(0xFFE65100), const Color(0xFFFFF3E0)),
      _statCard(Icons.swap_horiz_outlined,    'Préstamos activos',
          '${_data!['prestamos_activos'] ?? 0}',    kPrimary,                const Color(0xFFE3F2FD)),
      _statCard(Icons.hourglass_top_outlined, 'Por aprobar',
          '${_data!['prestamos_pendientes'] ?? 0}', const Color(0xFFE65100), const Color(0xFFFFF8E1)),
    ];
    return GridView.count(
      crossAxisCount: crossCount, crossAxisSpacing: 12, mainAxisSpacing: 12,
      childAspectRatio: aspectRatio, shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cards,
    );
  }

  Widget _statCard(IconData icon, String label, String value, Color color, Color bgColor) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          // Claro: pastel fijo del diseño original (limpio y luminoso). Oscuro:
          // tinte translúcido del color del dato (el pastel claro no sirve sobre fondo oscuro).
          color: Theme.of(context).brightness == Brightness.dark
              ? context.sgi.tileBg(color)
              : bgColor,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const Spacer(),
            Text(value, style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.bold, color: color, height: 1)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(
                color: color.withValues(alpha: 0.75), fontSize: 11,
                fontWeight: FontWeight.w500),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      );

  // ── Horario semanal ───────────────────────────────────────────────────────

  static const _dias   = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
  static const _horas  = [7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20];

  Widget _buildHorarioSemanal(bool isMobile) {
    final diaHoy     = DateTime.now().weekday - 1; // 0=Lun … 5=Sáb
    final horaActual = DateTime.now().hour;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header azul
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: context.sgi.brandBar,
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Horario Semanal',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                if (_puedeVer(Seccion.horario))
                  TextButton(
                    onPressed: () => widget.onNavigateTo?.call(Seccion.horario),
                    child: const Text('Ver completo →',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ),
              ]),
            ),

            // Subtítulo
            Container(
              color: Theme.of(context).colorScheme.surfaceContainer,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: const Text('Encargados y asignaturas en turno',
                  style: TextStyle(fontSize: 11, color: kTextMuted)),
            ),

            // Grilla
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildGridSemanal(diaHoy, horaActual),
            ),
          ],
        ),
      ),
    );
  }

  List<BloqueAsg> _bloquesAsg(Map<int, List<Map<String, dynamic>>>? porHora) =>
      HorarioUtils.bloquesAsg(porHora, _horas);

  // Color único por encargado basado en su username
  static Color _colorEncargado(String username) {
    const palette = [
      Color(0xFF1565C0), Color(0xFF6A1B9A), Color(0xFF00695C),
      Color(0xFFE65100), Color(0xFF880E4F), Color(0xFF004D40),
      Color(0xFF1A237E), Color(0xFF4E342E),
    ];
    final hash = username.codeUnits.fold(0, (a, b) => a + b);
    return palette[hash % palette.length];
  }

  Widget _buildGridSemanal(int diaHoy, int horaActual) {
    const labelWidth = 52.0;
    const colWidth   = 110.0;
    const rowHeight  = 44.0;
    const stripW     = 14.0; // ancho de cada franja de encargado
    const stripGap   =  2.0;
    final totalH = _horas.length * rowHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabecera días
        Row(children: [
          SizedBox(width: labelWidth),
          ..._dias.asMap().entries.map((e) {
            final esHoy = e.key == diaHoy;
            return Container(
              width: colWidth,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: esHoy
                  ? context.sgi.brandBar
                  : Color.lerp(context.sgi.brandBar, Colors.black, 0.18)!,
              alignment: Alignment.center,
              child: Text(e.value,
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: esHoy ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12)),
            );
          }),
        ]),
        SizedBox(
          height: totalH,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Columna de horas
              SizedBox(
                width: labelWidth,
                height: totalH,
                child: Stack(
                  children: _horas.asMap().entries.map((e) {
                    final hora    = e.value;
                    final esAhora = hora == horaActual && diaHoy >= 0 && diaHoy <= 5;
                    return Positioned(
                      top: e.key * rowHeight, left: 0, right: 0, height: rowHeight,
                      child: Container(
                        alignment: Alignment.topCenter,
                        padding: const EdgeInsets.only(top: 6),
                        decoration: BoxDecoration(
                          border: Border(
                            right:  BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                            bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                          ),
                        ),
                        child: Text(_horaAmPm(hora),
                            style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w600,
                                color: esAhora ? context.sgi.accent : kTextMuted)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              // Columnas por día
              ..._dias.asMap().entries.map((dEntry) {
                final dia   = dEntry.key;
                final esHoy = dia == diaHoy;

                // Bloques fusionados de asignatura
                final bloquesAsg = _bloquesAsg(_asgByDia[dia]);

                final todosBloquesEnc =
                    HorarioUtils.bloquesEnc(_encByDia[dia] ?? {}, _horas);
                final ocupados = {
                  for (final b in bloquesAsg) for (int k = 0; k < b.dur; k++) b.idx + k,
                  for (final b in todosBloquesEnc) for (int k = 0; k < b.dur; k++) b.idx + k,
                };

                return SizedBox(
                  width: colWidth,
                  height: totalH,
                  child: Stack(
                    children: [
                      // Fondo por hora
                      ...List.generate(_horas.length, (i) {
                        final hora    = _horas[i];
                        final esAhora = hora == horaActual && esHoy;
                        return Positioned(
                          top: i * rowHeight, left: 0, right: 0, height: rowHeight,
                          child: Container(
                            decoration: BoxDecoration(
                              color: esAhora
                                  ? context.sgi.accent.withValues(alpha: 0.18)
                                  : esHoy && !ocupados.contains(i)
                                      ? context.sgi.accent.withValues(alpha: 0.07)
                                      : i.isOdd
                                          ? Theme.of(context).colorScheme.surfaceContainer
                                          : Theme.of(context).colorScheme.surface,
                              border: Border(
                                right:  BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                                bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                                left: esAhora
                                    ? const BorderSide(color: kSemaforoRojo, width: 2)
                                    : BorderSide.none,
                              ),
                            ),
                          ),
                        );
                      }),
                      // Bloques de asignatura — izquierda, ancho completo
                      ...bloquesAsg.map((b) {
                        final a      = b.items.first;
                        final nombre = a['nombre_asignatura'] as String? ?? '?';
                        final grupo  = a['grupo'] as String? ?? '';
                        return Positioned(
                          top: b.idx * rowHeight + 2,
                          left: 2, right: 2,
                          height: b.dur * rowHeight - 4,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(5, 3, 5, 3),
                            decoration: BoxDecoration(
                              color: kSuccess.withValues(alpha: 0.15),
                              border: Border(
                                left: const BorderSide(color: kSuccess, width: 3),
                                top:    BorderSide(color: kSuccess.withValues(alpha: 0.4)),
                                right:  BorderSide(color: kSuccess.withValues(alpha: 0.4)),
                                bottom: BorderSide(color: kSuccess.withValues(alpha: 0.4)),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('$nombre${grupo.isNotEmpty ? ' Gr.$grupo' : ''}',
                                    style: const TextStyle(color: kSuccess,
                                        fontSize: 10, fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: b.dur > 1 ? 2 : 1),
                                if (b.dur > 1)
                                  Text('${b.dur}h',
                                      style: TextStyle(
                                          color: kSuccess.withValues(alpha: 0.7),
                                          fontSize: 9)),
                              ],
                            ),
                          ),
                        );
                      }),
                      // Franjas de encargados — derecha, semitransparentes, adaptativas
                      ...todosBloquesEnc.map((b) {
                        final username = b.enc['username']?.toString() ?? '?';
                        final nombre   = b.enc['nombre_completo']?.toString() ?? username;
                        final color    = _colorEncargado(username);
                        final rank     = HorarioUtils.rankEnBloque(b, todosBloquesEnc);
                        final rightOff = 2.0 + rank * (stripW + stripGap);
                        return Positioned(
                          top:    b.idx * rowHeight + 2,
                          right:  rightOff,
                          width:  stripW,
                          height: b.dur * rowHeight - 4,
                          child: Tooltip(
                            message: nombre,
                            child: Container(
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              alignment: Alignment.topCenter,
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                username.isNotEmpty ? username[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white,
                                    fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // ── Acciones rápidas ──────────────────────────────────────────────────────

  /// ¿El usuario tiene la pestaña [s]? (la misma regla que usa MainShell).
  bool _puedeVer(Seccion s) => s.visiblePara(context.read<AuthProvider>().can);

  Future<void> _registrarMovimiento(MovimientoStock tipo) async {
    final ok = await buscarInsumoYRegistrarMovimiento(context, tipo: tipo);
    if (ok && mounted) _cargar(); // los contadores de stock pueden cambiar
  }

  /// Botones de la grilla que el usuario puede usar (ver [accionesRapidasPara]).
  List<Widget> _accionesVisibles() {
    final auth = context.watch<AuthProvider>();
    final ir = widget.onNavigateTo;
    return accionesRapidasPara(auth.can).map((a) => switch (a) {
      AccionRapida.registrarEntrada => _accionBtn(Icons.add_box_outlined,
          'Registrar entrada', () => _registrarMovimiento(MovimientoStock.entrada)),
      AccionRapida.registrarSalida => _accionBtn(Icons.outbox_outlined,
          'Registrar salida', () => _registrarMovimiento(MovimientoStock.salida)),
      AccionRapida.nuevoPrestamo => _accionBtn(Icons.post_add_outlined,
          'Nuevo préstamo', () => ir?.call(Seccion.movimientos,
              prestamos: const DestinoPrestamos(nuevoPrestamo: true))),
      AccionRapida.aprobarPrestamos => _accionBtn(Icons.check_circle_outlined,
          'Aprobar préstamos', () => ir?.call(Seccion.movimientos,
              prestamos: const DestinoPrestamos(estado: 'PENDIENTE')),
          badge: '${_data?['prestamos_pendientes'] ?? 0}'),
      AccionRapida.registrarDevolucion => _accionBtn(Icons.assignment_return_outlined,
          'Registrar devolución', () => ir?.call(Seccion.movimientos,
              prestamos: const DestinoPrestamos(estado: 'ACTIVO'))),
      AccionRapida.buscarInsumo => _accionBtn(Icons.search,
          'Buscar insumo', () => ir?.call(Seccion.inventario)),
      AccionRapida.verBitacora => _accionBtn(Icons.history_outlined,
          'Ver bitácora', () => ir?.call(Seccion.bitacora)),
    }).toList();
  }

  Widget _buildAccionesRapidas() {
    final acciones = _accionesVisibles();
    return Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(10),
      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: context.sgi.brandBar,
          child: const Row(children: [
            Icon(Icons.bolt_outlined, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Acciones rápidas',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            // Botón QR prominente (formularios públicos: no requiere permiso)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => showDialog(
                    context: context, builder: (_) => const QrGeneratorDialog()),
                icon: const Icon(Icons.qr_code_2, size: 22),
                label: const Text('Códigos QR',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.sgi.brandBar, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ),
            if (acciones.isNotEmpty) ...[
              const SizedBox(height: 10),
              // Grilla de acciones secundarias (según permisos)
              GridView.count(
                crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8,
                childAspectRatio: 1.3, shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: acciones,
              ),
            ],
          ]),
        ),
      ]),
    ),
  );
  }

  Widget _accionBtn(IconData icon, String label, VoidCallback? onTap,
      {String? badge}) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(children: [
            Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, color: context.sgi.accent, size: 22),
                const SizedBox(height: 5),
                Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w500),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ]),
            ),
            if (badge != null && badge != '0')
              Positioned(
                top: 6, right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                      color: kDanger, borderRadius: BorderRadius.circular(10)),
                  child: Text(badge,
                      style: const TextStyle(color: Colors.white, fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ),
          ]),
        ),
      );

  // ── Tabla críticos (secundaria) ───────────────────────────────────────────

  Widget _buildCriticosTable(bool isMobile) {
    final lista = _data!['lista_criticos'] as List?;
    if (lista?.isNotEmpty != true) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(children: [
          // Header discreto
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded, color: kSemaforoRojo, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text('⚠ Insumos Críticos',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: kSemaforoRojo, borderRadius: BorderRadius.circular(10)),
                child: Text('${lista!.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              if (_puedeVer(Seccion.inventario))
                TextButton(
                  onPressed: () => widget.onNavigateTo?.call(Seccion.inventario),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero,
                      minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: Text('Ver todos →',
                      style: TextStyle(color: context.sgi.accent, fontSize: 12)),
                ),
            ]),
          ),
          // Tabla
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 460),
              child: Table(
                columnWidths: const {
                  0: FixedColumnWidth(170),
                  1: FixedColumnWidth(110),
                  2: FixedColumnWidth(100),
                  3: FixedColumnWidth(90),
                },
                border: TableBorder(
                    horizontalInside: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
                children: [
                  _headerRow(['Insumo', 'Stock actual', 'Mínimo', 'Estado']),
                  ...lista.asMap().entries.map((e) {
                    final idx = e.key;
                    final ins = e.value as Map<String, dynamic>;
                    final stock    = double.tryParse(ins['stock_actual'].toString()) ?? 0;
                    final stockMin = double.tryParse(ins['stock_minimo'].toString()) ?? 0;
                    return TableRow(
                      decoration: BoxDecoration(
                          color: idx.isOdd ? Theme.of(context).colorScheme.surfaceContainer : Theme.of(context).colorScheme.surface),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(children: [
                            Container(width: 8, height: 8,
                                decoration: const BoxDecoration(
                                    color: kSemaforoRojo, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(ins['nombre_insumo']?.toString() ?? '',
                                style: const TextStyle(fontWeight: FontWeight.w500))),
                          ]),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Text('${stock.toStringAsFixed(1)} ${ins['unidad_abreviatura'] ?? ''}',
                              style: const TextStyle(color: kSemaforoRojo, fontWeight: FontWeight.bold)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Text(stockMin.toStringAsFixed(1),
                              style: const TextStyle(color: kTextMuted)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: kSemaforoRojo.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20)),
                            child: const Text('Crítico',
                                style: TextStyle(color: kSemaforoRojo, fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  TableRow _headerRow(List<String> cols) => TableRow(
    decoration: BoxDecoration(color: context.sgi.brandBar),
    children: cols.map((h) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(h, softWrap: false, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
    )).toList(),
  );
}

// ── Banner de caché ───────────────────────────────────────────────────────────

class _CacheBanner extends StatelessWidget {
  final DateTime? cachedAt;
  final VoidCallback onRefresh;
  const _CacheBanner({required this.cachedAt, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final edad = cachedAt != null ? CacheService.formatEdad(cachedAt!) : '—';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kSemaforoAmarillo.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kSemaforoAmarillo),
      ),
      child: Row(children: [
        const Icon(Icons.history, color: Color(0xFFE65100), size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text('Mostrando datos guardados ($edad)',
            style: const TextStyle(fontSize: 12, color: Color(0xFFE65100)))),
        GestureDetector(onTap: onRefresh,
            child: const Icon(Icons.refresh, color: Color(0xFFE65100), size: 16)),
      ]),
    );
  }
}
