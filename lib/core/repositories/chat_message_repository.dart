import '../models/chat_message.dart';

/// Sohbet geçmişi (Berkay'ın asistan ekranı kullanır).
abstract class ChatMessageRepository {
  Future<int> add(ChatMessage m);

  /// Eskiden yeniye. `limit` verilirse en son `limit` mesaj (yine eskiden yeniye).
  Future<List<ChatMessage>> all({int? limit});

  Future<void> linkTransaction(int messageId, int transactionId);

  Future<void> clear();
}
