// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fine_pocket_mobile/main.dart';
import 'package:fine_pocket_mobile/state/finance_state.dart';

void main() {
  testWidgets('Dashboard UI renders correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => FinanceState()),
        ],
        child: const FinePocketApp(isFirstTime: false),
      ),
    );

    // Verify that the title is present
    expect(find.text('FinePocket'), findsOneWidget);
    expect(find.text('CASH\nSPEND'), findsOneWidget);
  });
}
