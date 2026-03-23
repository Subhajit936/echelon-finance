class AppConstants {
  AppConstants._();

  // ── Claude API ────────────────────────────────────────────────────────────
  static const String claudeApiUrl = 'https://api.anthropic.com/v1/messages';
  /// Haiku is used for chat (8× cheaper, ~3× faster than Sonnet).
  static const String claudeChatModel = 'claude-haiku-4-5-20251001';
  /// Sonnet for richer insight generation only.
  static const String claudeInsightModel = 'claude-haiku-4-5-20251001';
  static const String claudeApiVersion = '2023-06-01';

  // ── OpenAI API ────────────────────────────────────────────────────────────
  static const String openAiApiUrl = 'https://api.openai.com/v1/chat/completions';
  static const String openAiChatModel = 'gpt-4o-mini';

  // ── Secure storage keys ───────────────────────────────────────────────────
  static const String claudeApiKeyStorageKey = 'claude_api_key';
  /// Legacy alias kept so existing installs continue to work.
  static const String apiKeyStorageKey = 'claude_api_key';
  static const String openAiApiKeyStorageKey = 'openai_api_key';
  static const String aiProviderStorageKey = 'ai_provider';

  // ── Database ──────────────────────────────────────────────────────────────
  static const String dbName = 'echelon_finance.db';
  static const int dbVersion = 1;
  static const String userProfileId = '1';

  // ── Pagination ────────────────────────────────────────────────────────────
  static const int transactionPageSize = 20;
  static const int maxChatHistory = 20;

  // ── Backend (Railway) ─────────────────────────────────────────────────────
  /// Default Railway deployment URL — used when user has not overridden it.
  static const String defaultBackendUrl =
      'https://echelon-finance-production.up.railway.app';
  static const String defaultBackendToken = 'EchelonBackend2026';

  // ── API / Sync ────────────────────────────────────────────────────────────
  static const apiTimeout = Duration(seconds: 15);
  static const syncRetryDelay = Duration(seconds: 5);

  // ── Currencies ────────────────────────────────────────────────────────────
  static const String inr = 'INR';
  static const String usd = 'USD';

  // ── System prompt ─────────────────────────────────────────────────────────
  /// Strict financial-only prompt. Tokens are kept minimal — chat uses max 256.
  static String claudeSystemPrompt(String currency) => '''
You are Echelon, a personal finance AI assistant inside "The Ledger" app.
Currency: $currency (${currency == 'INR' ? 'Indian Rupee ₹' : 'US Dollar \$'}).

SCOPE: You ONLY discuss personal finance — budgets, spending, savings, income, investments, debt, financial goals. If the user asks about anything unrelated, reply: "I can only help with financial topics. Try asking about your spending or savings."

## When user describes a transaction, output EXACTLY this structure:
<transaction>
{
  "merchant": "name",
  "category": "food|transport|housing|utilities|entertainment|healthcare|education|shopping|salary|freelance|investment|other",
  "type": "income|expense",
  "amount": number,
  "date": "YYYY-MM-DD",
  "status": "cleared|pending|subscription|approved",
  "note": ""
}
</transaction>
Then ONE sentence confirming the log.

## Rules:
- Max 80 words per reply (unless user asks for explanation).
- Never invent data. Ask ONE question if amount/category is unclear.
- Use ${currency == 'INR' ? '₹' : '\$'} symbol.
- Decline off-topic requests firmly but politely.
''';

  /// Shorter prompt for insight generation (no transaction logging needed).
  static String insightSystemPrompt(String currency) => '''
You are a financial analyst. Provide 3 concise, actionable savings tips based on the data provided. Each tip: one sentence. Currency: $currency. Be specific, not generic.
''';
}
