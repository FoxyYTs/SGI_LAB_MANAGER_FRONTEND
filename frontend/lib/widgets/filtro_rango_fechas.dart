import 'package:flutter/material.dart';
import '../core/rango_fechas.dart';
import '../core/theme/colors.dart';

/// Botón "Fechas" que abre un selector de rango y, si hay uno elegido, se
/// muestra como chip con la "x" para limpiarlo. Se usa en el historial de
/// préstamos y en la bitácora.
class FiltroRangoFechas extends StatelessWidget {
  final DateTimeRange? rango;
  final ValueChanged<DateTimeRange?> onChanged;

  const FiltroRangoFechas({super.key, required this.rango, required this.onChanged});

  Future<void> _elegir(BuildContext context) async {
    final hoy = DateUtils.dateOnly(DateTime.now());
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: hoy,
      initialDateRange: rango,
      helpText: 'Rango de fechas',
      saveText: 'Aplicar',
      cancelText: 'Cancelar',
      fieldStartLabelText: 'Desde',
      fieldEndLabelText: 'Hasta',
    );
    if (r != null) onChanged(r);
  }

  @override
  Widget build(BuildContext context) {
    final r = rango;
    if (r == null) {
      return ActionChip(
        avatar: const Icon(Icons.date_range, size: 16, color: kPrimary),
        label: const Text('Fechas', style: TextStyle(fontSize: 12, color: kPrimary)),
        tooltip: 'Filtrar por rango de fechas',
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFDEE2E6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onPressed: () => _elegir(context),
      );
    }
    return InputChip(
      avatar: const Icon(Icons.date_range, size: 16, color: Colors.white),
      label: Text(etiquetaRango(r),
          style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
      backgroundColor: kPrimary,
      side: const BorderSide(color: kPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white),
      deleteButtonTooltipMessage: 'Quitar filtro de fechas',
      onDeleted: () => onChanged(null),
      onPressed: () => _elegir(context),
    );
  }
}
