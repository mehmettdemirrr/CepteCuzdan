import 'enums.dart';

/// Sohbet geçmişindeki bir mesaj. Onaylanan mesaj ilgili işleme bağlanır.
class ChatMessage {
  const ChatMessage({
    this.id,
    required this.role,
    required this.content,
    this.transactionId,
    required this.createdAt,
  });

  final int? id;
  final ChatRole role;
  final String content;
  final int? transactionId;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'role': role.name,
    'content': content,
    'transaction_id': transactionId,
    'created_at': createdAt.toIso8601String(),
  };

  factory ChatMessage.fromMap(Map<String, Object?> m) => ChatMessage(
    id: m['id'] as int?,
    role: ChatRole.values.byName(m['role'] as String),
    content: m['content'] as String,
    transactionId: m['transaction_id'] as int?,
    createdAt: DateTime.parse(m['created_at'] as String),
  );

  ChatMessage copyWith({
    int? id,
    ChatRole? role,
    String? content,
    int? transactionId,
    DateTime? createdAt,
  }) => ChatMessage(
    id: id ?? this.id,
    role: role ?? this.role,
    content: content ?? this.content,
    transactionId: transactionId ?? this.transactionId,
    createdAt: createdAt ?? this.createdAt,
  );

  @override
  bool operator ==(Object other) =>
      other is ChatMessage &&
      other.id == id &&
      other.role == role &&
      other.content == content &&
      other.transactionId == transactionId &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, role, content, transactionId, createdAt);
}
