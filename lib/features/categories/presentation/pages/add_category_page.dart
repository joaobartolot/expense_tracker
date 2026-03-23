import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/widgets/app_text_input.dart';
import 'package:expense_tracker/core/widgets/segmented_toggle_field.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:expense_tracker/features/categories/presentation/widgets/category_icon_picker.dart';
import 'package:flutter/material.dart';

class AddCategoryPage extends StatefulWidget {
  const AddCategoryPage({super.key});

  @override
  State<AddCategoryPage> createState() => _AddCategoryPageState();
}

class _AddCategoryPageState extends State<AddCategoryPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  CategoryType _type = CategoryType.expense;
  IconData? _selectedIcon;
  bool _didTrySubmit = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _selectedIcon = Icons.sell_outlined;
    _nameController.addListener(_handleFieldChange);
    _descriptionController.addListener(_handleFieldChange);
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_handleFieldChange)
      ..dispose();
    _descriptionController
      ..removeListener(_handleFieldChange)
      ..dispose();
    super.dispose();
  }

  String? get _nameError {
    if (!_didTrySubmit) {
      return null;
    }

    if (_nameController.text.trim().isEmpty) {
      return 'Please enter a category name.';
    }

    return null;
  }

  String? get _descriptionError {
    if (!_didTrySubmit) {
      return null;
    }

    if (_descriptionController.text.trim().isEmpty) {
      return 'Please enter a short description.';
    }

    return null;
  }

  void _handleFieldChange() {
    if (!_didTrySubmit || !mounted) {
      return;
    }

    setState(() {});
  }

  void _updateType(CategoryType type) {
    if (_type == type) {
      return;
    }

    setState(() {
      _type = type;
    });
  }

  void _saveCategory() {
    FocusScope.of(context).unfocus();

    setState(() {
      _didTrySubmit = true;
    });

    if (_nameError != null || _descriptionError != null) {
      return;
    }

    final category = CategoryItem(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      type: _type,
      icon: _selectedIcon ?? Icons.sell_outlined,
    );

    Navigator.of(context).pop(category);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Add category'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create a new category',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add a category entry with a clear label, a short description, and an icon that fits.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: CategoryIconPicker(
                        selectedIcon: _selectedIcon ?? Icons.sell_outlined,
                        accentColor: AppColors.brand,
                        backgroundColor: AppColors.brand.withValues(
                          alpha: 0.08,
                        ),
                        onIconSelected: (icon) {
                          setState(() {
                            _selectedIcon = icon;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    SegmentedToggleField<CategoryType>(
                      label: 'Type',
                      value: _type,
                      items: const [
                        SegmentedToggleItem(
                          value: CategoryType.expense,
                          label: 'Expense',
                          icon: Icons.arrow_upward_rounded,
                        ),
                        SegmentedToggleItem(
                          value: CategoryType.income,
                          label: 'Income',
                          icon: Icons.arrow_downward_rounded,
                        ),
                      ],
                      onChanged: _updateType,
                    ),
                    const SizedBox(height: 20),
                    AppTextInput(
                      label: 'Name',
                      hintText: 'Category name',
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      errorText: _nameError,
                    ),
                    const SizedBox(height: 16),
                    AppTextInput(
                      label: 'Description',
                      hintText: 'Short description',
                      controller: _descriptionController,
                      textCapitalization: TextCapitalization.sentences,
                      errorText: _descriptionError,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saveCategory,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text('Save category'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
