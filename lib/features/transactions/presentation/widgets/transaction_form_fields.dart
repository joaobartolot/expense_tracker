import 'package:expense_tracker/features/transactions/domain/enums/category.dart';
import 'package:expense_tracker/features/transactions/domain/enums/transaction_type.dart';
import 'package:flutter/material.dart';

/// Styled input decoration for transaction form fields
InputDecoration getTransactionInputDecoration(
  BuildContext context,
  String label,
) {
  final cs = Theme.of(context).colorScheme;
  return InputDecoration(
    labelText: label,
    filled: false,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: cs.outline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: cs.outline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: cs.primary, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  );
}

/// Reusable text form field with transaction styling
class TransactionTextFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final int maxLines;

  const TransactionTextFormField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: getTransactionInputDecoration(context, label),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
    );
  }
}

/// Custom switch for transaction type with icons and text
class TransactionTypeSwitch extends StatelessWidget {
  final TransactionType value;
  final Function(TransactionType) onChanged;

  const TransactionTypeSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          _TypeButton(
            type: TransactionType.expense,
            icon: Icons.remove_circle,
            label: 'Expense',
            isSelected: value == TransactionType.expense,
            onTap: () => onChanged(TransactionType.expense),
          ),
          _TypeButton(
            type: TransactionType.income,
            icon: Icons.add_circle,
            label: 'Income',
            isSelected: value == TransactionType.income,
            onTap: () => onChanged(TransactionType.income),
          ),
        ],
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final TransactionType type;
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeButton({
    required this.type,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isExpense = type == TransactionType.expense;
    final color = isExpense ? Colors.red : Colors.green;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? color.withAlpha(25) : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
          ),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? color : cs.onSurfaceVariant,
                size: 24,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable dropdown form field for categories
class CategoryDropdown extends StatelessWidget {
  final Category? value;
  final Function(Category?) onChanged;
  final List<Category> categories;

  const CategoryDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Category>(
      initialValue: value,
      decoration: getTransactionInputDecoration(context, 'Category'),
      items: categories
          .map((c) => DropdownMenuItem(value: c, child: Text(c.displayName)))
          .toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? 'Required' : null,
    );
  }
}
