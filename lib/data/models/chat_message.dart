import 'transaction.dart';

enum MessageRole { user, assistant }

class ChatMessage {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final AppTransaction? parsedTransaction;
  final bool isError;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.parsedTransaction,
    this.isError = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'role': role.name,
    'content': content,
    'intent': 'conversation',
    'timestamp': timestamp.millisecondsSinceEpoch,
    'parsed_transaction_id': parsedTransaction?.id,
    'is_error': isError ? 1 : 0,
  };

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
    id: m['id'] as String,
    role: MessageRole.values.firstWhere(
      (e) => e.name == m['role'],
      orElse: () => MessageRole.assistant,
    ),
    content: m['content'] as String,
    timestamp: DateTime.fromMillisecondsSinceEpoch(m['timestamp'] as int),
    isError: (m['is_error'] as int? ?? 0) == 1,
  );
}
