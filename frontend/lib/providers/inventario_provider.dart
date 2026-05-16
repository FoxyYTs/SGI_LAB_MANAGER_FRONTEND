import 'package:flutter/material.dart';
import '../models/insumo_model.dart';
import '../repositories/insumo_repository.dart';

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
