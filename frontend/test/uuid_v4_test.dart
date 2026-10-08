import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/uuid_v4.dart';

void main() {
  test('uuidV4 genera UUID v4 válidos y distintos', () {
    final re = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    final vistos = <String>{};
    for (var i = 0; i < 200; i++) {
      final u = uuidV4();
      expect(re.hasMatch(u), isTrue, reason: u);
      vistos.add(u);
    }
    expect(vistos.length, 200);
  });
}
