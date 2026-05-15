import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../models/insumo_model.dart';


class InventarioProvider with ChangeNotifier {
  List<Insumo> _insumos = [];
  final Dio _dio = Dio(BaseOptions(baseUrl: "http://localhost:8000/api/"));

  List<Insumo> get insumos => _insumos;

  Future<void> fetchInsumos() async {
    try {
      final response = await _dio.get('inventario/lista/');
      final List<dynamic> data = response.data;
      _insumos = data.map((item) => Insumo.fromJson(item)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint("Error cargando inventario: $e");
    }
  }
}