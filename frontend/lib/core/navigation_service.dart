import 'package:flutter/material.dart';

/// Clave global del navigator para poder navegar desde fuera del árbol de widgets
/// (p. ej. desde el interceptor Dio al recibir un 426 Upgrade Required).
final navigatorKey = GlobalKey<NavigatorState>();
