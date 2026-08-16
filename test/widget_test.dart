import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:store_management_app/main.dart';

void main() {
  testWidgets('shows the branded startup experience', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const StoreManagementApp());

    expect(find.text('NEXORA'), findsOneWidget);
    expect(find.text('Commerce, in perfect flow.'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pump();
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
