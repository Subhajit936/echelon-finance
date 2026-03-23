import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/sms_service.dart';
import '../../providers/database_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/user_profile_provider.dart';

class SmsImportScreen extends ConsumerStatefulWidget {
  const SmsImportScreen({super.key});

  @override
  ConsumerState<SmsImportScreen> createState() => _SmsImportScreenState();
}

class _SmsImportScreenState extends ConsumerState<SmsImportScreen> {
  List<ParsedSmsTransaction> _items = [];
  bool _loading = false;
  bool _importing = false;
  String? _error;
  int _daysBack = 90;
  int _importedCount = 0;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _loading = true;
      _error = null;
      _items = [];
    });

    try {
      final sms = ref.read(smsServiceProvider);
      final hasPermission = await sms.requestPermission();
      if (!hasPermission) {
        setState(() {
          _error = 'SMS permission denied. Grant it in Android Settings → Apps → Echelon → Permissions.';
          _loading = false;
        });
        return;
      }

      final currency = ref.read(currencyProvider);
      final results = await sms.fetchBankTransactions(
        daysBack: _daysBack,
        currency: currency,
      );

      setState(() {
        _items = results;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error reading SMS: $e';
        _loading = false;
      });
    }
  }

  Future<void> _importSelected() async {
    final selected = _items.where((i) => i.isSelected).toList();
    if (selected.isEmpty) return;

    setState(() => _importing = true);
    int count = 0;
    int skipped = 0;

    final repo = ref.read(transactionRepoProvider);
    for (final item in selected) {
      final t = item.transaction;
      final isDuplicate = await repo.existsByKey(t.merchant, t.amount, t.date);
      if (isDuplicate) {
        skipped++;
        continue;
      }
      await ref.read(transactionProvider.notifier).add(t);
      count++;
    }

    setState(() {
      _importing = false;
      _importedCount = count;
      _items = [];
    });

    if (mounted) {
      final msg = skipped > 0
          ? 'Imported $count transactions ($skipped duplicates skipped)'
          : 'Imported $count transactions';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _toggleAll(bool? value) {
    final v = value ?? false;
    setState(() {
      for (final item in _items) {
        item.isSelected = v;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _items.where((i) => i.isSelected).length;

    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Import from SMS'),
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        actions: [
          if (_items.isNotEmpty)
            PopupMenuButton<int>(
              icon: const Icon(Icons.tune),
              onSelected: (days) {
                _daysBack = days;
                _scan();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 30, child: Text('Last 30 days')),
                const PopupMenuItem(value: 90, child: Text('Last 90 days')),
                const PopupMenuItem(value: 180, child: Text('Last 6 months')),
              ],
            ),
        ],
      ),
      body: _buildBody(selectedCount),
      bottomNavigationBar: _items.isNotEmpty
          ? _BottomBar(
              selectedCount: selectedCount,
              totalCount: _items.length,
              onToggleAll: _toggleAll,
              onImport: _importing ? null : _importSelected,
              importing: _importing,
            )
          : null,
    );
  }

  Widget _buildBody(int selectedCount) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Scanning bank messages...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sms_failed_outlined, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _scan,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_importedCount > 0 && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, size: 56, color: Colors.green),
            const SizedBox(height: 16),
            Text('Imported $_importedCount transactions',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('They\'re now in your transaction log.'),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _scan,
              icon: const Icon(Icons.refresh),
              label: const Text('Scan again'),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 56, color: AppColors.onSurfaceVariant),
              const SizedBox(height: 16),
              const Text('No bank transactions found', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Text(
                'Make sure you\'ve received bank SMS in the last $_daysBack days.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _scan,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _items[index];
        return _SmsCard(
          item: item,
          onToggle: (v) => setState(() => item.isSelected = v ?? false),
        );
      },
    );
  }
}

class _SmsCard extends StatelessWidget {
  final ParsedSmsTransaction item;
  final ValueChanged<bool?> onToggle;

  const _SmsCard({required this.item, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final txn = item.transaction;
    final isIncome = txn.type.name == 'income';
    final color = isIncome ? Colors.green : Colors.red;
    final sign = isIncome ? '+' : '-';
    final currencySymbol = txn.currency == 'INR' ? '₹' : '\$';
    final formattedAmount = NumberFormat('#,##0.00').format(txn.amount);
    final formattedDate = DateFormat('dd MMM yyyy').format(txn.date);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: item.isSelected
              ? AppColors.primary.withOpacity(0.4)
              : AppColors.outlineVariant.withOpacity(0.2),
          width: item.isSelected ? 1.5 : 1,
        ),
      ),
      color: item.isSelected
          ? AppColors.primary.withOpacity(0.04)
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onToggle(!item.isSelected),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Checkbox(
                value: item.isSelected,
                onChanged: onToggle,
                activeColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            txn.merchant,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '$sign$currencySymbol$formattedAmount',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _Chip(txn.category.name),
                        const SizedBox(width: 6),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.smsBody,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: AppColors.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int selectedCount;
  final int totalCount;
  final ValueChanged<bool?> onToggleAll;
  final VoidCallback? onImport;
  final bool importing;

  const _BottomBar({
    required this.selectedCount,
    required this.totalCount,
    required this.onToggleAll,
    required this.onImport,
    required this.importing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: AppColors.outlineVariant.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          Row(
            children: [
              Checkbox(
                value: selectedCount == totalCount
                    ? true
                    : selectedCount == 0
                        ? false
                        : null,
                tristate: true,
                onChanged: onToggleAll,
              ),
              Text('$selectedCount / $totalCount'),
            ],
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: onImport,
            icon: importing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download_outlined),
            label: Text(importing ? 'Importing...' : 'Import selected'),
          ),
        ],
      ),
    );
  }
}
