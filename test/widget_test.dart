import 'package:expense_tracker/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home page renders repository data and adds a transaction', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ExpenseTrackerApp());
    await tester.pumpAndSettle();

    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('Current balance'), findsOneWidget);
    expect(find.text('Transactions'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Sample expense'), findsNothing);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Sample expense'), findsOneWidget);
    expect(find.text('Mock added transaction'), findsOneWidget);
  });
}
