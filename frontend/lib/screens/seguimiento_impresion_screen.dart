import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/impresion_calculo.dart';
import '../core/theme/app_theme.dart';
import '../widgets/error_carga.dart';

/// Página pública (sin login) que abre el QR de un encargo de impresión 3D:
///   FRONTEND_URL/?c=CODIGO#/seguimiento
/// Muestra cuánto se ha pagado y en qué va el trabajo. El backend solo
/// devuelve el nombre abreviado del cliente, nunca documento ni contacto.
class SeguimientoImpresionScreen extends StatefulWidget {
  const SeguimientoImpresionScreen({super.key});

  @override
  State<SeguimientoImpresionScreen> createState() => _SeguimientoImpresionScreenState();
}

class _SeguimientoImpresionScreenState extends State<SeguimientoImpresionScreen> {
  final _dio = Dio(BaseOptions(
    baseUrl: ApiClient.instance.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));
  final _codigo = kIsWeb ? Uri.base.queryParameters['c'] ?? '' : '';
  Map<String, dynamic>? _datos;
  String? _error;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      if (_codigo.isEmpty) throw StateError('sin código');
      final r = await _dio.get('operaciones/seguimiento-impresion/${Uri.encodeComponent(_codigo)}/');
      _datos = Map<String, dynamic>.from(r.data);
    } catch (e) {
      final noExiste = e is StateError || (e is DioException && e.response?.statusCode == 404);
      _error = noExiste
          ? 'No encontramos este encargo. Revisa el enlace o pide un QR nuevo en el laboratorio.'
          : mensajeErrorCarga(e, 'el encargo');
    }
    if (mounted) setState(() => _cargando = false);
  }

  static num _num(Object? v) => num.tryParse('$v') ?? 0;

  static String _fecha(Object? iso) {
    final f = DateTime.tryParse('${iso ?? ''}')?.toLocal();
    return f == null ? '' : '${f.day}/${f.month}/${f.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      color: context.sgi.brandBar,
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                      child: const Column(
                        children: [
                          Icon(Icons.view_in_ar_outlined, color: Colors.white, size: 36),
                          SizedBox(height: 8),
                          Text(
                            'Seguimiento de impresión 3D',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Padding(padding: const EdgeInsets.all(20), child: _cuerpo()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cuerpo() {
    if (_cargando) return Center(child: CircularProgressIndicator(color: context.sgi.accent));
    if (_error != null) return ErrorCargaReintentar(mensaje: _error!, onReintentar: _cargar);
    final d = _datos!;
    final cs = Theme.of(context).colorScheme;
    final total = _num(d['total']), abonado = _num(d['abonado']);
    final estadoPago = '${d['estado_pago']}';
    final colorPago = switch (estadoPago) {
      'PAGADO' => context.sgi.success,
      'ABONADO' => context.sgi.warning,
      _ => context.sgi.orange,
    };
    final pasos = estadosTrabajoImpresion.keys.toList();
    final paso = pasos.indexOf('${d['estado']}');
    final abonos = (d['abonos'] as List? ?? []).cast<Map<String, dynamic>>();
    final piezas = (d['piezas'] as List? ?? []).cast<String>();
    Widget fila(String etiqueta, String valor, {bool fuerte = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(etiqueta, style: TextStyle(color: cs.onSurfaceVariant)),
          const Spacer(),
          Text(valor, style: TextStyle(fontWeight: fuerte ? FontWeight.bold : FontWeight.w500)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${d['cliente']}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        Text(
          [
            'Encargado el ${_fecha(d['fecha_hora'])}',
            if (d['urgente'] == true) 'Urgente',
          ].join(' · '),
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Text('Pago', style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: context.sgi.tileBg(colorPago), borderRadius: BorderRadius.circular(10)),
              child: Text(
                estadosPagoImpresion[estadoPago] ?? estadoPago,
                style: TextStyle(fontWeight: FontWeight.w600, color: colorPago),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Semantics(
          label: 'Pagado ${formatoPesos(abonado)} de ${formatoPesos(total)}',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total > 0 ? (abonado / total).clamp(0, 1).toDouble() : 0,
              minHeight: 10,
              color: colorPago,
              backgroundColor: cs.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(height: 8),
        fila('Total', formatoPesos(total)),
        fila('Abonado', formatoPesos(abonado)),
        fila('Saldo pendiente', formatoPesos(_num(d['saldo'])), fuerte: true),
        if (estadoPago != 'PAGADO' && _num(d['anticipo']) > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              d['anticipo_cubierto'] == true
                  ? 'Anticipo cubierto.'
                  : 'Anticipo sugerido: ${formatoPesos(_num(d['anticipo']))}.',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ),
        if (abonos.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final a in abonos)
            Text(
              '${_fecha(a['fecha'])} — ${formatoPesos(_num(a['monto']))}',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
        ],
        const SizedBox(height: 20),
        const Text('Trabajo', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        for (var i = 0; i < pasos.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Icon(
                  i <= paso ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 20,
                  color: i <= paso ? context.sgi.success : cs.outline,
                ),
                const SizedBox(width: 10),
                Text(
                  estadosTrabajoImpresion[pasos[i]]!,
                  style: TextStyle(
                    fontWeight: i == paso ? FontWeight.w600 : FontWeight.normal,
                    color: i <= paso ? null : cs.onSurfaceVariant,
                  ),
                ),
                if (i == paso && pasos[i] == 'ENTREGADO' && d['fecha_entrega'] != null)
                  Text(
                    '  ${_fecha(d['fecha_entrega'])}',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        Text('Piezas (${piezas.length})', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        for (final p in piezas) Text('• $p'),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(onPressed: _cargar, icon: const Icon(Icons.refresh), label: const Text('Actualizar')),
        ),
      ],
    );
  }
}
