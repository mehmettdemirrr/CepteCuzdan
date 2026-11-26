import 'package:sqflite/sqflite.dart';

import '../models/chat_message.dart';
import '../repositories/chat_message_repository.dart';

class SqliteChatMessageRepository implements ChatMessageRepository {
  SqliteChatMessageRepository(this._db);
  final Database _db;

  @override
  Future<int> add(ChatMessage m) =>
      _db.insert('chat_messages', m.toMap()..remove('id'));

  @override
  Future<List<ChatMessage>> all({int? limit}) async {
    final rows = await _db.query(
      'chat_messages',
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(ChatMessage.fromMap).toList().reversed.toList();
  }

  @override
  Future<void> linkTransaction(int messageId, int transactionId) async {
    await _db.update(
      'chat_messages',
      {'transaction_id': transactionId},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  @override
  Future<void> clear() async {
    await _db.delete('chat_messages');
  }
}
