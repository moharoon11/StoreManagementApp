import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:store_management_app/main.dart';
import 'package:store_management_app/providers/app_provider.dart';
import 'package:store_management_app/views/auth/login_view.dart';
import 'package:store_management_app/widgets/adaptive_image_preview.dart';
import 'package:store_management_app/widgets/cart_checkout.dart';
import 'package:store_management_app/widgets/workspace_ui.dart';

void main() {
  testWidgets('shows the branded startup experience', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const StoreManagementApp());

    expect(find.text('NEXORA'), findsOneWidget);
    expect(find.text('Commerce, in perfect flow.'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pump();
    expect(find.text('Store login'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
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

  testWidgets('renders section panel scroll content inside bounded layouts',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 420,
            child: SectionPanel(
              title: 'Invoice ledger',
              subtitle: 'Recent sales',
              child: ListView(
                children: const [
                  ListTile(title: Text('Invoice #1001')),
                  ListTile(title: Text('Invoice #1002')),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Invoice #1001'), findsOneWidget);
    expect(find.text('Invoice #1002'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders an empty cart safely inside the desktop side panel',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final provider = AppProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: Builder(
            builder: (pageContext) => Scaffold(
              body: SizedBox(
                width: 320,
                height: 420,
                child: CartPanel(pageContext: pageContext),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('No items in the current sale'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 1300));
  });

  testWidgets('renders a picked image preview without Image.file',
      (tester) async {
    final pngBytes = Uint8List.fromList(const [
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
      0,
      0,
      0,
      13,
      73,
      72,
      68,
      82,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      1,
      8,
      6,
      0,
      0,
      0,
      31,
      21,
      196,
      137,
      0,
      0,
      0,
      13,
      73,
      68,
      65,
      84,
      120,
      156,
      99,
      248,
      255,
      255,
      63,
      0,
      5,
      254,
      2,
      254,
      167,
      53,
      129,
      132,
      0,
      0,
      0,
      0,
      73,
      69,
      78,
      68,
      174,
      66,
      96,
      130,
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              height: 120,
              child: AdaptiveImagePreview(
                pickedImage: XFile.fromData(
                  pngBytes,
                  name: 'preview.png',
                  mimeType: 'image/png',
                ),
                placeholder: const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a trimmed login experience on compact screens',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final provider = AppProvider();

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: LoginView(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Store login'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('What changed'), findsNothing);
    expect(find.text('Platform'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1300));
  });
}
