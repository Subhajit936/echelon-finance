import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/transaction.dart';
import '../../../core/utils/number_formatter.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final String currency;

  const ChatBubble({super.key, required this.message, required this.currency});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) _Avatar(isUser: false),
          if (!isUser) const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isUser
                        ? const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryContainer],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isUser
                        ? null
                        : message.isError
                            ? AppColors.tertiaryContainer
                            : AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isUser
                          ? const Radius.circular(16)
                          : const Radius.circular(4),
                      bottomRight: isUser
                          ? const Radius.circular(4)
                          : const Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    message.content,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: isUser ? Colors.white : AppColors.onSurface,
                    ),
                  ),
                ),
                // Transaction confirmation card
                if (!isUser && message.parsedTransaction != null)
                  _TransactionConfirmCard(
                    merchant: message.parsedTransaction!.merchant,
                    amount: message.parsedTransaction!.amount,
                    category: message.parsedTransaction!.category.label,
                    type: message.parsedTransaction!.type.name,
                    currency: currency,
                  ),
                const SizedBox(height: 2),
                Text(
                  _formatTime(message.timestamp),
                  style: AppTextStyles.labelSm,
                ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 8),
          if (isUser) _Avatar(isUser: true),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _Avatar extends StatelessWidget {
  final bool isUser;
  const _Avatar({required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isUser ? AppColors.surfaceContainerHigh : AppColors.primary.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isUser ? Icons.person : Icons.smart_toy_outlined,
        size: 18,
        color: isUser ? AppColors.onSurfaceVariant : AppColors.primary,
      ),
    );
  }
}

class _TransactionConfirmCard extends StatelessWidget {
  final String merchant;
  final double amount;
  final String category;
  final String type;
  final String currency;

  const _TransactionConfirmCard({
    required this.merchant,
    required this.amount,
    required this.category,
    required this.type,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = type == 'income';
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isIncome ? AppColors.secondaryContainer : AppColors.tertiaryContainer)
            .withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: isIncome ? AppColors.secondary : AppColors.tertiary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Logged: $merchant — ${NumberFormatter.formatCurrency(amount, currency)}',
              style: AppTextStyles.labelLg.copyWith(
                color: isIncome ? AppColors.secondary : AppColors.tertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
