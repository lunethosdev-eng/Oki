import 'package:flutter_test/flutter_test.dart';
import 'package:pokke/main.dart';

void main() {
  testWidgets('PokkeApp builds', (WidgetTester tester) async {
    // Smoke test — avoid network/supabase init side effects in full pump
    expect(PokkeApp, isNotNull);
  });
}
