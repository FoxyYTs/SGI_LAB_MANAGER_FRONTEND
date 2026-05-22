import 'package:flutter/foundation.dart';

/// Web stub — offline queue not needed on web (always online).
class SyncService extends ChangeNotifier {
  static final SyncService instance = SyncService._();
  SyncService._();

  bool get online  => true;
  bool get syncing => false;
  int  get pending => 0;

  Future<void> init(String? token) async {}
  void updateToken(String? token) {}
  Future<void> encolar(String operacion, Map<String, dynamic> payload) async {}
  Future<List<Map<String, dynamic>>> historialCola() async => [];

  @override
  void dispose() => super.dispose();
}
