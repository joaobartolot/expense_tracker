import 'package:expense_tracker/features/transactions/domain/enums/transaction_type.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction.dart';
import 'package:expense_tracker/features/transactions/presentation/widgets/transaction_form_fields.dart';
import 'package:expense_tracker/shared/di/providers.dart';
import 'package:expense_tracker/shared/utils/currency_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

class AddTransaction extends ConsumerStatefulWidget {
  const AddTransaction({super.key});

  @override
  ConsumerState<AddTransaction> createState() => _AddTransactionState();
}

class _AddTransactionState extends ConsumerState<AddTransaction> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  TransactionType _type = TransactionType.expense;
  String? _selectedCategory;

  final List<String> _categories = const [
    'Food',
    'Transport',
    'Bills',
    'Shopping',
    'Health',
    'Entertainment',
    'Other',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final repo = ref.read(transactionsRepositoryProvider);

    final amountCents = stringToCents(_amountCtrl.text);
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();

    await repo.upsert(
      Transaction(
        id: const Uuid().v4(),
        name: _nameCtrl.text.trim(),
        amountCents: amountCents,
        type: _type,
        category: _selectedCategory!,
        date: DateTime.now(),
        note: note,
      ),
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Transaction'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TransactionTypeSwitch(
                value: _type,
                onChanged: (v) => setState(() => _type = v),
              ),
              const SizedBox(height: 28),
              TransactionTextFormField(
                controller: _nameCtrl,
                label: 'Name',
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              TransactionTextFormField(
                controller: _amountCtrl,
                label: 'Amount (€)',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final value = double.tryParse(v);
                  if (value == null || value <= 0) return 'Invalid';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              CategoryDropdown(
                value: _selectedCategory,
                categories: _categories,
                onChanged: (v) => setState(() => _selectedCategory = v),
              ),
              const SizedBox(height: 20),
              TransactionTextFormField(
                controller: _noteCtrl,
                label: 'Note (optional)',
                maxLines: 2,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
