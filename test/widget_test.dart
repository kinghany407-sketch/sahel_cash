// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:sahel_cash/main.dart';
import 'package:sahel_cash/models/customer_model.dart';
import 'package:sahel_cash/screens/customers/customer_statement_dialog.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SahelCashApp());

    expect(find.text('سهل كاش'), findsOneWidget);
  });

  testWidgets(
    'customer statement scrolls to account summary with mouse wheel',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final customer = Customer(
        name: 'عميل اختبار',
        address: List.filled(1200, 'عنوان طويل').join(' '),
        initialBalance: 100,
        currentBalance: 150,
        createdAt: '2026-10-01',
        updatedAt: '2026-10-01',
      );

      await tester.pumpWidget(
        MaterialApp(home: CustomerStatementDialog(customer: customer)),
      );
      await tester.pump();

      final scrollView = find.byType(SingleChildScrollView);
      final viewport = tester.getRect(scrollView);
      expect(
        tester.getRect(find.text('ملخص الحساب')).top,
        greaterThan(viewport.bottom),
      );

      for (var scrollStep = 0; scrollStep < 20; scrollStep++) {
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: viewport.center,
            scrollDelta: const Offset(0, 600),
          ),
        );
        await tester.pump();
      }

      expect(
        tester.getRect(find.text('ملخص الحساب')).top,
        lessThan(viewport.bottom),
      );
    },
  );
}
