import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:store_management_app/main.dart';
import 'package:store_management_app/providers/app_provider.dart';
import 'package:store_management_app/widgets/cart_checkout.dart';

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

  testWidgets('saves an edited fractional cart quantity after closing dialog',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final provider = AppProvider();
    final product = <String, dynamic>{
      'id': 1,
      'name': 'Chicken 65',
      'sellingPrice': 400.0,
      'stockQuantity': 10.0,
      'unit': 'KG',
    };
    provider.addToCart(product);
    provider.setCartQuantity(1, 3.2);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: CartPanel(pageContext: context),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(TextButton, '3.2 KG'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1.5');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(provider.cartItems[1]!['quantity'], 1.5);
    expect(find.text('1.5 KG'), findsWidgets);

    // AppProvider starts the app's normal splash timer on construction.
    await tester.pump(const Duration(milliseconds: 1300));
  });
}
