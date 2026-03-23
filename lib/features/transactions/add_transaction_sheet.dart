import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/models/transaction.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../shared/widgets/gradient_button.dart';

const _uuid = Uuid();

class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({super.key});

  @override
  ConsumerState<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _merchantCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  TransactionType _type = TransactionType.expense;
  TransactionCategory _category = TransactionCategory.food;
  TransactionStatus _status = TransactionStatus.cleared;
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _merchantCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final merchant = _merchantCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (merchant.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill merchant and a valid amount')),
      );
      return;
    }

    final currency = ref.read(currencyProvider);
    final txn = AppTransaction(
      id: _uuid.v4(),
      merchant: merchant,
      category: _category,
      type: _type,
      amount: amount,
      date: _date,
      status: _status,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      currency: currency,
      createdAt: DateTime.now(),
    );

    ref.read(transactionProvider.notifier).add(txn);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Transaction', style: AppTextStyles.headlineMd),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type selector
            Row(
              children: [
                _TypeChip(
                  label: 'Expense',
                  selected: _type == TransactionType.expense,
                  color: AppColors.tertiary,
                  onTap: () => setState(() => _type = TransactionType.expense),
                ),
                const SizedBox(width: 8),
                _TypeChip(
                  label: 'Income',
                  selected: _type == TransactionType.income,
                  color: AppColors.secondary,
                  onTap: () => setState(() => _type = TransactionType.income),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _merchantCtrl,
              decoration: const InputDecoration(labelText: 'Merchant / Description'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            const SizedBox(height: 12),
            // Category
            Text('Category', style: AppTextStyles.labelLg),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TransactionCategory.values.map((cat) {
                final selected = cat == _category;
                return GestureDetector(
                  onTap: () => setState(() => _category = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withOpacity(0.12)
                          : AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${cat.icon} ${cat.label}',
                      style: AppTextStyles.labelLg.copyWith(
                        color: selected ? AppColors.primary : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            // Date
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Date', style: AppTextStyles.labelLg),
              subtitle: Text(
                '${_date.day}/${_date.month}/${_date.year}',
                style: AppTextStyles.bodyMd,
              ),
              trailing: const Icon(Icons.calendar_today_outlined, size: 18),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            const SizedBox(height: 32),
            GradientButton(
              label: 'Save Transaction',
              onTap: _save,
              fullWidth: true,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: AppTextStyles.titleMd.copyWith(
            color: selected ? color : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
