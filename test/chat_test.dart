import 'package:flutter_test/flutter_test.dart';
import 'package:boykotbarkodu/services/chat/chat_models.dart';
import 'package:boykotbarkodu/services/chat/chat_service.dart';
import 'package:boykotbarkodu/services/chat/grounded_provider.dart';
import 'package:boykotbarkodu/services/chat/topic_gate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TopicGate Tests', () {
    test('Boycott-related questions are allowed', () {
      expect(TopicGate.isRelevant('Ariel neden boykotta?'), isTrue);
      expect(TopicGate.isRelevant('Nescafe yerine ne alabilirim?'), isTrue);
      expect(TopicGate.isRelevant('729 barkodu nedir?'), isTrue);
      expect(TopicGate.isRelevant('Coca-Cola boykot mu?'), isTrue);
      expect(TopicGate.isRelevant('Bu ürün yerli mi?'), isTrue);
    });

    test('Off-topic questions are rejected', () {
      expect(TopicGate.isRelevant('Yarın hava durumu nasıl olacak?'), isFalse);
      expect(TopicGate.isRelevant('WWE figürleri nereden alınır?'), isFalse);
      expect(TopicGate.isRelevant('Bana bir fıkra anlatır mısın?'), isFalse);
      expect(TopicGate.isRelevant('Python nasıl öğrenilir?'), isFalse);
    });
  });

  group('GroundedChatProvider Tests', () {
    final provider = GroundedChatProvider();

    test('729 barcode question returns FAQ', () async {
      final reply = await provider.reply('729 barkod ne anlama gelir?', []);
      expect(reply, isNotNull);
      expect(reply!.text.contains('729'), isTrue);
      expect(reply.text.contains('İsrail'), isTrue);
    });

    test('Known boycotted brand returns status and reason', () async {
      final reply = await provider.reply('Ariel neden boykotta?', []);
      expect(reply, isNotNull);
      expect(reply!.text.toLowerCase().contains('boykot'), isTrue);
      expect(reply.text.contains('Procter & Gamble'), isTrue);
      expect(reply.sources.isNotEmpty, isTrue);
    });

    test('Alternatives query returns alternative products', () async {
      final reply = await provider.reply('Nescafe yerine ne alabilirim?', []);
      expect(reply, isNotNull);
      expect(reply!.text.toLowerCase().contains('alternatif'), isTrue);
      expect(reply.text.toLowerCase().contains('mehmet efendi') || reply.text.contains('Türk Kahvesi'), isTrue);
    });

    test('Follow-up with history resolves previous brand', () async {
      final history = [
        ChatMessage(role: ChatRole.user, text: 'Nescafe boykot mu?'),
        ChatMessage(role: ChatRole.assistant, text: 'Nescafe boykot listesinde yer almaktadır.'),
      ];
      final reply = await provider.reply('Peki alternatifi nedir?', history);
      expect(reply, isNotNull);
      expect(reply!.text.toLowerCase().contains('alternatif'), isTrue);
    });
  });

  group('ChatService Tests', () {
    final service = ChatService();

    test('Off-topic question triggers polite refusal notice', () async {
      final reply = await service.ask('Bana yemek tarifi ver', []);
      expect(reply.isNotice, isTrue);
      expect(reply.text.contains('sadece boykotla ilgili'), isTrue);
    });

    test('Relevant brand question returns answer with sources', () async {
      final reply = await service.ask('Coca-Cola boykot mu?', []);
      expect(reply.isNotice, isFalse);
      expect(reply.text.toLowerCase().contains('boykot'), isTrue);
      expect(reply.sources.isNotEmpty, isTrue);
    });
  });
}
