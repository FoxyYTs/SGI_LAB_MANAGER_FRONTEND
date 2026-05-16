import 'package:flutter/material.dart';
import '../models/insumo_model.dart';
import '../core/api/api_client.dart';

class InventarioProvider with ChangeNotifier {
  List<Insumo> _insumos = [];
  bool _cargando = false;

  List<Insumo> get insumos => _insumos;
  bool get cargando => _cargando;

  Future<void> fetchInsumos(String? token) async {
    _cargando = true;
    notifyListeners();

    try {
      final dio = ApiClient.instance.authenticatedDio(token);
      final response = await dio.get('inventario/lista/');
      final List<dynamic> data = response.data;
      _insumos = data.map((item) => Insumo.fromJson(item)).toList();
    } catch (e) {
      debugPrint("Error cargando inventario: $e");
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }
}
