import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:masjid_locator/main.dart';

void main() {
  testWidgets('GlobalMasjidApp loads and displays smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: GlobalMasjidApp(),
      ),
    );

    expect(find.byType(GlobalMasjidApp), findsOneWidget);
  });
}
