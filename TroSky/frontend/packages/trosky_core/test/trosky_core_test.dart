import 'package:flutter_test/flutter_test.dart';
import 'package:trosky_core/trosky_core.dart';

void main() {
  test('barrel exports the package name', () {
    expect(troskyCorePackageName, 'trosky_core');
  });
}
