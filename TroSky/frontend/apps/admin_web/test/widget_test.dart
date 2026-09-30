import 'package:flutter_test/flutter_test.dart';
import 'package:admin_web/main.dart';

void main() {
  testWidgets('shows the setup placeholder', (tester) async {
    await tester.pumpWidget(const TroskyAdminApp());

    expect(find.text('TroSky Admin — setup OK'), findsOneWidget);
  });
}
