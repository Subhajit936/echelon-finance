import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/models/user_profile.dart';
import '../../providers/user_profile_provider.dart';
import '../../shared/widgets/gradient_button.dart';
import '../../core/database/seed_data.dart';
import '../../providers/database_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nameCtrl = TextEditingController();
  String _currency = 'INR';

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    final profile = UserProfile(
      id: '1',
      displayName: name,
      preferredCurrency: _currency,
      onboardingComplete: false, // will complete after API key
      createdAt: DateTime.now(),
    );

    await ref.read(userProfileProvider.notifier).save(profile);

    // Seed sample data
    final db = ref.read(databaseHelperProvider);
    await SeedData.seed(db, _currency);

    if (mounted) context.go('/api-key');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              // Logo
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryContainer],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.account_balance_wallet_outlined,
                    color: Colors.white, size: 36),
              ),
              const SizedBox(height: 24),
              Text('Welcome to\nThe Ledger', style: AppTextStyles.displaySm),
              const SizedBox(height: 8),
              Text(
                'Your personal finance advisor.\nLet\'s get you set up.',
                style: AppTextStyles.bodyLg.copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Your name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 20),
              Text('Preferred currency', style: AppTextStyles.labelLg),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _CurrencyCard(
                      label: 'Indian Rupee',
                      symbol: '₹',
                      code: 'INR',
                      selected: _currency == 'INR',
                      onTap: () => setState(() => _currency = 'INR'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CurrencyCard(
                      label: 'US Dollar',
                      symbol: '\$',
                      code: 'USD',
                      selected: _currency == 'USD',
                      onTap: () => setState(() => _currency = 'USD'),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              GradientButton(
                label: 'Get Started',
                onTap: _continue,
                fullWidth: true,
                icon: const Icon(Icons.arrow_forward),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrencyCard extends StatelessWidget {
  final String label;
  final String symbol;
  final String code;
  final bool selected;
  final VoidCallback onTap;

  const _CurrencyCard({
    required this.label,
    required this.symbol,
    required this.code,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.08)
              : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: selected
              ? Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5)
              : null,
        ),
        child: Column(
          children: [
            Text(symbol,
                style: AppTextStyles.displaySm.copyWith(color: AppColors.primary)),
            const SizedBox(height: 4),
            Text(code, style: AppTextStyles.titleMd),
            Text(label,
                style: AppTextStyles.labelMd, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
