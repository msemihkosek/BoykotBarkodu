import 'chat_models.dart';

/// Sohbet cevabı üreten kaynaklar için ortak arayüz.
///
/// [reply] cevap veremiyorsa `null` döner; [ChatService] bir sonraki sağlayıcıyı dener.
/// Böylece ileride bir LLM sağlayıcısı (ör. resmi ücretsiz bir API) eklemek için
/// yalnızca bu arayüzü uygulamak yeterlidir.
abstract class ChatProvider {
  String get name;

  Future<ChatMessage?> reply(String question, List<ChatMessage> history);
}
