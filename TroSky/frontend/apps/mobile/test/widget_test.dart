import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('shows the setup placeholder', (tester) async {
    await tester.pumpWidget(const TroskyMobileApp());

    expect(find.text('TroSky Mobile — setup OK'), findsOneWidget);
  });
}
