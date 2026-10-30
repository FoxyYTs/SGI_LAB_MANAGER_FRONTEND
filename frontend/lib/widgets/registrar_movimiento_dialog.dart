import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api/api_client.dart';
import '../core/presentaciones.dart';
import '../core/sync/sync_errores.dart';
import '../core/text_utils.dart';
import '../core/theme/colors.dart';
import '../models/insumo_model.dart';
import '../providers/auth_provider.dart';
import '../providers/inventario_provider.dart';

/// Movimientos de stock que el personal registra a mano desde la app
/// (POST `operaciones/bitacora/`, permiso `bitacora.gestionar`).
///
/// Para un residuo: ENTRADA = se generó residuo (p. ej. en una práctica),
/// SALIDA = se entregó al gestor externo.
enum MovimientoStock {
  entrada('ENTRADA'),
  salida('SALIDA');

  final String codigo;
  const MovimientoStock(this.codigo);

  /// Texto del botón / título del diálogo.
  String etiqueta({required bool esResiduo}) => switch (this) {
        MovimientoStock.entrada => 'Registrar entrada',
        MovimientoStock.salida =>
          esResiduo ? 'Entregar al gestor' : 'Registrar salida',
      };

  IconData get icono => switch (this) {
        MovimientoStock.entrada => Icons.add_box_outlined,
        MovimientoStock.salida  => Icons.outbox_outlined,
      };

  Color get color => switch (this) {
        MovimientoStock.entrada => kSuccess,
        MovimientoStock.salida  => kPrimary,
      };
}

/// Resultado de un movimiento guardado.
class ResultadoMovimiento {
  /// Stock de la presentación después del movimiento (null si no se sabe).
  final double? stockResultante;
  final String unidad;
  const ResultadoMovimiento({this.stockResultante, required this.unidad});
}

/// Envía el cuerpo del POST y devuelve la respuesta del backend. Lanza
/// [DioException] si falla. Inyectable para los tests.
typedef EnviarMovimiento = Future<dynamic> Function(Map<String, dynamic> body);

/// Formatea una cantidad sin decimales sobrantes (12 → "12", 2.5 → "2.5").
String fmtCantidad(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

/// Interpreta la cantidad escrita (acepta coma decimal). null si no es un
/// número.
double? parseCantidad(String texto) =>
    double.tryParse(texto.trim().replaceAll(',', '.'));

/// Valida la cantidad de un movimiento: número > 0, con 2 decimales como
/// máximo y dentro de lo que admite la BD (DecimalField(10, 2)).
String? validarCantidad(String? texto) {
  final t = (texto ?? '').trim().replaceAll(',', '.');
  if (t.isEmpty) return 'Escribe la cantidad';
  final v = double.tryParse(t);
  if (v == null || v.isNaN || v.isInfinite) return 'Cantidad no válida';
  if (v <= 0) return 'Debe ser mayor a 0';
  final partes = t.split('.');
  if (partes.length == 2 && partes[1].length > 2) {
    return 'Máximo 2 decimales';
  }
  if (v >= 100000000) return 'Cantidad demasiado grande';
  return null;
}

/// Primer mensaje legible de un error del backend (DRF manda `{"error":…}`,
/// `{"detail":…}` o `{"campo": ["…"]}`).
String mensajeErrorApi(Object e) {
  if (e is DioException) {
    dynamic d = e.response?.data;
    while (true) {
      if (d is Map && d.isNotEmpty) {
        d = d['error'] ?? d['detail'] ?? d.values.first;
      } else if (d is List && d.isNotEmpty) {
        d = d.first;
      } else {
        break;
      }
    }
    final txt = d is String ? d.trim() : '';
    if (txt.isNotEmpty) return txt;
    if (esFalloDeRed(e)) {
      return 'No se pudo conectar con el servidor. Revisa tu conexión.';
    }
    final code = e.response?.statusCode;
    if (code == 403) return 'No tienes permiso para registrar movimientos.';
    return code != null ? 'Error del servidor ($code).' : 'Error de red.';
  }
  return e.toString();
}

/// Diálogo para registrar una ENTRADA o SALIDA de stock de un insumo.
///
/// Hace el POST él mismo (con guarda contra doble envío) y se cierra solo
/// si el backend lo aceptó, devolviendo un [ResultadoMovimiento]. Si el
/// backend lo rechaza (p. ej. salida mayor al stock) muestra su mensaje y
/// queda abierto para corregir.
class RegistrarMovimientoDialog extends StatefulWidget {
  final String insumoNombre;
  final bool esResiduo;
  final MovimientoStock tipo;

  /// Presentaciones del insumo (como llegan del detalle). Solo se ofrecen
  /// las activas.
  final List presentaciones;
  final EnviarMovimiento enviar;

  const RegistrarMovimientoDialog({
    super.key,
    required this.insumoNombre,
    required this.esResiduo,
    required this.tipo,
    required this.presentaciones,
    required this.enviar,
  });

  @override
  State<RegistrarMovimientoDialog> createState() =>
      _RegistrarMovimientoDialogState();
}

class _RegistrarMovimientoDialogState extends State<RegistrarMovimientoDialog> {
  final _formKey  = GlobalKey<FormState>();
  final _cantCtrl = TextEditingController();
  final _obsCtrl  = TextEditingController();
  late final List<Map<String, dynamic>> _activas;
  String? _presId;
  bool _enviando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _activas = presentacionesActivas(widget.presentaciones);
    // Con una sola presentación no hay nada que elegir; con varias se
    // obliga a elegir para no cargar el movimiento a la equivocada.
    if (_activas.length == 1) _presId = _activas.first['id'].toString();
  }

  @override
  void dispose() {
    _cantCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get _pres => _presId == null
      ? null
      : _activas.firstWhere((p) => p['id'].toString() == _presId,
          orElse: () => const {});

  String get _unidad => _pres?['unidad_nombre']?.toString() ?? '';

  static double? _stockDe(Map? p) =>
      double.tryParse(p?['stock_actual']?.toString() ?? '');

  String _etiquetaPres(Map<String, dynamic> p) {
    final stock = _stockDe(p);
    final u = p['unidad_nombre']?.toString() ?? '';
    return stock == null ? u : '$u — ${widget.esResiduo ? 'acumulado' : 'stock'} ${fmtCantidad(stock)}';
  }

  String get _ayudaObservacion {
    if (widget.esResiduo) {
      return widget.tipo == MovimientoStock.entrada
          ? 'Práctica / asignatura de origen'
          : 'Gestor y n.º de manifiesto';
    }
    return widget.tipo == MovimientoStock.entrada
        ? 'Proveedor, factura, donación…'
        : 'Motivo o destino de la salida';
  }

  Future<void> _guardar() async {
    if (_enviando) return; // guarda contra doble toque
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final pres = _pres;
    if (pres == null) return;
    final cantidad = parseCantidad(_cantCtrl.text)!;
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final data = await widget.enviar({
        'presentacion':    _presId,
        'tipo_movimiento': widget.tipo.codigo,
        // Como texto: el backend es DecimalField y así no viajan
        // artefactos de coma flotante (0.1 + 0.2…).
        'cantidad':        _cantCtrl.text.trim().replaceAll(',', '.'),
        'observaciones':   _obsCtrl.text.trim(),
      });
      // Un backend anterior no devuelve stock_posterior: se estima con el
      // stock que se conocía.
      double? resultante = data is Map
          ? double.tryParse(data['stock_posterior']?.toString() ?? '')
          : null;
      final previo = _stockDe(pres);
      if (resultante == null && previo != null) {
        resultante = widget.tipo == MovimientoStock.entrada
            ? previo + cantidad
            : previo - cantidad;
      }
      if (!mounted) return;
      Navigator.of(context).pop(
          ResultadoMovimiento(stockResultante: resultante, unidad: _unidad));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _error = mensajeErrorApi(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final titulo = widget.tipo.etiqueta(esResiduo: widget.esResiduo);
    final color  = widget.tipo.color;
    return PopScope(
      canPop: !_enviando,
      child: AlertDialog(
        title: Row(children: [
          Icon(widget.tipo.icono, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(titulo, style: TextStyle(color: color, fontSize: 15)),
          ),
        ]),
        content: SizedBox(
          width: 380,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Insumo: ${widget.insumoNombre}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  if (widget.esResiduo) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.tipo == MovimientoStock.entrada
                          ? 'Suma al residuo acumulado (residuo generado).'
                          : 'Descuenta lo entregado al gestor externo.',
                      style: const TextStyle(fontSize: 12, color: kTextMuted),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (_activas.length > 1) ...[
                    DropdownButtonFormField<String>(
                      key: const ValueKey('mov-presentacion'),
                      initialValue: _presId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Presentación *',
                        prefixIcon: Icon(Icons.inventory_2_outlined, size: 18),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _activas
                          .map((p) => DropdownMenuItem(
                                value: p['id'].toString(),
                                child: Text(_etiquetaPres(p),
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      validator: (v) =>
                          v == null ? 'Elige la presentación' : null,
                      onChanged: _enviando
                          ? null
                          : (v) => setState(() => _presId = v),
                    ),
                    const SizedBox(height: 10),
                  ] else if (_pres != null) ...[
                    Text('Presentación: ${_etiquetaPres(_pres!)}',
                        style: const TextStyle(
                            fontSize: 12, color: kTextMuted)),
                    const SizedBox(height: 10),
                  ],
                  TextFormField(
                    key: const ValueKey('mov-cantidad'),
                    controller: _cantCtrl,
                    autofocus: true,
                    enabled: !_enviando,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText:
                          'Cantidad${_unidad.isNotEmpty ? ' ($_unidad)' : ''} *',
                      prefixIcon: const Icon(Icons.numbers, size: 18),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: validarCantidad,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const ValueKey('mov-observaciones'),
                    controller: _obsCtrl,
                    enabled: !_enviando,
                    maxLines: 2,
                    maxLength: 500,
                    decoration: InputDecoration(
                      labelText: 'Observación (opcional)',
                      hintText: _ayudaObservacion,
                      prefixIcon: const Icon(Icons.notes_outlined, size: 18),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kDanger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(_error!,
                          key: const ValueKey('mov-error'),
                          style: const TextStyle(color: kDanger, fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _enviando ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            key: const ValueKey('mov-guardar'),
            style: ElevatedButton.styleFrom(
                backgroundColor: color, foregroundColor: Colors.white),
            onPressed: _enviando ? null : _guardar,
            child: _enviando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

/// Abre el diálogo para [insumo] (JSON del detalle `inventario/lista/<id>/`)
/// y, si se guardó, avisa con el stock resultante. Devuelve true si se
/// registró el movimiento.
Future<bool> registrarMovimientoStock(
  BuildContext context, {
  required Map<String, dynamic> insumo,
  required MovimientoStock tipo,
}) async {
  final nombre = insumo['nombre_insumo']?.toString() ?? '';
  final esResiduo = insumo['tipo_nombre'] == kTipoResiduo;
  final presentaciones = insumo['presentaciones'] as List? ?? const [];
  final messenger = ScaffoldMessenger.of(context);
  if (presentacionesActivas(presentaciones).isEmpty) {
    messenger.showSnackBar(const SnackBar(
        content: Text('Este insumo no tiene presentaciones activas: '
            'agrega o reactiva una antes de registrar movimientos.'),
        backgroundColor: kDanger));
    return false;
  }
  final token = context.read<AuthProvider>().token;
  final resultado = await showDialog<ResultadoMovimiento>(
    context: context,
    barrierDismissible: false,
    builder: (_) => RegistrarMovimientoDialog(
      insumoNombre: nombre,
      esResiduo: esResiduo,
      tipo: tipo,
      presentaciones: presentaciones,
      enviar: (body) async {
        final r = await ApiClient.instance
            .authenticatedDio(token)
            .post('operaciones/bitacora/', data: body);
        return r.data;
      },
    ),
  );
  if (resultado == null) return false;
  final hecho = switch (tipo) {
    MovimientoStock.entrada => 'Entrada registrada',
    MovimientoStock.salida =>
      esResiduo ? 'Entrega al gestor registrada' : 'Salida registrada',
  };
  final stock = resultado.stockResultante;
  messenger.showSnackBar(SnackBar(
    content: Text(stock == null
        ? '$hecho.'
        : '$hecho. ${esResiduo ? 'Acumulado' : 'Stock'} de "$nombre" '
            '(${resultado.unidad}): ${fmtCantidad(stock)}.'),
    backgroundColor: kSuccess,
  ));
  return true;
}

/// Flujo desde el inicio: elegir el insumo con un buscador, traer su
/// detalle actualizado (presentaciones y stock) y abrir el mismo diálogo.
/// Devuelve true si se registró el movimiento.
Future<bool> buscarInsumoYRegistrarMovimiento(
  BuildContext context, {
  required MovimientoStock tipo,
}) async {
  final auth = context.read<AuthProvider>();
  final inv = context.read<InventarioProvider>();
  final messenger = ScaffoldMessenger.of(context);
  if (inv.insumos.isEmpty && !inv.cargando) {
    await inv.fetchInsumos(auth.token);
  }
  if (!context.mounted) return false;
  final elegido = await showDialog<Insumo>(
    context: context,
    builder: (_) => SelectorInsumoMovimientoDialog(
      tipo: tipo,
      insumos: inv.insumos.where((i) => i.activo).toList(),
    ),
  );
  if (elegido == null || !context.mounted) return false;

  Map<String, dynamic> detalle;
  try {
    final r = await ApiClient.instance
        .authenticatedDio(auth.token)
        .get('inventario/lista/${elegido.id}/');
    detalle = Map<String, dynamic>.from(r.data as Map);
  } catch (e) {
    messenger.showSnackBar(SnackBar(
        content: Text('No se pudo cargar "${elegido.nombre}": ${mensajeErrorApi(e)}'),
        backgroundColor: kDanger));
    return false;
  }
  if (!context.mounted) return false;
  final ok = await registrarMovimientoStock(context, insumo: detalle, tipo: tipo);
  // El listado del inventario quedó con el stock viejo.
  if (ok) inv.fetchInsumos(auth.token);
  return ok;
}

/// Buscador de insumos para registrar una entrada/salida. Incluye los
/// residuos (para ellos la salida es la entrega al gestor).
class SelectorInsumoMovimientoDialog extends StatefulWidget {
  final MovimientoStock tipo;
  final List<Insumo> insumos;
  const SelectorInsumoMovimientoDialog(
      {super.key, required this.tipo, required this.insumos});

  @override
  State<SelectorInsumoMovimientoDialog> createState() =>
      _SelectorInsumoMovimientoDialogState();
}

class _SelectorInsumoMovimientoDialogState
    extends State<SelectorInsumoMovimientoDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = normalizarBusqueda(_query);
    final filtrados = widget.insumos
        .where((i) =>
            normalizarBusqueda(i.nombre).contains(q) ||
            normalizarBusqueda(i.tipo).contains(q))
        .toList()
      ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));

    return AlertDialog(
      title: Text(
        widget.tipo == MovimientoStock.entrada
            ? 'Registrar entrada — elige el insumo'
            : 'Registrar salida — elige el insumo',
        style: const TextStyle(color: kPrimary, fontSize: 15),
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      content: SizedBox(
        width: 420,
        height: 400,
        child: Column(children: [
          TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: 'Buscar por nombre o tipo (p. ej. Residuo)…',
              prefixIcon: Icon(Icons.search, color: kPrimary, size: 18),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtrados.isEmpty
                ? const Center(
                    child: Text('Sin resultados',
                        style: TextStyle(color: kTextMuted)))
                : ListView.builder(
                    itemCount: filtrados.length,
                    itemBuilder: (_, i) {
                      final ins = filtrados[i];
                      final cifra = '${fmtCantidad(ins.stockActual)} ${ins.unidad}'.trim();
                      return ListTile(
                        dense: true,
                        leading: Icon(
                            ins.esResiduo
                                ? Icons.delete_outline
                                : Icons.inventory_2_outlined,
                            size: 18,
                            color: ins.esResiduo
                                ? const Color(0xFF6D4C41)
                                : kTextMuted),
                        title: Text(ins.nombre,
                            style: const TextStyle(fontSize: 13)),
                        subtitle: Text(
                            '${ins.tipo} · ${ins.esResiduo ? 'Acumulado' : 'Stock'}: $cifra',
                            style: const TextStyle(fontSize: 11)),
                        onTap: () => Navigator.pop(context, ins),
                      );
                    },
                  ),
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
      ],
    );
  }
}
