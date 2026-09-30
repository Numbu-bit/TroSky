import 'package:flutter_test/flutter_test.dart';
import 'package:trosky_auth/trosky_auth.dart';

void main() {
  test('the stub store never has a saved session', () async {
    const SessionStore store = StubSessionStore();

    expect(await store.hasSavedSession(), isFalse);
  });
}
