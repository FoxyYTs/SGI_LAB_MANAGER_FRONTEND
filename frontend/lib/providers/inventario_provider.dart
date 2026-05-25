import 'package:flutter/material.dart';
import '../models/insumo_model.dart';
import '../repositories/insumo_repository.dart';

/// Proveedor de estado para el listado de insumos del inventario.
///
/// Delega la obtención de datos a [InsumoRepository], que implementa
/// la estrategia "servidor primero, caché offline como fallback".
/// El campo [desdeCache] indica si la última carga provino del SQLite local
/// (servidor no disponible) para que la UI pueda mostrarlo al usuario.
class InventarioProvider with ChangeNotifier {
  final _repo = InsumoRepository();

  List<Insumo> _insumos   = [];
  bool         _cargando  = false;
  bool         _desdeCache = false;
  DateTime?    _lastSync;

  List<Insumo> get insumos    => _insumos;
  bool         get cargando   => _cargando;
  bool         get desdeCache => _desdeCache;
  DateTime?    get lastSync   => _lastSync;

  /// Carga el inventario desde el servidor (o caché si no hay red).
  /// Actualiza [desdeCache] según si el timestamp de sync cambió.
  Future<void> fetchInsumos(String? token) async {
    _cargando = true;
    notifyListeners();

    final antes = await _repo.lastSync();
    _insumos  = await _repo.fetchInsumos(token);
    _lastSync = await _repo.lastSync();

    // Si last_sync no cambió es porque falló el server y se usó caché
    _desdeCache = (antes != null) && (_lastSync == antes);

    _cargando = false;
    notifyListeners();
  }
}
