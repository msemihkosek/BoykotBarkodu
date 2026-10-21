import 'chat_models.dart';
import 'chat_provider.dart';
import 'company_knowledge_service.dart';
import 'grounded_provider.dart';
import 'topic_gate.dart';

/// Soruyu esnek konu kapısından geçirir, soru tipine göre en uygun sağlayıcıyı
/// (Boykot Veri Sağlayıcısı veya Şirket & Kavram Bilgi Motoru) önceliklendirerek çalıştırır.
class ChatService {
  final List<ChatProvider> providers;
  final CompanyKnowledgeService _knowledgeService;
  final GroundedChatProvider _groundedProvider;

  ChatService({
    List<ChatProvider>? providers,
    CompanyKnowledgeService? knowledgeService,
    GroundedChatProvider? groundedProvider,
  })  : _knowledgeService = knowledgeService ?? CompanyKnowledgeService(),
        _groundedProvider = groundedProvider ?? GroundedChatProvider(),
        providers = providers ??
            [
              groundedProvider ?? GroundedChatProvider(),
              knowledgeService ?? CompanyKnowledgeService(),
            ];

  Future<ChatMessage> ask(String question, List<ChatMessage> history) async {
    final q = question.trim();

    // 1. Esnek Konu Kapısı Kontrolü (Devam eden sohbetteki hiçbir takip sorusu engellenmez)
    if (!TopicGate.isRelevant(q, history)) {
      return ChatMessage(
        role: ChatRole.assistant,
        text: TopicGate.refusalText,
        isNotice: true,
      );
    }

    // 2. Soru tipine göre sağlayıcı sırasını belirle
    // Eğer soru "nedir, ne iş yapar, kimdir, neresi, hakkında" gibi bir şirket/kavram
    // açıklaması istiyorsa önce CompanyKnowledgeService devreye girer.
    final isEntityInquiry = RegExp(
      r'\b(nedir|kimdir|ne\s+iş\s+yapar|ne\s+demek|neresi|nerede|hakkında|kimin\s+şirketi|bu\s+şirket|bu\s+firma|ne\s+üretiyor)\b',
      caseSensitive: false,
    ).hasMatch(q);

    final activeProviders = isEntityInquiry
        ? [_knowledgeService, _groundedProvider]
        : [_groundedProvider, _knowledgeService];

    for (final provider in activeProviders) {
      try {
        final reply = await provider.reply(q, history);
        if (reply != null && reply.text.trim().isNotEmpty) {
          return reply;
        }
      } catch (_) {
        // Bu sağlayıcı hata verirse bir sonrakini dene
      }
    }

    // 3. Hiçbiri cevap veremezse tahmin uydurma, kaynaklı yönlendirme sun
    final query = Uri.encodeComponent('$q boykot');
    return ChatMessage(
      role: ChatRole.assistant,
      text: 'Bu şirket veya konu hakkında arşivlerimizde ve açık ansiklopedide doğrudan eşleşen bir kayıt bulamadım. '
          'İsmi farklı yazarak tekrar sorabilir veya aşağıdaki kaynaklardan araştırabilirsiniz:',
      isNotice: true,
      sources: [
        const ChatSource(label: 'BYKT.ORG', url: 'https://bykt.org'),
        const ChatSource(label: 'Boykot Dedektifi', url: 'https://boykotdedektifi.com'),
        const ChatSource(label: 'Boykot.co', url: 'https://www.boykot.co'),
        ChatSource(label: 'DuckDuckGo\'da Ara', url: 'https://duckduckgo.com/?q=$query'),
      ],
    );
  }
}
