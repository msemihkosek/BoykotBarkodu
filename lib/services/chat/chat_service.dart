import 'chat_models.dart';
import 'chat_provider.dart';
import 'grounded_provider.dart';
import 'topic_gate.dart';

/// Soruyu önce konu kapısından geçirir, sonra sağlayıcıları sırayla dener.
/// Hiçbiri cevap veremezse uydurmaz; bulunamadı mesajı ve arama bağlantıları verir.
class ChatService {
  final List<ChatProvider> providers;

  ChatService({List<ChatProvider>? providers})
      : providers = providers ?? [GroundedChatProvider()];

  Future<ChatMessage> ask(String question, List<ChatMessage> history) async {
    final q = question.trim();

    if (!TopicGate.isRelevant(q) && !_isFollowUp(q, history)) {
      return ChatMessage(
        role: ChatRole.assistant,
        text: TopicGate.refusalText,
        isNotice: true,
      );
    }

    for (final provider in providers) {
      try {
        final reply = await provider.reply(q, history);
        if (reply != null) return reply;
      } catch (_) {
        // Bu sağlayıcı başarısız oldu; bir sonrakini dene
      }
    }

    final query = Uri.encodeComponent('$q boykot');
    return ChatMessage(
      role: ChatRole.assistant,
      text: 'Bu konuda doğrulanmış bir kayıt bulamadım, bu yüzden tahmin yürütmek istemiyorum. '
          'Markanın adını yazarak tekrar sorabilir veya kaynak sitelerde arayabilirsiniz.',
      isNotice: true,
      sources: [
        ChatSource(label: 'Boykot Dedektifi', url: 'https://boykotdedektifi.com'),
        ChatSource(label: 'Boykot.co', url: 'https://www.boykot.co'),
        ChatSource(label: 'DuckDuckGo\'da ara', url: 'https://duckduckgo.com/?q=$query'),
      ],
    );
  }

  /// "Peki alternatifi?" gibi kısa devam soruları, önceki konuşma boykotla ilgiliyse geçerlidir.
  bool _isFollowUp(String q, List<ChatMessage> history) {
    if (history.isEmpty) return false;
    final lower = q.toLowerCase();
    final short = lower.split(RegExp(r'\s+')).length <= 5;
    final hasAssistantAnswer = history.any((m) => !m.isUser && !m.isNotice);
    return short && hasAssistantAnswer &&
        (lower.contains('alternatif') || lower.contains('neden') ||
            lower.contains('peki') || lower.contains('kanıt') || lower.contains('kimin'));
  }
}
