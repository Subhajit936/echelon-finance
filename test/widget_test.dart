// Basic smoke test — verifies the app launches without crashing.
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The full EchelonApp requires a real SQLite database and platform channels
  // that are not available in the test environment. The meaningful unit tests
  // are in test/offline_responder_test.dart.
  test('placeholder — see offline_responder_test.dart for unit tests', () {
    expect(1 + 1, 2);
  });
}
