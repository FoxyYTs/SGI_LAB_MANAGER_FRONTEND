import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/insumo_model.dart';

class InventarioProvider with ChangeNotifier {
  List<Insumo> _insumos = [];
  bool _cargando = false;
  final Dio _dio = Dio(BaseOptions(baseUrl: "http://localhost:8000/api/"));
  final _storage = const FlutterSecureStorage();

  List<Insumo> get insumos => _insumos;
  bool get cargando => _cargando;

  Future<void> fetchInsumos() async {
    _cargando = true;
    notifyListeners();

    try {
      final token = await _storage.read(key: 'token');
      final response = await _dio.get(
        'inventario/lista/',
        options: Options(headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        }),
      );
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
