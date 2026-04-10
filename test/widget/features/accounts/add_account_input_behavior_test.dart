import 'package:expense_tracker/core/widgets/custom_dropdown_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'add_account_test_harness.dart';

void main() {
  late AddAccountTestEnvironment environment;

  setUp(() {
    environment = AddAccountTestEnvironment();
  });

  group('add account input behavior', () {
    testWidgets('create starts at 0.00 with the settings currency selected', (
      tester,
    ) async {
      await _configureSurface(tester);
      environment = AddAccountTestEnvironment(
        settings: environment.settingsRepository.getSettings().copyWith(
          defaultCurrencyCode: 'USD',
        ),
      );

      await environment.pumpHost(tester);
      await _openAddAccountPage(tester);

      expect(_balanceText(tester), '0.00');
      expect(find.text('USD'), findsAtLeastNWidgets(1));
      expect(_balanceField(tester).decoration?.prefixText, r'$ ');
    });

    testWidgets(
      'digit entry follows masked cents behavior from 0.00 to 0.01 to 0.12 to 1.23',
      (tester) async {
        await _configureSurface(tester);
        await environment.pumpHost(tester);
        await _openAddAccountPage(tester);

        await _updateBalanceValue(
          tester,
          const TextEditingValue(
            text: '1',
            selection: TextSelection.collapsed(offset: 1),
          ),
        );
        expect(_balanceText(tester), '0.01');

        await _updateBalanceValue(
          tester,
          const TextEditingValue(
            text: '12',
            selection: TextSelection.collapsed(offset: 2),
          ),
        );
        expect(_balanceText(tester), '0.12');

        await _updateBalanceValue(
          tester,
          const TextEditingValue(
            text: '123',
            selection: TextSelection.collapsed(offset: 3),
          ),
        );
        expect(_balanceText(tester), '1.23');
      },
    );

    testWidgets('backspace reverses the mask down to 0.00', (tester) async {
      await _configureSurface(tester);
      await environment.pumpHost(tester);
      await _openAddAccountPage(tester);

      await _updateBalanceValue(
        tester,
        const TextEditingValue(
          text: '123',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      expect(_balanceText(tester), '1.23');

      await _updateBalanceValue(
        tester,
        const TextEditingValue(
          text: '12',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      expect(_balanceText(tester), '0.12');

      await _updateBalanceValue(
        tester,
        const TextEditingValue(
          text: '1',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      expect(_balanceText(tester), '0.01');

      await _updateBalanceValue(
        tester,
        const TextEditingValue(
          text: '',
          selection: TextSelection.collapsed(offset: 0),
        ),
      );
      expect(_balanceText(tester), '0.00');
    });

    testWidgets('non digit input does not override the cents mask', (
      tester,
    ) async {
      await _configureSurface(tester);
      await environment.pumpHost(tester);
      await _openAddAccountPage(tester);

      await _updateBalanceValue(
        tester,
        const TextEditingValue(
          text: '1a2.3',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );

      expect(_balanceText(tester), '1.23');
    });

    testWidgets('negative sign is preserved by the balance mask', (
      tester,
    ) async {
      await _configureSurface(tester);
      await environment.pumpHost(tester);
      await _openAddAccountPage(tester);

      await _updateBalanceValue(
        tester,
        const TextEditingValue(
          text: '-123',
          selection: TextSelection.collapsed(offset: 4),
        ),
      );

      expect(_balanceText(tester), '-1.23');
    });

    testWidgets('currency prefix updates when the selected currency changes', (
      tester,
    ) async {
      await _configureSurface(tester);
      await environment.pumpHost(tester);
      await _openAddAccountPage(tester);

      expect(_balanceField(tester).decoration?.prefixText, '€ ');

      await _selectDropdownOption<String>(tester, 'Currency', 'GBP');

      expect(_balanceField(tester).decoration?.prefixText, '£ ');
    });
  });
}

Future<void> _openAddAccountPage(WidgetTester tester) async {
  await _tapVisible(
    tester,
    find.widgetWithText(FilledButton, 'Open add account'),
  );
  await tester.pumpAndSettle();
}

Future<void> _updateBalanceValue(
  WidgetTester tester,
  TextEditingValue value,
) async {
  _balanceField(tester).controller!.value = value;
  await tester.pumpAndSettle();
}

TextField _balanceField(WidgetTester tester) {
  return tester.widget<TextField>(find.byType(TextField).at(2));
}

String _balanceText(WidgetTester tester) {
  return _balanceField(tester).controller!.text;
}

Future<void> _selectDropdownOption<T>(
  WidgetTester tester,
  String label,
  String optionLabel,
) async {
  final selector = find.byWidgetPredicate(
    (widget) => widget is CustomDropdownSelector<T> && widget.label == label,
  );
  await _tapVisible(
    tester,
    find.descendant(of: selector, matching: find.byType(InkWell)).first,
  );
  await tester.pumpAndSettle();
  await _tapVisible(
    tester,
    find.descendant(of: selector, matching: find.text(optionLabel)).last,
  );
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
}

Future<void> _configureSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}
