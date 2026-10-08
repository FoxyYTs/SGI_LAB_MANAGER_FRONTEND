/// Helpers del filtro por rango de fechas del historial (préstamos y
/// bitácora). El backend recibe `?desde=AAAA-MM-DD&hasta=AAAA-MM-DD`,
/// fechas locales de Bogotá e inclusivas.
library;

import 'package:flutter/material.dart';

String _dos(int n) => n.toString().padLeft(2, '0');

/// `2026-10-05` — formato que espera el backend.
String fechaApi(DateTime d) => '${d.year}-${_dos(d.month)}-${_dos(d.day)}';

/// `05/10/2026` — formato para mostrar.
String fechaCorta(DateTime d) => '${_dos(d.day)}/${_dos(d.month)}/${d.year}';

/// Parámetros `desde`/`hasta` para [rango] (vacío si es null).
Map<String, String> paramsRango(DateTimeRange? rango) => rango == null
    ? const {}
    : {'desde': fechaApi(rango.start), 'hasta': fechaApi(rango.end)};

/// Texto del chip: un solo día o "inicio – fin".
String etiquetaRango(DateTimeRange r) =>
    DateUtils.isSameDay(r.start, r.end)
        ? fechaCorta(r.start)
        : '${fechaCorta(r.start)} – ${fechaCorta(r.end)}';
