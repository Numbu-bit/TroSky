import 'package:flutter_test/flutter_test.dart';
import 'package:trosky_api/trosky_api.dart';

void main() {
  test('barrel exports the package name', () {
    expect(troskyApiPackageName, 'trosky_api');
  });
}
