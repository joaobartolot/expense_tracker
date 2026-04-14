import 'package:expense_tracker/core/widgets/custom_dropdown_selector.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('closesExpandedMenu_whenTappedOutside', (tester) async {
    await tester.pumpWidget(_buildScrollableDropdownHarness());

    final selector = find.byType(CustomDropdownSelector<String>);
    final collapsedHeight = tester.getSize(selector).height;

    await tester.tap(find.text('Choose a category'));
    await tester.pumpAndSettle();

    final expandedHeight = tester.getSize(selector).height;
    expect(expandedHeight, greaterThan(collapsedHeight));

    final gesture = await tester.startGesture(
      const Offset(20, 300),
      kind: PointerDeviceKind.touch,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(tester.getSize(selector).height, collapsedHeight);
  });

  testWidgets('keepsExpandedMenuOpen_whenScrollingOutside', (tester) async {
    await tester.pumpWidget(_buildScrollableDropdownHarness());

    final selector = find.byType(CustomDropdownSelector<String>);
    final collapsedHeight = tester.getSize(selector).height;

    await tester.tap(find.text('Choose a category'));
    await tester.pumpAndSettle();

    final expandedHeight = tester.getSize(selector).height;
    expect(expandedHeight, greaterThan(collapsedHeight));

    final scrollStart = tester.getCenter(find.text('Scrollable filler area'));
    final gesture = await tester.startGesture(scrollStart);
    await gesture.moveBy(const Offset(0, -120));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(tester.getSize(selector).height, greaterThan(collapsedHeight));
  });
}

Widget _buildScrollableDropdownHarness({ScrollController? scrollController}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        controller: scrollController,
        child: Column(
          children: [
            CustomDropdownSelector<String>(
              label: 'Category',
              hintText: 'Choose a category',
              items: const [
                DropdownSelectorItem<String>(value: 'food', label: 'Food'),
                DropdownSelectorItem<String>(
                  value: 'transport',
                  label: 'Transport',
                ),
              ],
              onChanged: (_) {},
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: const SizedBox(
                height: 1200,
                child: Center(child: Text('Scrollable filler area')),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
