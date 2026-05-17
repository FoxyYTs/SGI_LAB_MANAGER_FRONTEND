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

    setState(() { _extrayendo = true; });
    try {
      final formData = FormData.fromMap({
        'fds': MultipartFile.fromBytes(bytes, filename: file.name),
      });
      final r = await _dio.post(
        'inventario/lista/${widget.insumoId}/sga/extraer-fds/',
        data: formData,
        options: Options(receiveTimeout: const Duration(seconds: 60)),
      );
      setState(() { _datos = Map<String, dynamic>.from(r.data['datos']); _colmena = null; });
      _snack('Extracción completada exitosamente.', kSuccess);
    } on DioException catch (e) {
      _snack(e.response?.data?['detail'] ?? 'Error al procesar el PDF.', kDanger);
    } finally {
      setState(() { _extrayendo = false; });
    }
  }

  Future<void> _abrirEtiquetaUrl() async {
    // La URL de la etiqueta requiere auth; abrimos con token en header no es posible
    // desde navegador. En su lugar construimos la URL con el token como query param
    // (el backend podría soportarlo). Por ahora informamos al usuario.
    final url = Uri.parse(
      '${ApiClient.instance.baseUrl}inventario/lista/${widget.insumoId}/sga/etiqueta-pdf/',
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
    if (datos.isEmpty) {
      return _buildEmpty(context);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBanner(datos),
          const SizedBox(height: 12),
          _buildPictogramas(datos),
          const SizedBox(height: 12),
          if ((datos['frases_h'] as List?)?.isNotEmpty == true) ...[
            _buildSeccion('Frases H — Indicaciones de peligro',
                Icons.warning_amber_rounded, kDanger),
            ...(datos['frases_h'] as List).map((f) => _buildBullet(f.toString())),
            const SizedBox(height: 8),
          ],
          if ((datos['frases_p'] as List?)?.isNotEmpty == true) ...[
            _buildSeccion('Frases P — Consejos de prudencia',
                Icons.shield_outlined, kPrimary),
            ...(datos['frases_p'] as List).map((f) => _buildBullet(f.toString())),
            const SizedBox(height: 8),
          ],
          if (datos['epp']?.toString().isNotEmpty == true) ...[
            _buildSeccion('EPP', Icons.security_outlined, kTextMuted),
            _buildCard(datos['epp'].toString()),
          ],
          if (datos['primeros_auxilios']?.toString().isNotEmpty == true) ...[
            _buildSeccion('Primeros auxilios', Icons.medical_services_outlined, kSuccess),
            _buildCard(datos['primeros_auxilios'].toString()),
          ],
          // ── NFPA 704 ────────────────────────────────────────────────────────
          if (datos['nfpa_salud'] != null || datos['nfpa_inflamable'] != null ||
              datos['nfpa_reactivo'] != null) ...[
            _buildSeccion('Rombo NFPA 704', Icons.emergency_outlined, const Color(0xFF8B0000)),
            const SizedBox(height: 6),
            _buildNfpa(datos),
            const SizedBox(height: 8),
          ],

          if (datos['fecha_vencimiento']?.toString().isNotEmpty == true) ...[
            _buildSeccion('Fecha de vencimiento', Icons.event_outlined, kTextMuted),
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 4),
              child: Text(datos['fecha_vencimiento'].toString(),
                  style: const TextStyle(fontSize: 13)),
            ),
          ],

          if (datos['fds_drive_url']?.toString().isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Ver FDS en Google Drive'),
                onPressed: () async {
                  final uri = Uri.parse(datos['fds_drive_url'].toString());
                  if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
                },
              ),
            ),
          const SizedBox(height: 24),
          if (datos['datos_extraidos'] == true)
            Text(
              'Datos extraídos automáticamente con Gemini AI · ${datos['fecha_extraccion']?.toString().substring(0, 10) ?? ''}',
              style: const TextStyle(color: kTextMuted, fontSize: 11),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.science_outlined, size: 64, color: kTextMuted),
        const SizedBox(height: 12),
        const Text('Sin datos SGA cargados',
            style: TextStyle(fontSize: 16, color: kTextMuted)),
        const SizedBox(height: 8),
        const Text('Sube la FDS (PDF) para extraer datos automáticamente',
            style: TextStyle(color: kTextMuted, fontSize: 13),
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.upload_file),
          label: const Text('Subir FDS'),
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimary, foregroundColor: Colors.white),
          onPressed: () => (context.findAncestorStateOfType<_SgaScreenState>())?._extraerFDS(),
        ),
      ],
    ),
  );

  Widget _buildBanner(Map<String, dynamic> d) {
    final pwa = d['palabra_advertencia']?.toString() ?? '';
    final color = pwa == 'PELIGRO' ? kDanger : kSemaforoAmarillo;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (pwa.isNotEmpty)
                  Text(pwa, style: TextStyle(
                      fontWeight: FontWeight.bold, color: color, fontSize: 18)),
                Text(d['nombre_producto']?.toString() ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (d['numero_cas']?.toString().isNotEmpty == true)
                  Text('CAS: ${d['numero_cas']}',
                      style: const TextStyle(color: kTextMuted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPictogramas(Map<String, dynamic> d) {
    final pics = (d['pictogramas_sga'] as List?)?.cast<String>() ?? [];
    if (pics.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: pics.map((code) {
        final info = _ghsInfo[code];
        final emoji  = info?.$1 ?? '?';
        final label  = info?.$2 ?? code;
        final color  = info?.$3 ?? Colors.grey;
        return Container(
          width: 72,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(8),
            color: color.withOpacity(0.07),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 4),
              Text(code, style: TextStyle(
                  fontSize: 9, color: color, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(fontSize: 9, color: kTextMuted),
                  textAlign: TextAlign.center, maxLines: 2),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSeccion(String title, IconData icon, Color color) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 4),
    child: Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
    ]),
  );

  Widget _buildBullet(String text) => Padding(
    padding: const EdgeInsets.only(left: 8, bottom: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ', style: TextStyle(color: kTextMuted)),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    ),
  );

  Widget _buildCard(String text) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 4),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: const Color(0xFFDEE2E6)),
    ),
    child: Text(text, style: const TextStyle(fontSize: 13)),
  );

  Widget _buildNfpa(Map<String, dynamic> d) {
    Widget cell(String label, dynamic val, Color bg) => Container(
      width: 56, height: 56,
      color: bg,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(val?.toString() ?? '–',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 8)),
      ]),
    );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      cell('SALUD',      d['nfpa_salud'],      Colors.blue.shade700),
      cell('INFLAM.',    d['nfpa_inflamable'],  Colors.red.shade700),
      cell('REACTIV.',   d['nfpa_reactivo'],    Colors.yellow.shade700),
      cell('ESPEC.',     d['nfpa_corrosivo'] == true ? 'W' : '–', Colors.grey.shade700),
    ]);
  }
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
    for (final c in _c.values) c.dispose();
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
    border: const OutlineInputBorder(),
    focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: kPrimary)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _seccion('Sección 1 — Identificación'),
            TextFormField(controller: _c['nombre_producto'], decoration: _deco('Nombre del producto')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextFormField(controller: _c['formula_quimica'], decoration: _deco('Fórmula química'))),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(controller: _c['numero_cas'], decoration: _deco('Número CAS'))),
            ]),
            const SizedBox(height: 10),
            TextFormField(controller: _c['nombre_proveedor'], decoration: _deco('Nombre del proveedor')),
            const SizedBox(height: 10),
            TextFormField(controller: _c['direccion_proveedor'], decoration: _deco('Dirección del proveedor')),
            const SizedBox(height: 10),
            TextFormField(
              controller: _c['fds_drive_url'],
              decoration: _deco('URL de la FDS en Google Drive'),
              keyboardType: TextInputType.url,
            ),

            _seccion('Sección 2 — Peligros'),
            DropdownButtonFormField<String>(
              value: _c['palabra_advertencia']!.text.isEmpty
                  ? null : _c['palabra_advertencia']!.text,
              decoration: _deco('Palabra de advertencia'),
              items: ['PELIGRO', 'ATENCIÓN'].map((v) =>
                  DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => _c['palabra_advertencia']!.text = v ?? '',
            ),
            const SizedBox(height: 10),
            TextFormField(controller: _c['categoria_toxicidad'],
                decoration: _deco('Categoría de toxicidad (si aplica)')),

            _seccion('Sección 8 — EPP y controles'),
            TextFormField(controller: _c['epp'], decoration: _deco('Elementos de protección personal'),
                maxLines: 3),
            const SizedBox(height: 10),
            TextFormField(controller: _c['controles_tecnicos'],
                decoration: _deco('Controles técnicos'), maxLines: 2),

            _seccion('Secciones 4-6 — Respuesta a emergencias'),
            TextFormField(controller: _c['primeros_auxilios'],
                decoration: _deco('Primeros auxilios'), maxLines: 4),
            const SizedBox(height: 10),
            TextFormField(controller: _c['lucha_incendios'],
                decoration: _deco('Lucha contra incendios'), maxLines: 3),
            const SizedBox(height: 10),
            TextFormField(controller: _c['vertido_accidental'],
                decoration: _deco('Vertido accidental'), maxLines: 3),

            _seccion('Sección 9 — Propiedades físicas'),
            DropdownButtonFormField<String>(
              value: _c['estado_fisico']!.text.isEmpty
                  ? null : _c['estado_fisico']!.text,
              decoration: _deco('Estado físico'),
              items: ['SÓLIDO', 'LÍQUIDO', 'GASEOSO', 'PASTA', 'GEL'].map((v) =>
                  DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => _c['estado_fisico']!.text = v ?? '',
            ),

            _seccion('Sección 10 — Estabilidad'),
            TextFormField(controller: _c['estabilidad_reactividad'],
                decoration: _deco('Estabilidad y reactividad'), maxLines: 3),

            _seccion('Sección 14 — Transporte UN'),
            TextFormField(controller: _c['numero_un'], decoration: _deco('Número UN')),

            _seccion('Rombo NFPA 704'),
            Row(children: [
              Expanded(child: _nfpaDropdown('Salud', _nfpaSalud,
                  (v) => setState(() => _nfpaSalud = v))),
              const SizedBox(width: 10),
              Expanded(child: _nfpaDropdown('Inflamable', _nfpaInflamable,
                  (v) => setState(() => _nfpaInflamable = v))),
              const SizedBox(width: 10),
              Expanded(child: _nfpaDropdown('Reactivo', _nfpaReactivo,
                  (v) => setState(() => _nfpaReactivo = v))),
            ]),
            const SizedBox(height: 10),
            SwitchListTile(
              title: const Text('Corrosivo (W especial)'),
              value: _nfpaCorrosivo,
              activeColor: kPrimary,
              onChanged: (v) => setState(() => _nfpaCorrosivo = v),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),

            _seccion('Vencimiento del lote'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined, color: kPrimary),
              title: Text(_fechaVencimiento != null
                  ? '${_fechaVencimiento!.day.toString().padLeft(2,'0')}/'
                    '${_fechaVencimiento!.month.toString().padLeft(2,'0')}/'
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

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: _guardando
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined),
                label: const Text('Guardar datos SGA'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _seccion(String title) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 10),
    child: Text(title,
        style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimary, fontSize: 14)),
  );

  Widget _nfpaDropdown(String label, int? value, void Function(int?) onChanged) =>
    DropdownButtonFormField<int?>(
      value: value,
      decoration: _deco(label),
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
              color: kPrimary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kPrimary.withOpacity(0.3)),
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
    final map = Map<String, dynamic>.from(value);
    final titulo = map.remove('titulo')?.toString() ?? key;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        title: Text(titulo,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kPrimary)),
        children: map.entries.map((e) => _buildCampo(e.key, e.value)).toList(),
      ),
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
