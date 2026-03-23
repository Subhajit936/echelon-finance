import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/ai_service.dart';
import '../../providers/database_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/notification_provider.dart';
import '../../core/api/api_client.dart';
import '../../providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameController = TextEditingController();
  final _claudeKeyController = TextEditingController();
  final _openAiKeyController = TextEditingController();
  final _backendUrlController = TextEditingController();
  final _backendTokenController = TextEditingController();

  bool _claudeObscured = true;
  bool _openAiObscured = true;
  bool _backendTokenObscured = true;
  bool _isSaving = false;
  bool _isTestingConnection = false;
  AIProvider _selectedProvider = AIProvider.claude;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final ai = ref.read(aiServiceProvider);
    final claudeKey = await ai.getClaudeKey() ?? '';
    final openAiKey = await ai.getOpenAiKey() ?? '';
    final provider = await ai.getProvider();

    final apiClient = ref.read(apiClientProvider);
    final backendUrl = await apiClient.getBaseUrl() ?? '';
    final backendToken = await apiClient.getToken() ?? '';

    final profile = ref.read(userProfileProvider).valueOrNull;
    if (mounted) {
      setState(() {
        _claudeKeyController.text = claudeKey;
        _openAiKeyController.text = openAiKey;
        _selectedProvider = provider;
        _nameController.text = profile?.displayName ?? '';
        _backendUrlController.text = backendUrl;
        _backendTokenController.text = backendToken;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _claudeKeyController.dispose();
    _openAiKeyController.dispose();
    _backendUrlController.dispose();
    _backendTokenController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final ai = ref.read(aiServiceProvider);
      await ai.saveClaudeKey(_claudeKeyController.text.trim());
      await ai.saveOpenAiKey(_openAiKeyController.text.trim());
      await ai.saveProvider(_selectedProvider);

      // Update profile name if changed
      final profile = ref.read(userProfileProvider).valueOrNull;
      if (profile != null && _nameController.text.trim().isNotEmpty &&
          _nameController.text.trim() != profile.displayName) {
        await ref.read(userProfileProvider.notifier).updateName(
          _nameController.text.trim(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveBackend() async {
    final apiClient = ref.read(apiClientProvider);
    await apiClient.saveBaseUrl(_backendUrlController.text.trim());
    await apiClient.saveToken(_backendTokenController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backend settings saved'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    setState(() => _isTestingConnection = true);
    try {
      final syncService = ref.read(syncServiceProvider);
      final reachable = await syncService.isBackendReachable();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(reachable
                ? 'Backend reachable — connection successful'
                : 'Backend not reachable — check URL and token'),
            backgroundColor: reachable ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTestingConnection = false);
    }
  }

  Future<void> _showAddBudgetDialog() async {
    final categoryCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final currency = ref.read(userProfileProvider).valueOrNull?.preferredCurrency ?? 'INR';

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Monthly Budget'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: categoryCtrl,
              decoration: const InputDecoration(labelText: 'Category (e.g. Food)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Monthly limit',
                prefixText: currency == 'INR' ? '₹ ' : '\$ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              final cat = categoryCtrl.text.trim();
              final amt = double.tryParse(amountCtrl.text.trim());
              if (cat.isNotEmpty && amt != null && amt > 0) {
                ref.read(budgetProvider.notifier).addBudget(
                  category: cat,
                  limitAmount: amt,
                  currency: currency,
                );
                Navigator.pop(_);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearChatHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Chat History'),
        content: const Text('This will permanently delete all AI chat messages. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(chatProvider.notifier).clearHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat history cleared'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final currency = profile?.preferredCurrency ?? AppConstants.inr;

    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Save'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Profile ──────────────────────────────────────────────────────
          _SectionHeader(icon: Icons.person_outline, title: 'Profile'),
          _Card(
            child: Column(
              children: [
                _Field(
                  controller: _nameController,
                  label: 'Display name',
                  icon: Icons.badge_outlined,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.currency_exchange),
                  title: const Text('Currency'),
                  trailing: _CurrencyToggle(
                    current: currency,
                    onChanged: (c) {
                      ref.read(userProfileProvider.notifier).updateCurrency(c);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── AI Provider ──────────────────────────────────────────────────
          _SectionHeader(icon: Icons.smart_toy_outlined, title: 'AI Provider'),
          _Card(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Active provider',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AppColors.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      SegmentedButton<AIProvider>(
                        segments: const [
                          ButtonSegment(
                            value: AIProvider.claude,
                            label: Text('Claude'),
                            icon: Icon(Icons.psychology_outlined),
                          ),
                          ButtonSegment(
                            value: AIProvider.openai,
                            label: Text('OpenAI'),
                            icon: Icon(Icons.auto_awesome_outlined),
                          ),
                        ],
                        selected: {_selectedProvider},
                        onSelectionChanged: (s) => setState(() => _selectedProvider = s.first),
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.resolveWith((states) =>
                              states.contains(WidgetState.selected)
                                  ? AppColors.primary.withOpacity(0.15)
                                  : null),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Claude key
                _KeyField(
                  controller: _claudeKeyController,
                  label: 'Claude (Anthropic) API key',
                  hint: 'sk-ant-api03-...',
                  obscured: _claudeObscured,
                  onToggle: () => setState(() => _claudeObscured = !_claudeObscured),
                  isActive: _selectedProvider == AIProvider.claude,
                ),
                const Divider(height: 1),

                // OpenAI key
                _KeyField(
                  controller: _openAiKeyController,
                  label: 'OpenAI API key',
                  hint: 'sk-...',
                  obscured: _openAiObscured,
                  onToggle: () => setState(() => _openAiObscured = !_openAiObscured),
                  isActive: _selectedProvider == AIProvider.openai,
                ),
                const Divider(height: 1),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: AppColors.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _selectedProvider == AIProvider.claude
                              ? 'Chat uses Claude Haiku (efficient). Insights use Claude Sonnet.'
                              : 'Chat uses GPT-4o mini. Insights fall back to Sonnet if Claude key is set.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Backend / MongoDB ─────────────────────────────────────────────
          _SectionHeader(icon: Icons.cloud_outlined, title: 'Backend / MongoDB'),
          _Card(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _backendUrlController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Backend URL',
                      hintText: 'https://your-app.railway.app',
                      prefixIcon: Icon(Icons.link, size: 20),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _backendTokenController,
                    obscureText: _backendTokenObscured,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Personal Token',
                      hintText: 'Bearer token (optional)',
                      prefixIcon: const Icon(Icons.key_outlined, size: 20),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _backendTokenObscured
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                        ),
                        onPressed: () => setState(
                            () => _backendTokenObscured = !_backendTokenObscured),
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isTestingConnection ? null : _testConnection,
                          icon: _isTestingConnection
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.wifi_tethering, size: 16),
                          label: const Text('Test Connection'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary),
                          onPressed: _saveBackend,
                          icon: const Icon(Icons.save_outlined, size: 16),
                          label: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Monthly Budgets ───────────────────────────────────────────────
          _SectionHeader(icon: Icons.account_balance_wallet_outlined, title: 'Monthly Budgets'),
          _Card(
            child: Consumer(builder: (_, ref, __) {
              final budgetState = ref.watch(budgetProvider);
              return Column(
                children: [
                  ...budgetState.budgets.map((b) => ListTile(
                    leading: const Icon(Icons.donut_small_outlined),
                    title: Text(b.category),
                    subtitle: LinearProgressIndicator(
                      value: b.utilizedPercent,
                      backgroundColor: AppColors.outlineVariant.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        b.utilizedPercent >= 1.0
                            ? AppColors.tertiary
                            : b.utilizedPercent >= 0.8
                                ? Colors.orange
                                : AppColors.secondary,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => ref.read(budgetProvider.notifier).deleteBudget(b.id),
                    ),
                  )),
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                    title: const Text('Add budget category'),
                    onTap: _showAddBudgetDialog,
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 20),

          // ── SMS Import ───────────────────────────────────────────────────
          _SectionHeader(icon: Icons.sms_outlined, title: 'SMS Import'),
          _Card(
            child: ListTile(
              leading: const Icon(Icons.import_export),
              title: const Text('Import from bank SMS'),
              subtitle: const Text('Scan inbox and auto-detect bank transactions'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/sms-import'),
            ),
          ),
          const SizedBox(height: 20),

          // ── Notifications ────────────────────────────────────────────────
          _SectionHeader(icon: Icons.notifications_outlined, title: 'Notifications'),
          _Card(
            child: Consumer(builder: (ctx, ref, __) {
              final notifState = ref.watch(notificationProvider);
              final notifier = ref.read(notificationProvider.notifier);
              return Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.wb_sunny_outlined),
                    title: const Text('Morning Recap'),
                    subtitle: const Text('Daily 8 AM financial summary'),
                    value: notifState.morningEnabled,
                    onChanged: (v) async {
                      if (v) {
                        final svc = ref.read(notificationServiceProvider);
                        final granted = await svc.requestPermission();
                        if (!granted) return;
                      }
                      await notifier.toggleMorning(v);
                    },
                    activeColor: AppColors.primary,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.nightlight_round_outlined),
                    title: const Text('Evening Nudge'),
                    subtitle: const Text('Daily 9 PM expense reminder'),
                    value: notifState.eveningEnabled,
                    onChanged: (v) async {
                      if (v) {
                        final svc = ref.read(notificationServiceProvider);
                        final granted = await svc.requestPermission();
                        if (!granted) return;
                      }
                      await notifier.toggleEvening(v);
                    },
                    activeColor: AppColors.primary,
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 20),

          // ── Data Management ──────────────────────────────────────────────
          _SectionHeader(icon: Icons.storage_outlined, title: 'Data'),
          _Card(
            child: ListTile(
              leading: const Icon(Icons.delete_sweep_outlined, color: Colors.orange),
              title: const Text('Clear chat history'),
              subtitle: const Text('Remove all AI chat messages'),
              onTap: _clearChatHistory,
            ),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          // Account section
          Text(
            'Account',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          // Show logged-in user info
          Consumer(builder: (context, ref, _) {
            final auth = ref.watch(authProvider);
            if (auth.userEmail != null) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, size: 18, color: Color(0xFF6B7280)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        auth.userEmail!,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          }),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.spending,
                side: BorderSide(color: AppColors.spending.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text('Sign Out', style: TextStyle(color: AppColors.spending)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && mounted) {
                  await ref.read(authProvider.notifier).logout();
                  if (mounted) context.go('/login');
                }
              },
            ),
          ),
          const SizedBox(height: 32),

          // Version info
          Center(
            child: Text(
              'Echelon Finance • The Ledger v1.1.0',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.outlineVariant.withOpacity(0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  const _Field({required this.controller, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}

class _KeyField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscured;
  final VoidCallback onToggle;
  final bool isActive;

  const _KeyField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.obscured,
    required this.onToggle,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: controller,
        obscureText: obscured,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: isActive ? null : AppColors.onSurfaceVariant,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: isActive
              ? TextStyle(color: AppColors.primary)
              : TextStyle(color: AppColors.onSurfaceVariant),
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.onSurfaceVariant.withOpacity(0.5), fontSize: 12),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          prefixIcon: Icon(
            Icons.key_outlined,
            size: 20,
            color: isActive ? AppColors.primary : AppColors.onSurfaceVariant,
          ),
          suffixIcon: IconButton(
            icon: Icon(obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
            onPressed: onToggle,
          ),
        ),
      ),
    );
  }
}

class _CurrencyToggle extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  const _CurrencyToggle({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'INR', label: Text('₹ INR')),
        ButtonSegment(value: 'USD', label: Text('\$ USD')),
      ],
      selected: {current},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}
