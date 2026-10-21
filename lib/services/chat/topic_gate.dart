import '../offline_data.dart';
import 'chat_models.dart';

/// Sohbetin tüketim, markalar, şirketler, boykot gerekçeleri ve alternatifler
/// çerçevesinde akıcı ve bağlamsal çalışmasını sağlayan esnek konu kapısı.
class TopicGate {
  static const Set<String> _keywords = {
    'boykot', 'boykotlu', 'boykotta', 'boykotmu', 'alternatif', 'alternatifi',
    'muadil', 'yerli', 'milli', 'israil', 'filistin', 'gazze', 'siyonist',
    'marka', 'markasi', 'markalar', 'urun', 'urunu', 'urunler', 'sirket',
    'sirketi', 'sirketler', 'holding', 'sahibi', 'kimin', 'barkod', 'barkodu',
    'uygulama', 'kanit', 'gerekce', 'neden', 'niye', 'yerine', 'temiz', 'uygun',
    'liste', 'listesi', 'market', 'gida', 'icecek', 'deterjan', 'temizlik',
    'su', 'kahve', 'cikolata', 'cips', 'sampuan', 'kozmetik', 'bebek',
    'nedir', 'ne demek', 'ne is yapar', 'kimdir', 'neresi', 'nerede',
    'ortak', 'ortakligi', 'faaliyeti', 'baglanti', 'baglantisi', 'anlat',
  };

  /// Açıkça konu dışı olan, tüketim/şirket/boykot ile ilgisi bulunmayan talepler
  static final List<RegExp> _blatantlyOffTopic = [
    RegExp(
      r'\b(hava\s+durumu|kaç\s+derece|yağmur\s+yağacak|fıkra\s+anlat|şarkı\s+söyle|kod\s+yaz|python|javascript|flutter|c\+\+|matematik\s+ödev|şiir\s+yaz|beste\s+yap)\b',
      caseSensitive: false,
    ),
  ];

  /// Soru tüketim, şirket veya boykot konularıyla ilgiliyse true döndürür.
  /// Eğer halihazırda devam eden bir sohbet varsa (`history` doluysa) ve soru açıkça
  /// alakasız bir talep (kod yazma, hava durumu vb.) değilse takibi serbest bırakır.
  static bool isRelevant(String question, [List<ChatMessage>? history]) {
    final clean = question.trim();
    if (clean.isEmpty) return false;

    // 1. Açıkça konu dışı talepleri hemen filtrele
    for (final reg in _blatantlyOffTopic) {
      if (reg.hasMatch(clean)) return false;
    }

    // 2. Devam eden bir sohbet varsa (takip soruları, şirket sorguları, detay istekleri)
    if (history != null && history.isNotEmpty) {
      final hasAssistantAnswer = history.any((m) => !m.isUser && !m.isNotice);
      if (hasAssistantAnswer) {
        return true;
      }
    }

    // 3. Yerel veya bilinen bir marka içeriyor mu?
    if (OfflineBoycottDatabase.findBrandKeyInText(clean) != null) return true;

    // 4. Kısa sorgular (ör. kullanıcının doğrudan bir şirket/marka adı yazması: "SodaStream", "Stellantis")
    final words = clean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length <= 2 && words.first.length >= 3) {
      return true;
    }

    // 5. Tanım ve şirket sorguları: "X nedir?", "X kimdir?", "X neresi?", "X ne iş yapar?"
    const inquiryWords = {'nedir', 'kimdir', 'neresi', 'nerede', 'kimin', 'sahibi', 'faaliyeti', 'hakkinda', 'yapar'};
    final tokens = OfflineBoycottDatabase.tokenize(clean);
    final hasInquiry = tokens.any(inquiryWords.contains) ||
        clean.toLowerCase().contains('ne iş yapar') ||
        clean.toLowerCase().contains('hakkında');
    if (hasInquiry && tokens.length >= 2) {
      return true;
    }

    // 6. Anahtar kelime taraması
    const weak = {
      'su', 'neden', 'liste', 'listesi', 'market', 'uygun', 'temiz', 'bebek',
      'anlat',
    };
    final strong = tokens.where((t) => _keywords.contains(t) && !weak.contains(t));
    if (strong.isNotEmpty) return true;
    final weakHits = tokens.where(weak.contains).length;
    return weakHits >= 2;
  }

  static const String refusalText =
      'Ben tüketim ürünleri, markalar, şirket bağlantıları ve boykot gerekçeleri konusunda '
      'yardımcı olmak için tasarlandım. Bir ürünün boykot durumunu, çatı şirketini, '
      'neden boykot edildiğini veya yerli alternatiflerini sorabilirsiniz.';
}
