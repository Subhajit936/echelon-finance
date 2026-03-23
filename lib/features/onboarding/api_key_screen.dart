import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../providers/database_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../shared/widgets/gradient_button.dart';

class ApiKeyScreen extends ConsumerStatefulWidget {
  const ApiKeyScreen({super.key});

  @override
  ConsumerState<ApiKeyScreen> createState() => _ApiKeyScreenState();
}

class _ApiKeyScreenState extends ConsumerState<ApiKeyScreen> {
  final _keyCtrl = TextEditingController();
  bool _obscure = true;
  bool _saving = false;

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final key = _keyCtrl.text.trim();
    setState(() => _saving = true);

    // Save key to secure storage
    await ref.read(aiServiceProvider).saveClaudeKey(key);

    // Mark onboarding complete
    await ref.read(userProfileProvider.notifier).save(
      ref.read(userProfileProvider).value!.copyWith(onboardingComplete: true),
    );

    setState(() => _saving = false);
    if (mounted) context.go('/login');
  }

  Future<void> _skip() async {
    await ref.read(userProfileProvider.notifier).save(
      ref.read(userProfileProvider).value!.copyWith(onboardingComplete: true),
    );
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        actions: [
          TextButton(
            onPressed: _skip,
            child: Text('Skip', style: AppTextStyles.titleMd),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.key_outlined, color: AppColors.primary, size: 32),
            ),
            const SizedBox(height: 20),
            Text('Add AI API Key', style: AppTextStyles.displaySm),
            const SizedBox(height: 8),
            Text(
              'Add a Claude (Anthropic) API key to enable AI features. You can also use OpenAI — configure both in Settings after onboarding.',
              style: AppTextStyles.bodyLg.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _keyCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Claude API Key (Anthropic)',
                hintText: 'sk-ant-api03-...',
                prefixIcon: const Icon(Icons.vpn_key_outlined),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your key is stored securely on this device and never sent to any server other than Anthropic\'s API.',
              style: AppTextStyles.labelMd,
            ),
            const Spacer(),
            GradientButton(
              label: _saving ? 'Saving...' : 'Save & Continue',
              onTap: _saving ? null : _save,
              fullWidth: true,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
