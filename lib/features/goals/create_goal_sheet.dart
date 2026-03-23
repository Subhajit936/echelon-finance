import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/models/goal.dart';
import '../../providers/goal_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../shared/widgets/gradient_button.dart';

const _uuid = Uuid();
const _emojis = ['🎯', '🏠', '🚗', '✈️', '💻', '📱', '🎓', '💍', '🏖️', '🏋️', '📚', '🎮'];

class CreateGoalSheet extends ConsumerStatefulWidget {
  const CreateGoalSheet({super.key});

  @override
  ConsumerState<CreateGoalSheet> createState() => _CreateGoalSheetState();
}

class _CreateGoalSheetState extends ConsumerState<CreateGoalSheet> {
  final _nameCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _currentCtrl = TextEditingController();
  String _selectedEmoji = '🎯';
  DateTime? _targetDate;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    _currentCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    final target = double.tryParse(_targetCtrl.text.trim());
    if (name.isEmpty || target == null || target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill name and a valid target amount')),
      );
      return;
    }

    final current = double.tryParse(_currentCtrl.text.trim()) ?? 0;
    final currency = ref.read(currencyProvider);

    // Calculate daily target
    double dailyTarget = 0;
    if (_targetDate != null) {
      final daysLeft = _targetDate!.difference(DateTime.now()).inDays;
      if (daysLeft > 0) dailyTarget = (target - current) / daysLeft;
    }

    final goal = Goal(
      id: _uuid.v4(),
      name: name,
      emoji: _selectedEmoji,
      targetAmount: target,
      currentAmount: current,
      targetDate: _targetDate,
      dailyTarget: dailyTarget,
      status: GoalStatus.active,
      currency: currency,
      createdAt: DateTime.now(),
    );

    ref.read(goalProvider.notifier).create(goal);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Goal', style: AppTextStyles.headlineMd),
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
            // Emoji picker
            Text('Choose an icon', style: AppTextStyles.labelLg),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _emojis.map((e) {
                final selected = e == _selectedEmoji;
                return GestureDetector(
                  onTap: () => setState(() => _selectedEmoji = e),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withOpacity(0.12)
                          : AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(child: Text(e, style: const TextStyle(fontSize: 24))),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Goal name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _targetCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Target amount'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _currentCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Already saved (optional)'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Target date (optional)', style: AppTextStyles.labelLg),
              subtitle: Text(
                _targetDate != null
                    ? '${_targetDate!.day}/${_targetDate!.month}/${_targetDate!.year}'
                    : 'Not set',
                style: AppTextStyles.bodyMd,
              ),
              trailing: const Icon(Icons.calendar_today_outlined, size: 18),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                );
                if (picked != null) setState(() => _targetDate = picked);
              },
            ),
            const SizedBox(height: 32),
            GradientButton(label: 'Create Goal', onTap: _save, fullWidth: true),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
