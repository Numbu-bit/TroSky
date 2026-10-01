import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_web/main.dart';

void main() {
  testWidgets('shows the setup placeholder', (tester) async {
    await tester.pumpWidget(const TroskyFleetApp());

    expect(find.text('TroSky Fleet — setup OK'), findsOneWidget);
  });
}
