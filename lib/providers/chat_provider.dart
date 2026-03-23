import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/models/chat_message.dart';
import '../data/models/transaction.dart';
import '../core/utils/transaction_parser.dart';
import '../core/utils/offline_responder.dart';
import 'database_provider.dart';
import 'transaction_provider.dart';
import 'user_profile_provider.dart';

const _uuid = Uuid();

class ChatState {
  final List<ChatMessage> messages;
  final bool isAiThinking;
  final bool isListening;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.isAiThinking = false,
    this.isListening = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isAiThinking,
    bool? isListening,
    String? error,
  }) => ChatState(
    messages: messages ?? this.messages,
    isAiThinking: isAiThinking ?? this.isAiThinking,
    isListening: isListening ?? this.isListening,
    error: error,
  );
}

class ChatNotifier extends StateNotifier<ChatState> {
  final Ref _ref;
  ChatNotifier(this._ref) : super(const ChatState()) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final repo = _ref.read(chatRepoProvider);
    final msgs = await repo.getRecent(50);
    state = state.copyWith(messages: msgs);
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final currency = _ref.read(currencyProvider);
    final userMsg = ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.user,
      content: text.trim(),
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isAiThinking: true,
      error: null,
    );
    await _ref.read(chatRepoProvider).insert(userMsg);

    try {
      final ai = _ref.read(aiServiceProvider);
      final isConfigured = await ai.isConfigured();

      String response;
      AppTransaction? parsed;

      // ── Offline-first: try keyword matching before calling the API ──────
      // This saves tokens even when an API key IS configured.
      final offline = OfflineResponder.respond(text.trim(), currency);
      final offlineHandled = offline.isTransaction ||
          !offline.responseText.contains('financial topics');
      // offlineHandled = true when OfflineResponder gave a real answer
      // (a transaction log OR a balance/budget/savings guidance reply).
      // offlineHandled = false only for off-topic messages that we want
      // to forward to the AI so it can politely decline in full context.

      if (!isConfigured || offlineHandled) {
        // ── Handled locally: no API call needed ──────────────────────────
        response = offline.responseText;

        if (offline.isTransaction && offline.amount != null) {
          final txnType = offline.type == 'income'
              ? TransactionType.income
              : TransactionType.expense;
          final sms = _ref.read(smsServiceProvider);
          final inferredCategory = sms.inferCategoryFromMerchant(
            offline.merchant ?? 'General',
            txnType,
          );
          parsed = AppTransaction(
            id: _uuid.v4(),
            merchant: offline.merchant ?? 'General',
            category: inferredCategory,
            type: txnType,
            amount: offline.amount!,
            date: DateTime.now(),
            status: TransactionStatus.cleared,
            note: 'Added via AI Buddy',
            currency: currency,
            createdAt: DateTime.now(),
          );
          await _ref.read(transactionProvider.notifier).add(parsed);
        }
      } else {
        // ── Online mode: OfflineResponder couldn't handle — call AI API ──
        response = await ai.sendMessage(
          history: state.messages.where((m) => m != userMsg).toList(),
          userMessage: text.trim(),
          currency: currency,
        );
        parsed = TransactionParser.tryParse(response, currency);
        if (parsed != null) {
          await _ref.read(transactionProvider.notifier).add(parsed);
        }
      }

      final displayText = TransactionParser.stripTransactionBlock(response);
      final aiMsg = ChatMessage(
        id: _uuid.v4(),
        role: MessageRole.assistant,
        content: displayText.isNotEmpty ? displayText : response,
        timestamp: DateTime.now(),
        parsedTransaction: parsed,
      );

      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        isAiThinking: false,
      );
      await _ref.read(chatRepoProvider).insert(aiMsg);
    } catch (e) {
      final errorMsg = ChatMessage(
        id: _uuid.v4(),
        role: MessageRole.assistant,
        content: e.toString(),
        timestamp: DateTime.now(),
        isError: true,
      );
      state = state.copyWith(
        messages: [...state.messages, errorMsg],
        isAiThinking: false,
        error: e.toString(),
      );
    }
  }

  void setListening(bool value) => state = state.copyWith(isListening: value);

  Future<void> clearHistory() async {
    await _ref.read(chatRepoProvider).clear();
    state = const ChatState();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref);
});
