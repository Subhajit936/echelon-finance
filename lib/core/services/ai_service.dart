import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';
import '../../data/models/chat_message.dart';

/// Which AI backend the user has configured.
enum AIProvider { claude, openai }

extension AIProviderX on AIProvider {
  String get label => this == AIProvider.claude ? 'Claude (Anthropic)' : 'OpenAI';
  String get storageValue => name; // 'claude' | 'openai'
  static AIProvider fromStorage(String? value) =>
      value == 'openai' ? AIProvider.openai : AIProvider.claude;
}

/// Unified AI service — routes to Claude or OpenAI transparently.
/// All callers only depend on this class, never directly on either backend.
class AIService {
  final FlutterSecureStorage _storage;
  AIService(this._storage);

  // ── Key management ──────────────────────────────────────────────────────

  Future<String?> getClaudeKey() =>
      _storage.read(key: AppConstants.claudeApiKeyStorageKey);
  Future<void> saveClaudeKey(String key) =>
      _storage.write(key: AppConstants.claudeApiKeyStorageKey, value: key);

  Future<String?> getOpenAiKey() =>
      _storage.read(key: AppConstants.openAiApiKeyStorageKey);
  Future<void> saveOpenAiKey(String key) =>
      _storage.write(key: AppConstants.openAiApiKeyStorageKey, value: key);

  Future<AIProvider> getProvider() async {
    final v = await _storage.read(key: AppConstants.aiProviderStorageKey);
    return AIProviderX.fromStorage(v);
  }

  Future<void> saveProvider(AIProvider p) =>
      _storage.write(key: AppConstants.aiProviderStorageKey, value: p.storageValue);

  /// Returns the active key for the currently selected provider.
  Future<String?> getActiveKey() async {
    final provider = await getProvider();
    return provider == AIProvider.openai ? getOpenAiKey() : getClaudeKey();
  }

  /// Returns true if at least one provider is configured.
  Future<bool> isConfigured() async {
    final claude = await getClaudeKey();
    final openai = await getOpenAiKey();
    return (claude != null && claude.isNotEmpty) ||
        (openai != null && openai.isNotEmpty);
  }

  // ── Chat ────────────────────────────────────────────────────────────────

  /// Sends a chat message and returns the assistant's reply.
  /// Automatically uses the selected provider (Claude Haiku / GPT-4o-mini).
  Future<String> sendMessage({
    required List<ChatMessage> history,
    required String userMessage,
    required String currency,
    String? budgetContext,
  }) async {
    final provider = await getProvider();
    return provider == AIProvider.openai
        ? _sendOpenAI(
            history: history,
            userMessage: userMessage,
            currency: currency,
            budgetContext: budgetContext,
          )
        : _sendClaude(
            history: history,
            userMessage: userMessage,
            currency: currency,
            budgetContext: budgetContext,
            model: AppConstants.claudeChatModel,
            maxTokens: 400, // raised from 256 to prevent truncated replies
          );
  }

  // ── Insights (always Claude Haiku for cost) ──────────────────────────────

  Future<String> generateInsights({
    required String currency,
    required double savingsRate,
    required Map<String, double> categorySpend,
    required double healthScore,
  }) async {
    // Always prefer Claude for insights; fall back to OpenAI if no Claude key.
    final claudeKey = await getClaudeKey();
    final summary = '''
Savings rate: ${savingsRate.toStringAsFixed(1)}%
Health score: ${healthScore.toStringAsFixed(0)}/100
Top spending: ${categorySpend.entries.take(3).map((e) => '${e.key}: ${e.value.toStringAsFixed(0)}').join(', ')}
''';

    if (claudeKey != null && claudeKey.isNotEmpty) {
      return _sendClaude(
        history: [],
        userMessage: summary,
        currency: currency,
        systemOverride: AppConstants.insightSystemPrompt(currency),
        model: AppConstants.claudeInsightModel,
        maxTokens: 512,
      );
    }

    final openAiKey = await getOpenAiKey();
    if (openAiKey != null && openAiKey.isNotEmpty) {
      return _sendOpenAI(
        history: [],
        userMessage: summary,
        currency: currency,
        systemOverride: AppConstants.insightSystemPrompt(currency),
      );
    }

    throw AIException('No AI key configured. Add a key in Settings.');
  }

  // ── Private: Claude backend ─────────────────────────────────────────────

  Future<String> _sendClaude({
    required List<ChatMessage> history,
    required String userMessage,
    required String currency,
    String? budgetContext,
    String? systemOverride,
    required String model,
    required int maxTokens,
  }) async {
    final key = await getClaudeKey();
    if (key == null || key.isEmpty) {
      throw AIException('Claude API key not set. Add it in Settings → AI Provider.');
    }

    final messages = <Map<String, String>>[];
    final recent = history.length > AppConstants.maxChatHistory
        ? history.sublist(history.length - AppConstants.maxChatHistory)
        : history;
    for (final msg in recent) {
      messages.add({
        'role': msg.role == MessageRole.user ? 'user' : 'assistant',
        'content': msg.content,
      });
    }
    messages.add({'role': 'user', 'content': userMessage});

    var system = systemOverride ?? AppConstants.claudeSystemPrompt(currency);
    if (budgetContext != null && budgetContext.isNotEmpty) {
      system += '\n\n<budget_context>\n$budgetContext\n</budget_context>';
    }

    final response = await http.post(
      Uri.parse(AppConstants.claudeApiUrl),
      headers: {
        'x-api-key': key,
        'anthropic-version': AppConstants.claudeApiVersion,
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'max_tokens': maxTokens,
        'system': system,
        'messages': messages,
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ((data['content'] as List).first as Map)['text'] as String;
    } else if (response.statusCode == 401) {
      throw AIException('Invalid Claude API key. Check Settings → AI Provider.');
    } else if (response.statusCode == 429) {
      throw AIException('Claude rate limit hit. Wait a moment and try again.');
    } else {
      final err = jsonDecode(response.body);
      throw AIException('Claude error: ${err['error']?['message'] ?? response.statusCode}');
    }
  }

  // ── Private: OpenAI backend ─────────────────────────────────────────────

  Future<String> _sendOpenAI({
    required List<ChatMessage> history,
    required String userMessage,
    required String currency,
    String? budgetContext,
    String? systemOverride,
  }) async {
    final key = await getOpenAiKey();
    if (key == null || key.isEmpty) {
      throw AIException('OpenAI API key not set. Add it in Settings → AI Provider.');
    }

    var system = systemOverride ?? AppConstants.claudeSystemPrompt(currency);
    if (budgetContext != null && budgetContext.isNotEmpty) {
      system += '\n\nBudget context:\n$budgetContext';
    }

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': system},
    ];

    final recent = history.length > AppConstants.maxChatHistory
        ? history.sublist(history.length - AppConstants.maxChatHistory)
        : history;
    for (final msg in recent) {
      messages.add({
        'role': msg.role == MessageRole.user ? 'user' : 'assistant',
        'content': msg.content,
      });
    }
    messages.add({'role': 'user', 'content': userMessage});

    final response = await http.post(
      Uri.parse(AppConstants.openAiApiUrl),
      headers: {
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': AppConstants.openAiChatModel,
        'max_tokens': 400,
        'messages': messages,
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['choices'] as List).first['message']['content'] as String;
    } else if (response.statusCode == 401) {
      throw AIException('Invalid OpenAI API key. Check Settings → AI Provider.');
    } else if (response.statusCode == 429) {
      throw AIException('OpenAI rate limit hit. Wait a moment and try again.');
    } else {
      final err = jsonDecode(response.body);
      throw AIException('OpenAI error: ${err['error']?['message'] ?? response.statusCode}');
    }
  }
}

class AIException implements Exception {
  final String message;
  AIException(this.message);

  @override
  String toString() => message;
}
