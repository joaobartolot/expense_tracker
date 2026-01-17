sealed class Category {
  const Category();

  String get displayName;
  String get key;

  static Category fromKey(String key) {
    final allCategories = <Category>[
      ...ExpenseCategory.values,
      ...IncomeCategory.values,
    ];

    return allCategories.firstWhere(
      (c) => c.key == key,
      orElse: () => ExpenseCategory.other as Category,
    );
  }
}

enum ExpenseCategory implements Category {
  food('Food'),
  transportation('Transportation'),
  utilities('Utilities'),
  entertainment('Entertainment'),
  healthcare('Healthcare'),
  education('Education'),
  personalCare('Personal Care'),
  gifts('Gifts'),
  travel('Travel'),
  miscellaneous('Miscellaneous'),
  other('Other');

  const ExpenseCategory(this.displayName);

  @override
  final String displayName;

  @override
  String get key => 'expense_$name';
}

enum IncomeCategory implements Category {
  salary('Salary'),
  business('Business'),
  investment('Investment'),
  gift('Gift'),
  other('Other');

  const IncomeCategory(this.displayName);

  @override
  final String displayName;

  @override
  String get key => 'income_$name';
}
