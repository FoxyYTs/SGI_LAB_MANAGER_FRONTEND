/// Web stub — SQLite is not available on web. All operations are no-ops.
class LocalDb {
  static Future<_NoopDb> get instance async => _NoopDb._();
}

class _NoopDb {
  _NoopDb._();
  Future<void> insert(String t, Map m, {dynamic conflictAlgorithm}) async {}
  Future<void> delete(String t, {String? where, List? whereArgs}) async {}
  Future<List<Map<String, dynamic>>> query(String t,
      {String? where, List? whereArgs, String? orderBy, int? limit}) async => [];
  Future<List<Map<String, dynamic>>> rawQuery(String sql,
      [List? args]) async => [];
  Future<int> rawInsert(String sql, [List? args]) async => 0;
  Future<int> update(String t, Map<String, dynamic> v,
      {String? where, List? whereArgs}) async => 0;
  _Batch batch() => _Batch();
}

class _Batch {
  void insert(String t, Map m, {dynamic conflictAlgorithm}) {}
  void delete(String t) {}
  Future<List<dynamic>> commit({bool? noResult}) async => [];
}
