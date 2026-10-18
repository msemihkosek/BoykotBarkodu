import '../../models/boycott_result.dart';
import '../boycott_service.dart';
import '../offline_data.dart';
import 'chat_models.dart';
import 'chat_provider.dart';

/// Cevapları yalnızca doğrulanmış verilerden (yerel marka veritabanı, Boykot Dedektifi,
/// Boykot.co) üretir. Model kullanmaz; bu yüzden uydurma bilgi vermez ve çevrimdışı da çalışır.
class GroundedChatProvider implements ChatProvider {
  final BoycottService _boycottService;

  GroundedChatProvider({BoycottService? boycottService})
      : _boycottService = boycottService ?? BoycottService();

  @override
  String get name => 'Doğrulanmış Veri';

  static const Set<String> _altWords = {
    'alternatif', 'alternatifi', 'alternatifler', 'alternatifleri', 'yerine',
    'muadil', 'muadili', 'oner', 'onerir', 'alabilirim', 'almali', 'almaliyim',
  };
  static const Set<String> _whyWords = {
    'neden', 'sebep', 'sebebi', 'gerekce', 'gerekcesi', 'kanit', 'niye', 'nicin',
  };
  static const Set<String> _ownerWords = {'kimin', 'sahibi', 'sirket', 'sirketi', 'ortak'};

  /// Marka adı çıkarılırken atılacak soru kalıpları
  static const Set<String> _stopWords = {
    'boykot', 'boykotlu', 'boykotta', 'mu', 'mi', 'midir', 'mudur', 'neden',
    'nedir', 'bu', 'su', 'bir', 'urun', 'urunu', 'marka', 'markasi', 'listesinde',
    'liste', 'var', 'yok', 'alternatif', 'alternatifi', 'alternatifleri', 'ne',
    'nasil', 'hangi', 'kimin', 'sahibi', 'hakkinda', 'bilgi', 'ver', 'soyle',
    'yerine', 'alabilirim', 'sirket', 'sirketi', 'yerli', 'milli', 'israil',
    'destekliyor', 've', 'ile', 'icin', 'de', 'da', 'ki', 'olarak', 'gerekce',
    'sebep', 'kanit', 'peki', 'o', 'onun', 'bunun', 'bunlar', 'yani', 'misin',
  };

  @override
  Future<ChatMessage?> reply(String question, List<ChatMessage> history) async {
    final tokens = OfflineBoycottDatabase.tokenize(question).toSet();

    final faq = _faq(tokens);
    if (faq != null) return faq;

    // 1) Yerel veritabanında marka var mı?
    String? key = OfflineBoycottDatabase.findBrandKeyInText(question);

    final candidate = tokens
        .where((t) => !_stopWords.contains(t))
        .toList()
        .join(' ')
        .trim();

    // Soru hiçbir marka adı içermiyorsa ("peki alternatifi?") son konuşulan markayı kullan
    if (key == null && candidate.isEmpty) {
      key = _lastBrandFromHistory(history);
    }

    if (key != null && OfflineBoycottDatabase.brandDatabase.containsKey(key)) {
      final data = OfflineBoycottDatabase.brandDatabase[key]!;
      return _fromLocal(key, data, tokens);
    }

    // 2) Yerelde yoksa Boykot Dedektifi / Boykot.co'da ara
    if (candidate.isEmpty || candidate.length < 3) return null;

    final result = await _boycottService.checkBoycott(
      barcode: '',
      productName: candidate,
      brandName: candidate,
    );
    if (result.isUnknown) return null;
    return _fromResult(result, tokens);
  }

  ChatMessage? _faq(Set<String> tokens) {
    if (tokens.contains('729')) {
      return ChatMessage(
        role: ChatRole.assistant,
        text: 'Barkodu 729 ile başlayan ürünler İsrail GS1 kaydıyla tescillidir; uygulama bunları '
            'doğrudan "İsrail menşeli" olarak işaretler. Ancak 729 olmaması boykot olmadığı anlamına '
            'gelmez: çok uluslu şirketlerin ürünleri başka ülke kodlarıyla (ör. Türkiye için 869) '
            'satılabilir. Bu yüzden marka ve çatı şirket de ayrıca kontrol edilir.',
      );
    }
    if (tokens.contains('boykot') &&
        (tokens.contains('nedir') || tokens.contains('ne')) &&
        !tokens.contains('mu')) {
      return ChatMessage(
        role: ChatRole.assistant,
        text: 'Bu uygulamada boykot, İsrail ekonomisine veya işgal politikalarına doğrudan destek '
            'verdiği belgelenen şirket ve markaların ürünlerini satın almamak anlamına gelir. '
            'Listeler Boykot Dedektifi ve Boykot.co gibi kaynaklardan derlenir; her kayıtta mümkün '
            'olduğunca gerekçe ve kanıt bağlantısı gösterilir.',
        sources: const [
          ChatSource(label: 'Boykot Dedektifi', url: 'https://boykotdedektifi.com'),
          ChatSource(label: 'Boykot.co', url: 'https://www.boykot.co'),
        ],
      );
    }
    if (tokens.contains('uygulama') && (tokens.contains('nasil') || tokens.contains('calisir'))) {
      return ChatMessage(
        role: ChatRole.assistant,
        text: 'Ürünün barkodunu okutursunuz; uygulama barkoddan ürün ve markayı bulur, ardından '
            'markanın boykot durumunu, gerekçesini ve yerli alternatiflerini gösterir. Ürün yanlış '
            'bulunduysa sonuç kartındaki düzeltme butonuyla doğru markayı yazabilirsiniz; bu düzeltme '
            'o barkod için telefonunuza kaydedilir.',
      );
    }
    return null;
  }

  String? _lastBrandFromHistory(List<ChatMessage> history) {
    for (final m in history.reversed) {
      final key = OfflineBoycottDatabase.findBrandKeyInText(m.text);
      if (key != null) return key;
    }
    return null;
  }

  ChatMessage _fromLocal(String key, Map<String, dynamic> data, Set<String> tokens) {
    final status = data['status'] as BoycottStatus;
    final reason = data['reason'] as String? ?? '';
    final proof = data['proofUrl'] as String?;
    final alts = ((data['alternatives'] as List<dynamic>?) ?? [])
        .map((a) => a['name'] as String)
        .toList();
    final title = _title(key);

    return _compose(
      title: title,
      status: status,
      statusText: data['statusText'] as String? ?? '',
      reason: reason,
      proofUrl: proof,
      alternatives: alts,
      tokens: tokens,
    );
  }

  ChatMessage _fromResult(ProductScanResult r, Set<String> tokens) {
    return _compose(
      title: r.brandName,
      status: r.status,
      statusText: r.statusText,
      reason: r.reason ?? '',
      proofUrl: r.proofUrl,
      alternatives: r.alternatives.map((a) => a.name).toList(),
      tokens: tokens,
    );
  }

  ChatMessage _compose({
    required String title,
    required BoycottStatus status,
    required String statusText,
    required String reason,
    required String? proofUrl,
    required List<String> alternatives,
    required Set<String> tokens,
  }) {
    final wantsAlt = tokens.any(_altWords.contains);
    final wantsWhy = tokens.any(_whyWords.contains);
    final wantsOwner = tokens.any(_ownerWords.contains);

    final buffer = StringBuffer();
    final isBoycott = status == BoycottStatus.boycott;

    if (wantsAlt && !wantsWhy) {
      if (isBoycott && alternatives.isNotEmpty) {
        buffer.write('$title [$statusText] yerine tercih edebileceğiniz yerli alternatifler:\n• ${alternatives.join('\n• ')}');
      } else if (!isBoycott) {
        buffer.write('$title boykot listesinde görünmüyor ($statusText), bu yüzden alternatif aramanız gerekmez.');
      } else {
        buffer.write('$title için kayıtlı bir alternatif bulunamadı.');
      }
    } else if (wantsWhy || wantsOwner) {
      buffer.write('$title ($statusText): ');
      buffer.write(reason.isNotEmpty ? reason : 'Kayıtlı bir gerekçe bulunamadı.');
      if (isBoycott && alternatives.isNotEmpty) {
        buffer.write('\n\nAlternatifler:\n• ${alternatives.join('\n• ')}');
      }
    } else {
      buffer.write('$title: $statusText.');
      if (reason.isNotEmpty) buffer.write(' $reason');
      if (isBoycott && alternatives.isNotEmpty) {
        buffer.write('\n\nAlternatifler:\n• ${alternatives.join('\n• ')}');
      }
    }

    return ChatMessage(
      role: ChatRole.assistant,
      text: buffer.toString(),
      sources: [
        if (proofUrl != null && proofUrl.isNotEmpty)
          ChatSource(label: 'Kaynak / kanıt', url: proofUrl),
      ],
    );
  }

  String _title(String key) {
    if (key.isEmpty) return key;
    return key
        .split(RegExp(r'[\s-]+'))
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
