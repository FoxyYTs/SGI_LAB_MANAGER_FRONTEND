import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api/api_client.dart';
import '../core/theme/colors.dart';
import '../core/cache/cache_service.dart';
import '../providers/auth_provider.dart';
import '../core/sync/sync_service.dart';
import '../widgets/qr_generator_dialog.dart';

String _horaAmPm(int hora) {
  if (hora == 12) return '12 PM';
  if (hora > 12) return '${hora - 12} PM';
  return '$hora AM';
}

class DashboardContent extends StatefulWidget {
  final void Function(int tabIndex)? onNavigateTo;
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

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() => _cargando = true);
    final auth = context.read<AuthProvider>();
    final dio  = ApiClient.instance.authenticatedDio(auth.token);
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
      final rawEnc = results[1].data;
      final listaEnc = List<Map<String, dynamic>>.from(
          rawEnc is List ? rawEnc : (rawEnc['results'] ?? []));
      for (final e in listaEnc) {
        final dia  = e['dia_semana'] as int? ?? -1;
        final hora = e['hora'] as int? ?? -1;
        if (dia < 0 || hora < 0) continue;
        encByDia.putIfAbsent(dia, () => {}).putIfAbsent(hora, () => []).add(e);
      }

      // Indexar asignaturas por día y hora
      final asgByDia = <int, Map<int, List<Map<String, dynamic>>>>{};
      final rawAsg = results[2].data;
      final listaAsg = List<Map<String, dynamic>>.from(
          rawAsg is List ? rawAsg : (rawAsg['results'] ?? []));
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
      final isMobile = constraints.maxWidth < 650;
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

  Widget _statCard(IconData icon, String label, String value,
      Color color, Color bgColor) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(10),
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
        color: Colors.white, borderRadius: BorderRadius.circular(10),
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
              color: kPrimary,
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Horario Semanal',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                TextButton(
                  onPressed: () => widget.onNavigateTo?.call(4),
                  child: const Text('Ver completo →',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              ]),
            ),

            // Subtítulo
            Container(
              color: const Color(0xFFF0F4F8),
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

  // Fusiona horas consecutivas con el mismo contenido para ASG
  List<({int idx, int dur, List<Map<String, dynamic>> items})> _bloquesAsg(
      Map<int, List<Map<String, dynamic>>>? porHora) {
    final result = <({int idx, int dur, List<Map<String, dynamic>> items})>[];
    int i = 0;
    while (i < _horas.length) {
      final hora  = _horas[i];
      final items = porHora?[hora] ?? [];
      if (items.isEmpty) { i++; continue; }
      String key(Map<String, dynamic> item) =>
          '${item['asignatura']}|${item['docente']}|${item['grupo']}';
      final keys = items.map(key).toSet();
      int dur = 1;
      while (i + dur < _horas.length) {
        final next = porHora?[_horas[i + dur]] ?? [];
        if (next.isNotEmpty &&
            next.map(key).toSet().containsAll(keys) &&
            keys.containsAll(next.map(key).toSet())) {
          dur++;
        } else break;
      }
      result.add((idx: i, dur: dur, items: items));
      i += dur;
    }
    return result;
  }

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
              color: esHoy ? kPrimary : const Color(0xFF0069D9),
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
                        decoration: const BoxDecoration(
                          border: Border(
                            right:  BorderSide(color: Color(0xFFDEE2E6)),
                            bottom: BorderSide(color: Color(0xFFDEE2E6)),
                          ),
                        ),
                        child: Text(_horaAmPm(hora),
                            style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w600,
                                color: esAhora ? kPrimary : kTextMuted)),
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

                // Bloques consecutivos por usuario de encargado
                List<({int idx, int dur, Map<String, dynamic> enc})> _bloquesEnc() {
                  final result = <({int idx, int dur, Map<String, dynamic> enc})>[];
                  final porHora = _encByDia[dia] ?? {};
                  // Recoger usuarios únicos
                  final encMap = <int, Map<String, dynamic>>{};
                  for (final items in porHora.values) {
                    for (final item in items) {
                      encMap[item['usuario'] as int? ?? 0] ??= item;
                    }
                  }
                  for (final uid in encMap.keys) {
                    int i = 0;
                    while (i < _horas.length) {
                      final tiene = (porHora[_horas[i]] ?? []).any((e) => e['usuario'] == uid);
                      if (!tiene) { i++; continue; }
                      int dur = 1;
                      while (i + dur < _horas.length &&
                          (porHora[_horas[i + dur]] ?? []).any((e) => e['usuario'] == uid)) {
                        dur++;
                      }
                      result.add((idx: i, dur: dur, enc: encMap[uid]!));
                      i += dur;
                    }
                  }
                  return result;
                }

                final todosBloquesEnc = _bloquesEnc();
                final ocupados = {
                  for (final b in bloquesAsg) for (int k = 0; k < b.dur; k++) b.idx + k,
                  for (final b in todosBloquesEnc) for (int k = 0; k < b.dur; k++) b.idx + k,
                };

                // Para cada bloque de enc, calcular cuántos otros enc se solapan
                // y cuál es su posición (rank) entre ellos → determina el right offset
                int _rankEnBloque(({int idx, int dur, Map<String, dynamic> enc}) target) {
                  final uid = target.enc['usuario'] as int? ?? 0;
                  final solapantes = todosBloquesEnc
                      .where((b) {
                        final bUid = b.enc['usuario'] as int? ?? 0;
                        if (bUid == uid) return false;
                        return b.idx < target.idx + target.dur && b.idx + b.dur > target.idx;
                      })
                      .map((b) => b.enc['usuario'] as int? ?? 0)
                      .toSet()
                      .toList()..sort();
                  // rank = posición de este uid entre los solapantes + él mismo
                  final todos = ([uid, ...solapantes])..sort();
                  return todos.indexOf(uid);
                }

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
                                  ? const Color(0xFFD4E8FF)
                                  : esHoy && !ocupados.contains(i)
                                      ? const Color(0xFFF0F7FF)
                                      : i.isOdd ? const Color(0xFFF8F9FA) : Colors.white,
                              border: Border(
                                right:  const BorderSide(color: Color(0xFFDEE2E6)),
                                bottom: const BorderSide(color: Color(0xFFDEE2E6)),
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
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(4),
                              border: const Border(
                                left: BorderSide(color: kSuccess, width: 3),
                                top:    BorderSide(color: Color(0xFFB2DFDB)),
                                right:  BorderSide(color: Color(0xFFB2DFDB)),
                                bottom: BorderSide(color: Color(0xFFB2DFDB)),
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
                        final rank     = _rankEnBloque(b);
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

  Widget _buildAccionesRapidas() => Container(
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(10),
      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: kPrimary,
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
            // Botón QR prominente
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => showDialog(
                    context: context, builder: (_) => const QrGeneratorDialog()),
                icon: const Icon(Icons.qr_code_2, size: 22),
                label: const Text('Códigos QR',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Grid 2×3 de acciones secundarias
            GridView.count(
              crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8,
              childAspectRatio: 1.3, shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _accionBtn(Icons.add_box_outlined,          'Registrar entrada',    () => widget.onNavigateTo?.call(2)),
                _accionBtn(Icons.outbox_outlined,            'Registrar salida',     () => widget.onNavigateTo?.call(2)),
                _accionBtn(Icons.inventory_2_outlined,       'Escanear ítem',        () => widget.onNavigateTo?.call(1)),
                _accionBtn(Icons.check_circle_outlined,      'Aprobar préstamos',    () => widget.onNavigateTo?.call(2),
                    badge: '${_data?['prestamos_pendientes'] ?? 0}'),
                _accionBtn(Icons.history_outlined,           'Ver bitácora',         () => widget.onNavigateTo?.call(3)),
                _accionBtn(Icons.assignment_return_outlined, 'Registrar devolución', () => widget.onNavigateTo?.call(2)),
              ],
            ),
            // Link personalizar
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: null,
                child: Text('✏ Personalizar bandeja',
                    style: TextStyle(fontSize: 11, color: kTextMuted)),
              ),
            ),
          ]),
        ),
      ]),
    ),
  );

  Widget _accionBtn(IconData icon, String label, VoidCallback? onTap,
      {String? badge}) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFDEE2E6)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(children: [
            Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, color: kPrimary, size: 22),
                const SizedBox(height: 5),
                Text(label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF223542),
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
        color: Colors.white, borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(children: [
          // Header discreto
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFF8F9FA),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded, color: kSemaforoRojo, size: 16),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('⚠ Insumos Críticos',
                    style: TextStyle(color: Color(0xFF223542), fontWeight: FontWeight.bold, fontSize: 13)),
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
              TextButton(
                onPressed: () => widget.onNavigateTo?.call(1),
                style: TextButton.styleFrom(padding: EdgeInsets.zero,
                    minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: const Text('Ver todos →',
                    style: TextStyle(color: kPrimary, fontSize: 12)),
              ),
            ]),
          ),
          // Tabla
          SingleChildScrollView(
            scrollDirection: isMobile ? Axis.horizontal : Axis.vertical,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: isMobile ? 360 : 0),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(3),
                  1: FixedColumnWidth(110),
                  2: FixedColumnWidth(100),
                  3: FixedColumnWidth(90),
                },
                border: const TableBorder(
                    horizontalInside: BorderSide(color: Color(0xFFDEE2E6))),
                children: [
                  _headerRow(['Insumo', 'Stock actual', 'Mínimo', 'Estado']),
                  ...lista!.asMap().entries.map((e) {
                    final idx = e.key;
                    final ins = e.value as Map<String, dynamic>;
                    final stock    = double.tryParse(ins['stock_actual'].toString()) ?? 0;
                    final stockMin = double.tryParse(ins['stock_minimo'].toString()) ?? 0;
                    return TableRow(
                      decoration: BoxDecoration(
                          color: idx.isOdd ? const Color(0xFFF8F9FA) : Colors.white),
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
                                color: const Color(0xFFFFEBEE),
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
    decoration: const BoxDecoration(color: kPrimary),
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
        color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(8),
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
