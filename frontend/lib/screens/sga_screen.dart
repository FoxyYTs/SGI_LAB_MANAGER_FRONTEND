import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api/api_client.dart';
import '../core/theme/colors.dart';
import '../providers/auth_provider.dart';

// ── Constantes de pictogramas ─────────────────────────────────────────────────

const _ghsInfo = {
  'GHS01': ('💥', 'Explosivo',          Color(0xFFCC0000)),
  'GHS02': ('🔥', 'Inflamable',          Color(0xFFFF6600)),
  'GHS03': ('⭕', 'Oxidante',            Color(0xFFFF6600)),
  'GHS04': ('⬤',  'Gas comprimido',     Color(0xFF0066CC)),
  'GHS05': ('⚗️', 'Corrosivo',           Color(0xFFCC0000)),
  'GHS06': ('☠',  'Tóxico agudo',        Color(0xFFCC0000)),
  'GHS07': ('!',   'Nocivo/irritante',   Color(0xFFFF6600)),
  'GHS08': ('♡',   'Peligro para salud', Color(0xFFFF6600)),
  'GHS09': ('🌿', 'Peligro ambiental',  Color(0xFF006600)),
};

// ── Pantalla raíz SGA ─────────────────────────────────────────────────────────

class SgaScreen extends StatefulWidget {
  final String insumoId;
  final String insumoNombre;
  const SgaScreen({super.key, required this.insumoId, required this.insumoNombre});

  @override
  State<SgaScreen> createState() => _SgaScreenState();
}

class _SgaScreenState extends State<SgaScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic>? _datos;
  Map<String, dynamic>? _colmena;
  bool _cargando = true;
  bool _extrayendo = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _cargar();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String get _token => context.read<AuthProvider>().token ?? '';

  Dio get _dio => ApiClient.instance.authenticatedDio(_token);

  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final r = await _dio.get('inventario/lista/${widget.insumoId}/quimico/');
      setState(() { _datos = Map<String, dynamic>.from(r.data); });
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        setState(() { _datos = {}; });
      } else {
        setState(() { _error = 'Error cargando datos SGA'; });
      }
    } finally {
      setState(() { _cargando = false; });
    }
  }

  Future<void> _cargarColmena() async {
    if (_colmena != null) return;
    try {
      final r = await _dio.get('inventario/lista/${widget.insumoId}/sga/colmena/');
      setState(() { _colmena = Map<String, dynamic>.from(r.data); });
    } catch (_) {
      setState(() { _colmena = {}; });
    }
  }

  Future<void> _extraerFDS() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes ?? Uint8List(0);
    if (bytes.isEmpty) {
      _snack('No se pudo leer el archivo.', kDanger);
      return;
    }

    // ── Paso 1: extraer sin guardar ──────────────────────────────────────────
    setState(() { _extrayendo = true; });
    Map<String, dynamic> preview;
    try {
      final formData = FormData.fromMap({
        'fds': MultipartFile.fromBytes(bytes, filename: file.name),
      });
      final r = await _dio.post(
        'inventario/lista/${widget.insumoId}/sga/extraer-fds/',
        data: formData,
        options: Options(receiveTimeout: const Duration(seconds: 60)),
      );
      preview = Map<String, dynamic>.from(r.data);
    } on DioException catch (e) {
      _snack(e.response?.data?['detail'] ?? 'Error al procesar el PDF.', kDanger);
      setState(() { _extrayendo = false; });
      return;
    } finally {
      if (mounted) setState(() { _extrayendo = false; });
    }

    // ── Paso 2: mostrar diálogo de confirmación ──────────────────────────────
    if (!mounted) return;
    final confirmado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogConfirmacionFDS(
        diff: List<Map<String, dynamic>>.from(preview['diff'] ?? []),
        camposVacios: List<Map<String, dynamic>>.from(preview['campos_vacios'] ?? []),
        sinDatosPrevios: preview['sin_datos_previos'] as bool? ?? true,
        totalCambios: preview['total_cambios'] as int? ?? 0,
      ),
    );
    if (confirmado != true) return;

    // ── Paso 3: confirmar y guardar ──────────────────────────────────────────
    setState(() { _extrayendo = true; });
    try {
      final r2 = await _dio.post(
        'inventario/lista/${widget.insumoId}/sga/extraer-fds/?confirmar=1',
        data: {'datos_extraidos': preview['datos_extraidos']},
        options: Options(
          contentType: Headers.jsonContentType,
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      if (!mounted) return;
      setState(() { _datos = Map<String, dynamic>.from(r2.data['datos']); _colmena = null; });
      final vacios = List<Map<String, dynamic>>.from(r2.data['campos_vacios'] ?? []);
      if (vacios.isNotEmpty) {
        _snack('Extracción aplicada. ${vacios.length} campo(s) sin datos en la FDS.', kSemaforoAmarillo);
      } else {
        _snack('Extracción completada exitosamente.', kSuccess);
      }
    } on DioException catch (e) {
      _snack(e.response?.data?['detail'] ?? 'Error al confirmar la extracción.', kDanger);
    } finally {
      if (mounted) setState(() { _extrayendo = false; });
    }
  }

  Future<void> _abrirEtiquetaUrl() async {
    // Diálogo para elegir el tamaño de etiqueta
    final formatos = [
      {'value': 'pequena', 'label': 'Pequeña',    'sub': '52 × 74 mm'},
      {'value': '50l',     'label': 'Máx. 50 L',  'sub': '74 × 105 mm'},
      {'value': '500l',    'label': 'Máx. 500 L', 'sub': '105 × 148 mm'},
      {'value': 'grande',  'label': 'Más de 500 L','sub': '148 × 210 mm'},
    ];

    final elegido = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seleccionar tamaño de etiqueta',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: formatos.map((f) => ListTile(
            dense: true,
            leading: const Icon(Icons.label_outline, color: Color(0xFF1E73BE)),
            title: Text(f['label']!, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(f['sub']!),
            onTap: () => Navigator.pop(ctx, f['value']),
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (elegido == null || !mounted) return;

    final dlToken = await ApiClient.instance.obtenerTokenDescarga(_token);
    if (!mounted) return;
    if (dlToken == null) {
      _snack('No se pudo generar el token de descarga.', kDanger);
      return;
    }

    final url = Uri.parse(
      '${ApiClient.instance.baseUrl}inventario/lista/${widget.insumoId}/sga/etiqueta-pdf/'
      '?download_token=$dlToken&formato=$elegido',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _snack('No se pudo abrir el visor de PDF.', kDanger);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 2,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ficha SGA/GHS',
                style: TextStyle(fontWeight: FontWeight.bold, color: kPrimary, fontSize: 17)),
            Text(widget.insumoNombre,
                style: const TextStyle(color: kTextMuted, fontSize: 12),
                overflow: TextOverflow.ellipsis),
          ],
        ),
        actions: [
          if (_extrayendo)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary))),
            )
          else
            IconButton(
              tooltip: 'Subir FDS para extraer datos',
              icon: const Icon(Icons.upload_file, color: kPrimary),
              onPressed: _extraerFDS,
            ),
          IconButton(
            tooltip: 'Generar etiqueta GHS',
            icon: const Icon(Icons.label_outline, color: kSuccess),
            onPressed: _datos == null || _datos!.isEmpty ? null : _abrirEtiquetaUrl,
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: kPrimary,
          unselectedLabelColor: kTextMuted,
          indicatorColor: kPrimary,
          onTap: (i) { if (i == 2) _cargarColmena(); },
          tabs: const [
            Tab(icon: Icon(Icons.science_outlined),  text: 'Datos SGA'),
            Tab(icon: Icon(Icons.edit_note_outlined), text: 'Editar'),
            Tab(icon: Icon(Icons.assignment_outlined), text: 'Colmena ARL'),
          ],
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : _error != null
              ? _buildError()
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _DatosSgaTab(datos: _datos ?? {}, insumoNombre: widget.insumoNombre),
                    _EditarSgaTab(
                      insumoId: widget.insumoId,
                      datos: _datos ?? {},
                      onGuardado: (d) => setState(() { _datos = d; _colmena = null; }),
                    ),
                    _ColmenaTab(colmena: _colmena),
                  ],
                ),
    );
  }

  Widget _buildError() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: kDanger, size: 48),
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(color: kDanger)),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _cargar, child: const Text('Reintentar')),
      ],
    ),
  );
}

// ── Tab: Vista de datos SGA ───────────────────────────────────────────────────

class _DatosSgaTab extends StatelessWidget {
  final Map<String, dynamic> datos;
  final String insumoNombre;
  const _DatosSgaTab({required this.datos, required this.insumoNombre});

  @override
  Widget build(BuildContext context) {
    if (datos.isEmpty) return _buildEmpty(context);

    final fraseH   = (datos['frases_h'] as List?)?.cast<String>() ?? [];
    final fraseP   = (datos['frases_p'] as List?)?.cast<String>() ?? [];
    final pics     = (datos['pictogramas_sga'] as List?)?.cast<String>() ?? [];
    final tieneNfpa = datos['nfpa_salud'] != null ||
        datos['nfpa_inflamable'] != null || datos['nfpa_reactivo'] != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBanner(datos),
              const SizedBox(height: 16),

              // Pictogramas + NFPA
              if (pics.isNotEmpty || tieneNfpa) ...[
                LayoutBuilder(builder: (ctx, c) {
                  final dos = c.maxWidth > 580;
                  final pCard = pics.isNotEmpty ? _buildPictogramasCard(pics) : null;
                  final nCard = tieneNfpa ? _buildNfpaCard(datos) : null;
                  if (pCard != null && nCard != null && dos) {
                    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(flex: 60, child: pCard),
                      const SizedBox(width: 12),
                      Expanded(flex: 40, child: nCard),
                    ]);
                  }
                  return Column(children: [
                    ?pCard,
                    if (pCard != null && nCard != null) const SizedBox(height: 12),
                    ?nCard,
                  ]);
                }),
                const SizedBox(height: 12),
              ],

              if (fraseH.isNotEmpty) ...[
                _buildFrasesCard('H — Indicaciones de peligro',
                    Icons.warning_amber_rounded, kDanger, fraseH),
                const SizedBox(height: 12),
              ],
              if (fraseP.isNotEmpty) ...[
                _buildFrasesCard('P — Consejos de prudencia',
                    Icons.shield_outlined, kPrimary, fraseP),
                const SizedBox(height: 12),
              ],
              if (datos['epp']?.toString().isNotEmpty == true) ...[
                _SgaCard(
                  titulo: 'EPP — Equipo de Protección',
                  icon: Icons.security_outlined,
                  headerColor: kPrimary,
                  child: Text(datos['epp'].toString(),
                      style: const TextStyle(fontSize: 13)),
                ),
                const SizedBox(height: 12),
              ],
              if (datos['primeros_auxilios']?.toString().isNotEmpty == true) ...[
                _SgaCard(
                  titulo: 'Primeros auxilios',
                  icon: Icons.medical_services_outlined,
                  headerColor: kSuccess,
                  child: Text(datos['primeros_auxilios'].toString(),
                      style: const TextStyle(fontSize: 13)),
                ),
                const SizedBox(height: 12),
              ],
              if (datos['fecha_vencimiento']?.toString().isNotEmpty == true) ...[
                _SgaCard(
                  titulo: 'Fecha de vencimiento',
                  icon: Icons.event_outlined,
                  headerColor: kTextMuted,
                  child: Text(datos['fecha_vencimiento'].toString(),
                      style: const TextStyle(fontSize: 13)),
                ),
                const SizedBox(height: 12),
              ],

              if (datos['fds_drive_url']?.toString().isNotEmpty == true)
                OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Ver FDS en Google Drive'),
                  onPressed: () async {
                    final uri = Uri.parse(datos['fds_drive_url'].toString());
                    if (await canLaunchUrl(uri)) {
                      launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),

              const SizedBox(height: 16),
              if (datos['datos_extraidos'] == true)
                Text(
                  'Datos extraídos automáticamente · '
                  '${datos['fecha_extraccion']?.toString().substring(0, 10) ?? ''}',
                  style: const TextStyle(color: kTextMuted, fontSize: 11),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.science_outlined, size: 64, color: kTextMuted),
      const SizedBox(height: 12),
      const Text('Sin datos SGA cargados',
          style: TextStyle(fontSize: 16, color: kTextMuted)),
      const SizedBox(height: 8),
      const Text('Sube la FDS (PDF) para extraer datos automáticamente',
          style: TextStyle(color: kTextMuted, fontSize: 13), textAlign: TextAlign.center),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        icon: const Icon(Icons.upload_file),
        label: const Text('Subir FDS'),
        style: ElevatedButton.styleFrom(
            backgroundColor: kPrimary, foregroundColor: Colors.white),
        onPressed: () =>
            (context.findAncestorStateOfType<_SgaScreenState>())?._extraerFDS(),
      ),
    ]),
  );

  Widget _buildBanner(Map<String, dynamic> d) {
    final pwa   = d['palabra_advertencia']?.toString() ?? '';
    final color = pwa == 'PELIGRO' ? kDanger : kSemaforoAmarillo;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
      ),
      child: Column(children: [
        Icon(Icons.warning_amber_rounded, color: color, size: 42),
        const SizedBox(height: 6),
        if (pwa.isNotEmpty)
          Text(pwa, style: TextStyle(
              fontWeight: FontWeight.bold, color: color, fontSize: 22)),
        const SizedBox(height: 4),
        Text(d['nombre_producto']?.toString() ?? insumoNombre,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            textAlign: TextAlign.center),
        if (d['formula_quimica']?.toString().isNotEmpty == true)
          Text(d['formula_quimica'].toString(),
              style: const TextStyle(fontSize: 13, color: kTextMuted)),
        if (d['numero_cas']?.toString().isNotEmpty == true)
          Text('CAS: ${d['numero_cas']}',
              style: const TextStyle(color: kTextMuted, fontSize: 12)),
      ]),
    );
  }

  Widget _buildPictogramasCard(List<String> pics) => _SgaCard(
    titulo: 'Pictogramas GHS',
    icon: Icons.category_outlined,
    headerColor: kPrimary,
    child: Wrap(
      spacing: 8, runSpacing: 8,
      children: pics.map((code) {
        final info  = _ghsInfo[code];
        final emoji = info?.$1 ?? '?';
        final label = info?.$2 ?? code;
        final color = info?.$3 ?? Colors.grey;
        return Container(
          width: 72,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(6),
            color: color.withValues(alpha: 0.06),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 4),
            Text(code, style: TextStyle(
                fontSize: 9, color: color, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(fontSize: 9, color: kTextMuted),
                textAlign: TextAlign.center, maxLines: 2),
          ]),
        );
      }).toList(),
    ),
  );

  Widget _buildNfpaCard(Map<String, dynamic> d) => _SgaCard(
    titulo: 'Rombo NFPA 704',
    icon: Icons.emergency_outlined,
    headerColor: const Color(0xFF8B0000),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _nfpaCell('SALUD',    d['nfpa_salud'],     Colors.blue.shade700),
        const SizedBox(width: 4),
        _nfpaCell('INFLAM.',  d['nfpa_inflamable'], Colors.red.shade700),
        const SizedBox(width: 4),
        _nfpaCell('REACTIV.', d['nfpa_reactivo'],   Colors.yellow.shade800),
        const SizedBox(width: 4),
        _nfpaCell('ESPEC.',
            d['nfpa_corrosivo'] == true ? 'W' : '–', Colors.grey.shade700),
      ],
    ),
  );

  Widget _nfpaCell(String label, dynamic val, Color color) => Container(
    width: 58, height: 58,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(val?.toString() ?? '–',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 8)),
    ]),
  );

  Widget _buildFrasesCard(String titulo, IconData icon, Color color, List<String> frases) =>
    _SgaCard(
      titulo: titulo,
      icon: icon,
      headerColor: color,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        children: frases.map((f) {
          final m    = RegExp(r'^([HPR]\d+[a-z]?)\s*[–—-]\s*(.+)$').firstMatch(f.trim());
          final code = m?.group(1) ?? '';
          final desc = m?.group(2) ?? f;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(6),
              border: Border(left: BorderSide(color: color, width: 3)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (code.isNotEmpty) ...[
                SizedBox(
                  width: 44,
                  child: Text(code, style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(child: Text(desc, style: const TextStyle(fontSize: 12))),
            ]),
          );
        }).toList(),
      ),
    );
}

// ── Tab: Edición de datos SGA ─────────────────────────────────────────────────

class _EditarSgaTab extends StatefulWidget {
  final String insumoId;
  final Map<String, dynamic> datos;
  final void Function(Map<String, dynamic>) onGuardado;
  const _EditarSgaTab({required this.insumoId, required this.datos, required this.onGuardado});

  @override
  State<_EditarSgaTab> createState() => _EditarSgaTabState();
}

class _EditarSgaTabState extends State<_EditarSgaTab> {
  final _formKey = GlobalKey<FormState>();
  late Map<String, dynamic> _d;
  bool _guardando = false;

  final _c = <String, TextEditingController>{};
  int? _nfpaSalud;
  int? _nfpaInflamable;
  int? _nfpaReactivo;
  bool _nfpaCorrosivo = false;
  DateTime? _fechaVencimiento;

  @override
  void initState() {
    super.initState();
    _d = Map.from(widget.datos);
    for (final k in ['nombre_producto', 'formula_quimica', 'numero_cas',
        'nombre_proveedor', 'direccion_proveedor', 'fds_drive_url',
        'palabra_advertencia', 'categoria_toxicidad', 'epp',
        'controles_tecnicos', 'primeros_auxilios', 'lucha_incendios',
        'vertido_accidental', 'estabilidad_reactividad', 'numero_un', 'estado_fisico']) {
      _c[k] = TextEditingController(text: _d[k]?.toString() ?? '');
    }
    // Normaliza enums a mayúsculas para que coincidan con los items del dropdown
    // (el modelo puede devolver "Peligro", "peligro", "ATENCION" sin tilde, etc.)
    final pwa = _c['palabra_advertencia']!.text.toUpperCase();
    _c['palabra_advertencia']!.text =
        pwa.contains('ATEN') ? 'ATENCIÓN' : pwa.isEmpty ? '' : 'PELIGRO';
    final ef = _c['estado_fisico']!.text.toUpperCase();
    // Mapea variantes conocidas al valor canónico
    const estadoMap = {
      'SOLIDO': 'SÓLIDO', 'SÓLIDO': 'SÓLIDO',
      'LIQUIDO': 'LÍQUIDO', 'LÍQUIDO': 'LÍQUIDO',
      'GASEOSO': 'GASEOSO', 'GAS': 'GASEOSO',
      'PASTA': 'PASTA', 'GEL': 'GEL',
    };
    _c['estado_fisico']!.text = estadoMap[ef] ?? ef;
    _nfpaSalud       = _d['nfpa_salud'] as int?;
    _nfpaInflamable  = _d['nfpa_inflamable'] as int?;
    _nfpaReactivo    = _d['nfpa_reactivo'] as int?;
    _nfpaCorrosivo   = _d['nfpa_corrosivo'] as bool? ?? false;
    final fv = _d['fecha_vencimiento']?.toString();
    if (fv != null && fv.isNotEmpty) {
      _fechaVencimiento = DateTime.tryParse(fv);
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) { c.dispose(); }
    super.dispose();
  }

  String get _token => context.read<AuthProvider>().token ?? '';

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _guardando = true; });
    final payload = <String, dynamic>{};
    for (final k in _c.keys) {
      payload[k] = _c[k]!.text.trim();
    }
    payload['nfpa_salud']       = _nfpaSalud;
    payload['nfpa_inflamable']  = _nfpaInflamable;
    payload['nfpa_reactivo']    = _nfpaReactivo;
    payload['nfpa_corrosivo']   = _nfpaCorrosivo;
    payload['fecha_vencimiento'] = _fechaVencimiento != null
        ? '${_fechaVencimiento!.year.toString().padLeft(4, '0')}-'
          '${_fechaVencimiento!.month.toString().padLeft(2, '0')}-'
          '${_fechaVencimiento!.day.toString().padLeft(2, '0')}'
        : null;
    try {
      final dio = ApiClient.instance.authenticatedDio(_token);
      final r = await dio.patch(
        'inventario/lista/${widget.insumoId}/quimico/',
        data: payload,
      );
      widget.onGuardado(Map<String, dynamic>.from(r.data));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datos guardados correctamente.'),
              backgroundColor: kSuccess));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error guardando datos.'),
              backgroundColor: kDanger));
      }
    } finally {
      if (mounted) setState(() { _guardando = false; });
    }
  }

  InputDecoration _deco(String label) => InputDecoration(
    labelText: label,
    border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8))),
    focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: kPrimary)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── S1 Identificación ───────────────────────────────────────
                _SgaCard(
                  titulo: 'S1 — Identificación',
                  icon: Icons.info_outline,
                  headerColor: kPrimary,
                  child: Column(children: [
                    TextFormField(
                        controller: _c['nombre_producto'],
                        decoration: _deco('Nombre del producto')),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: TextFormField(
                          controller: _c['formula_quimica'],
                          decoration: _deco('Fórmula química'))),
                      const SizedBox(width: 10),
                      Expanded(child: TextFormField(
                          controller: _c['numero_cas'],
                          decoration: _deco('Número CAS'))),
                    ]),
                    const SizedBox(height: 10),
                    TextFormField(
                        controller: _c['nombre_proveedor'],
                        decoration: _deco('Nombre del proveedor')),
                    const SizedBox(height: 10),
                    TextFormField(
                        controller: _c['direccion_proveedor'],
                        decoration: _deco('Dirección del proveedor')),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _c['fds_drive_url'],
                      decoration: _deco('URL de la FDS en Google Drive'),
                      keyboardType: TextInputType.url,
                    ),
                  ]),
                ),
                const SizedBox(height: 14),

                // ── S2 Peligros ─────────────────────────────────────────────
                _SgaCard(
                  titulo: 'S2 — Peligros',
                  icon: Icons.warning_amber_rounded,
                  headerColor: kDanger,
                  child: Column(children: [
                    DropdownButtonFormField<String>(
                      initialValue: _c['palabra_advertencia']!.text.isEmpty
                          ? null : _c['palabra_advertencia']!.text,
                      decoration: _deco('Palabra de advertencia'),
                      items: ['PELIGRO', 'ATENCIÓN'].map((v) =>
                          DropdownMenuItem(value: v, child: Text(v))).toList(),
                      onChanged: (v) => _c['palabra_advertencia']!.text = v ?? '',
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                        controller: _c['categoria_toxicidad'],
                        decoration: _deco('Categoría de toxicidad (si aplica)')),
                  ]),
                ),
                const SizedBox(height: 14),

                // ── S4-6 Respuesta a emergencias ────────────────────────────
                _SgaCard(
                  titulo: 'S4-6 — Respuesta a emergencias',
                  icon: Icons.local_hospital_outlined,
                  headerColor: kSuccess,
                  child: Column(children: [
                    TextFormField(controller: _c['primeros_auxilios'],
                        decoration: _deco('Primeros auxilios'), maxLines: 4),
                    const SizedBox(height: 10),
                    TextFormField(controller: _c['lucha_incendios'],
                        decoration: _deco('Lucha contra incendios'), maxLines: 3),
                    const SizedBox(height: 10),
                    TextFormField(controller: _c['vertido_accidental'],
                        decoration: _deco('Vertido accidental'), maxLines: 3),
                  ]),
                ),
                const SizedBox(height: 14),

                // ── S8 EPP y controles ──────────────────────────────────────
                _SgaCard(
                  titulo: 'S8 — EPP y controles de exposición',
                  icon: Icons.security_outlined,
                  headerColor: kPrimary,
                  child: Column(children: [
                    TextFormField(controller: _c['epp'],
                        decoration: _deco('Elementos de protección personal'),
                        maxLines: 3),
                    const SizedBox(height: 10),
                    TextFormField(controller: _c['controles_tecnicos'],
                        decoration: _deco('Controles técnicos'), maxLines: 2),
                  ]),
                ),
                const SizedBox(height: 14),

                // ── S9 + S10 Propiedades ────────────────────────────────────
                _SgaCard(
                  titulo: 'S9-10 — Propiedades físicas y estabilidad',
                  icon: Icons.science_outlined,
                  headerColor: kPrimary,
                  child: Column(children: [
                    DropdownButtonFormField<String>(
                      initialValue: _c['estado_fisico']!.text.isEmpty
                          ? null : _c['estado_fisico']!.text,
                      decoration: _deco('Estado físico'),
                      items: ['SÓLIDO', 'LÍQUIDO', 'GASEOSO', 'PASTA', 'GEL'].map((v) =>
                          DropdownMenuItem(value: v, child: Text(v))).toList(),
                      onChanged: (v) => _c['estado_fisico']!.text = v ?? '',
                    ),
                    const SizedBox(height: 10),
                    TextFormField(controller: _c['estabilidad_reactividad'],
                        decoration: _deco('Estabilidad y reactividad'),
                        maxLines: 3),
                  ]),
                ),
                const SizedBox(height: 14),

                // ── S14 + NFPA ──────────────────────────────────────────────
                _SgaCard(
                  titulo: 'S14 — Transporte y Rombo NFPA 704',
                  icon: Icons.local_shipping_outlined,
                  headerColor: const Color(0xFF8B0000),
                  child: Column(children: [
                    TextFormField(controller: _c['numero_un'],
                        decoration: _deco('Número UN')),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: _nfpaDropdown('Salud', _nfpaSalud,
                          (v) => setState(() => _nfpaSalud = v), Colors.blue.shade700)),
                      const SizedBox(width: 8),
                      Expanded(child: _nfpaDropdown('Inflamable', _nfpaInflamable,
                          (v) => setState(() => _nfpaInflamable = v), Colors.red.shade700)),
                      const SizedBox(width: 8),
                      Expanded(child: _nfpaDropdown('Reactivo', _nfpaReactivo,
                          (v) => setState(() => _nfpaReactivo = v), Colors.yellow.shade800)),
                    ]),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('Corrosivo (W especial)',
                          style: TextStyle(fontSize: 13)),
                      value: _nfpaCorrosivo,
                      activeThumbColor: kPrimary,
                      onChanged: (v) => setState(() => _nfpaCorrosivo = v),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ]),
                ),
                const SizedBox(height: 14),

                // ── Vencimiento ─────────────────────────────────────────────
                _SgaCard(
                  titulo: 'Vencimiento del lote',
                  icon: Icons.event_outlined,
                  headerColor: kTextMuted,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined, color: kPrimary),
                    title: Text(_fechaVencimiento != null
                        ? '${_fechaVencimiento!.day.toString().padLeft(2, '0')}/'
                          '${_fechaVencimiento!.month.toString().padLeft(2, '0')}/'
                          '${_fechaVencimiento!.year}'
                        : 'Sin fecha de vencimiento'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _fechaVencimiento ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2099),
                          );
                          if (picked != null) setState(() => _fechaVencimiento = picked);
                        },
                        child: const Text('Seleccionar'),
                      ),
                      if (_fechaVencimiento != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() => _fechaVencimiento = null),
                        ),
                    ]),
                  ),
                ),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _guardando ? null : _guardar,
                    icon: _guardando
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_outlined),
                    label: const Text('Guardar cambios'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _nfpaDropdown(String label, int? value,
      void Function(int?) onChanged, Color color) =>
    DropdownButtonFormField<int?>(
      initialValue: value,
      decoration: _deco(label).copyWith(
        labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: color, width: 1.5),
        ),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('–')),
        ...List.generate(5, (i) => DropdownMenuItem(value: i, child: Text(i.toString()))),
      ],
      onChanged: onChanged,
    );
}

// ── Tab: Datos para Colmena ARL ───────────────────────────────────────────────

class _ColmenaTab extends StatelessWidget {
  final Map<String, dynamic>? colmena;
  const _ColmenaTab({required this.colmena});

  @override
  Widget build(BuildContext context) {
    if (colmena == null) {
      return const Center(child: CircularProgressIndicator(color: kPrimary));
    }
    if (colmena!.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.science_outlined, size: 48, color: kTextMuted),
          SizedBox(height: 12),
          Text('No hay datos SGA cargados para este químico.',
              style: TextStyle(color: kTextMuted)),
          SizedBox(height: 4),
          Text('Usa la pestaña "Editar" o sube una FDS para extraer los datos.',
              style: TextStyle(color: kTextMuted, fontSize: 12)),
        ]),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kPrimary.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: kPrimary, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Copia estos datos al software de Colmena ARL para generar la etiqueta SGA.',
                    style: TextStyle(fontSize: 12, color: kPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...colmena!.entries.map((e) => _buildSeccionColmena(e.key, e.value)),
        ],
      ),
    );
  }

  Widget _buildSeccionColmena(String key, dynamic value) {
    if (value is! Map) return const SizedBox.shrink();
    final map    = Map<String, dynamic>.from(value);
    final titulo = map.remove('titulo')?.toString() ?? key;
    return _ColmenaSeccion(
      titulo: titulo,
      children: map.entries.map((e) => _buildCampo(e.key, e.value)).toList(),
    );
  }

  Widget _buildCampo(String key, dynamic value) {
    final label = key
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');

    if (value == null || (value is String && value.isEmpty)) {
      return _row(label, '—');
    }
    if (value is List) {
      if (value.isEmpty) return _row(label, '—');
      if (value.first is Map) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: kTextMuted)),
            ),
            ...value.map((item) {
              final m = Map<String, dynamic>.from(item as Map);
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kBackground,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: m.entries.map((e) =>
                      Text('${e.key}: ${e.value ?? "—"}',
                          style: const TextStyle(fontSize: 12))).toList(),
                ),
              );
            }),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: kTextMuted)),
          ),
          ...value.map((v) => Padding(
            padding: const EdgeInsets.only(bottom: 2, left: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(color: kTextMuted)),
                Expanded(child: Text(v.toString(), style: const TextStyle(fontSize: 12))),
              ],
            ),
          )),
        ],
      );
    }
    return _row(label, value.toString());
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: kTextMuted)),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
      ],
    ),
  );
}

// ── Card con header de sección (estilo Stitch) ────────────────────────────────

class _SgaCard extends StatelessWidget {
  final String titulo;
  final IconData icon;
  final Color headerColor;
  final Widget child;
  final EdgeInsets? padding;

  const _SgaCard({
    required this.titulo,
    required this.icon,
    required this.headerColor,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: Colors.white,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: headerColor,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(titulo, style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ]),
          ),
          Padding(
            padding: padding ?? const EdgeInsets.all(14),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ── Sección acordeón para Colmena ARL ─────────────────────────────────────────

class _ColmenaSeccion extends StatefulWidget {
  final String titulo;
  final List<Widget> children;
  const _ColmenaSeccion({required this.titulo, required this.children});

  @override
  State<_ColmenaSeccion> createState() => _ColmenaSeccionState();
}

class _ColmenaSeccionState extends State<_ColmenaSeccion> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              color: kPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                const Icon(Icons.assignment_outlined, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.titulo, style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white, size: 20),
              ]),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.children,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Diálogo de confirmación de extracción FDS ─────────────────────────────────

class _DialogConfirmacionFDS extends StatelessWidget {
  final List<Map<String, dynamic>> diff;
  final List<Map<String, dynamic>> camposVacios;
  final bool sinDatosPrevios;
  final int totalCambios;

  const _DialogConfirmacionFDS({
    required this.diff,
    required this.camposVacios,
    required this.sinDatosPrevios,
    required this.totalCambios,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.science_outlined, color: kPrimary, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            sinDatosPrevios ? 'Primera extracción SGA' : 'Confirmar cambios SGA',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ]),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Resumen ────────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: kPrimary.withValues(alpha: 0.25)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline, color: kPrimary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      sinDatosPrevios
                          ? 'Se crearán los datos SGA por primera vez ($totalCambios campos).'
                          : '$totalCambios campo(s) cambiarán respecto a los datos actuales.',
                      style: const TextStyle(fontSize: 13, color: kPrimary),
                    ),
                  ),
                ]),
              ),

              // ── Diff ───────────────────────────────────────────────────────
              if (diff.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('Cambios detectados',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                ...diff.map((e) => _buildDiffRow(e)),
              ],

              // ── Campos vacíos ──────────────────────────────────────────────
              if (camposVacios.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: kSemaforoAmarillo, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '${camposVacios.length} campo(s) sin datos en la FDS',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13, color: kSemaforoAmarillo),
                  ),
                ]),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: camposVacios.map((e) => Chip(
                    label: Text(e['etiqueta']?.toString() ?? e['campo'],
                        style: const TextStyle(fontSize: 11)),
                    backgroundColor: kSemaforoAmarillo.withValues(alpha: 0.12),
                    side: BorderSide(color: kSemaforoAmarillo.withValues(alpha: 0.4)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  )).toList(),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Aplicar extracción'),
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimary,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
  }

  Widget _buildDiffRow(Map<String, dynamic> e) {
    final esNuevo = e['valor_actual'] == null ||
        e['valor_actual'] == '' ||
        e['valor_actual'] == [];
    final etiqueta = e['etiqueta']?.toString() ?? e['campo'];
    final valorNuevo = _resumir(e['valor_nuevo']);
    final valorActual = esNuevo ? null : _resumir(e['valor_actual']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.edit_outlined, size: 13, color: kTextMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etiqueta,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                if (esNuevo)
                  const Text('nuevo', style: TextStyle(fontSize: 11, color: kSuccess))
                else ...[
                  Text(valorActual ?? '—',
                      style: const TextStyle(
                          fontSize: 11, color: kTextMuted,
                          decoration: TextDecoration.lineThrough)),
                  Row(children: [
                    const Icon(Icons.arrow_forward, size: 11, color: kPrimary),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(valorNuevo,
                          style: const TextStyle(fontSize: 11, color: kPrimary)),
                    ),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _resumir(dynamic valor) {
    if (valor == null) return '—';
    if (valor is List) {
      if (valor.isEmpty) return '—';
      final s = valor.map((e) => e is Map ? e.values.first : e).join(', ');
      return s.length > 80 ? '${s.substring(0, 80)}…' : s;
    }
    final s = valor.toString();
    return s.length > 80 ? '${s.substring(0, 80)}…' : s;
  }
}
