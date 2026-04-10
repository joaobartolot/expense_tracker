import 'package:expense_tracker/core/widgets/custom_dropdown_selector.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('closesExpandedMenu_whenTappedOutside', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
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
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      ),
    );

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
}
