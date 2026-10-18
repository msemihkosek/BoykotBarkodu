import '../offline_data.dart';

/// Sohbetin yalnızca boykotla ilgili sorulara cevap vermesini sağlayan konu kapısı.
class TopicGate {
  static const Set<String> _keywords = {
    'boykot', 'boykotlu', 'boykotta', 'boykotmu', 'alternatif', 'alternatifi',
    'muadil', 'yerli', 'milli', 'israil', 'filistin', 'gazze', 'siyonist',
    'marka', 'markasi', 'markalar', 'urun', 'urunu', 'urunler', 'sirket',
    'sirketi', 'sahibi', 'kimin', 'barkod', 'barkodu', 'uygulama', 'kanit',
    'gerekce', 'neden', 'yerine', 'temiz', 'uygun', 'liste', 'listesi',
    'market', 'gida', 'icecek', 'deterjan', 'temizlik', 'su', 'kahve',
    'cikolata', 'cips', 'sampuan', 'kozmetik', 'bebek',
  };

  /// Soru bilinen bir marka içeriyorsa veya boykot ile ilgili bir anahtar kelime geçiyorsa true.
  static bool isRelevant(String question) {
    if (OfflineBoycottDatabase.findBrandKeyInText(question) != null) return true;
    final tokens = OfflineBoycottDatabase.tokenize(question);
    // "su" gibi çok genel kelimeler tek başına yeterli sayılmaz
    const weak = {'su', 'neden', 'liste', 'listesi', 'market', 'uygun', 'temiz', 'bebek'};
    final strong = tokens.where((t) => _keywords.contains(t) && !weak.contains(t));
    if (strong.isNotEmpty) return true;
    final weakHits = tokens.where(weak.contains).length;
    return weakHits >= 2;
  }

  static const String refusalText =
      'Ben sadece boykotla ilgili sorulara cevap verebilirim: bir markanın boykot durumu, '
      'gerekçesi veya yerli alternatifleri gibi. Örneğin "Ariel neden boykotta?" ya da '
      '"Nescafe yerine ne alabilirim?" diye sorabilirsiniz.';
}
