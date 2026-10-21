import 'dart:convert';
import 'package:dio/dio.dart';
import '../../models/boycott_result.dart';
import '../bykt_service.dart';
import '../offline_data.dart';
import 'chat_models.dart';
import 'chat_provider.dart';

/// Şirketleri, çatı kuruluşları, ortaklıkları ve kavramları (örneğin SodaStream, Atarot,
/// Stellantis, Im Tirtzu) açıklayan, sıfır API anahtarı gerektiren ve Vikipedi + Boykot Arşivi
/// üzerinden bilgi üreten akıllı bilgi motoru.
class CompanyKnowledgeService implements ChatProvider {
  final Dio _dio;
  final ByktService _byktService;

  CompanyKnowledgeService({
    Dio? dio,
    ByktService? byktService,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(milliseconds: 4000),
                receiveTimeout: const Duration(milliseconds: 4000),
                headers: {
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 BoykotBarkodu/1.0',
                  'Accept': 'application/json',
                },
              ),
            ),
        _byktService = byktService ?? ByktService();

  @override
  String get name => 'Şirket ve Kavram Bilgi Motoru';

  @override
  Future<ChatMessage?> reply(String question, List<ChatMessage> history) async {
    final cleanQ = question.trim();
    if (cleanQ.isEmpty) return null;

    // 1. ADIM: Hedef Şirket veya Kavramı Çıkar
    final targetEntity = _extractTargetEntity(cleanQ, history);
    if (targetEntity == null || targetEntity.length < 2) return null;

    // 2. ADIM: Boykot Veritabanı ve Gerekçelerindeki Bahisleri Tara
    final boycottMentions = await _searchBoycottMentions(targetEntity);
    final directBrandResult = await _byktService.queryBrand(targetEntity);

    // 3. ADIM: Vikipedi REST API'sinden Ansiklopedik Bilgi Çek (Ücretsiz & Anahtarsız)
    final wikiInfo = await _queryWikipedia(targetEntity);

    // Ne Vikipedi'de ne de boykot gerekçelerinde bir şey bulunamadıysa sağlayıcı cevap veremez
    if (wikiInfo == null && boycottMentions.isEmpty && directBrandResult == null) {
      return null;
    }

    // 4. ADIM: Bilgileri Birleştirerek Doğal ve Akıcı Bir Yanıt Oluştur
    final buffer = StringBuffer();
    final sources = <ChatSource>[];

    // Şirket / Kavram Tanımı (Vikipedi veya doğrudan marka bilgisi)
    if (wikiInfo != null) {
      final wikiTitle = wikiInfo['title'] as String? ?? targetEntity;
      final wikiExtract = (wikiInfo['extract'] as String? ?? '').trim();
      buffer.write('🏢 **$wikiTitle Hakkında:**\n$wikiExtract');
      final wikiUrl = wikiInfo['url'] as String?;
      if (wikiUrl != null && wikiUrl.isNotEmpty) {
        sources.add(ChatSource(label: 'Vikipedi: $wikiTitle', url: wikiUrl));
      }
    } else if (directBrandResult != null) {
      final bName = directBrandResult['brandName'] ?? targetEntity;
      final statusText = directBrandResult['statusText'] ?? '';
      final sector = directBrandResult['category'];
      buffer.write('🏢 **$bName** ($statusText)${sector != null ? ' - Sektör: $sector' : ''}:\n');
      final directReason = directBrandResult['reason'] as String?;
      if (directReason != null && directReason.isNotEmpty) {
        buffer.write(directReason);
      }
    }

    // Boykot Dosyalarındaki Özel Bağlantı ve Rolü
    if (boycottMentions.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write('\n\n');
      buffer.write('📌 **Boykot Dosyalarındaki Bağlantısı ve Rolü:**\n');

      final takenMentions = boycottMentions.take(2);
      for (final mention in takenMentions) {
        final brand = mention['brand']!;
        final paragraph = mention['paragraph']!;
        buffer.write('• **$brand Dosyası:** $paragraph\n');
      }

      sources.add(const ChatSource(label: 'BYKT.ORG Boykot Arşivi', url: 'https://bykt.org'));
    }

    // Eğer doğrudan boykot durumu varsa ve henüz gerekçe yazılmadıysa alternatifleri ekle
    if (directBrandResult != null) {
      final status = directBrandResult['status'] as BoycottStatus?;
      final alts = (directBrandResult['alternatives'] as List<AlternativeProduct>?) ?? [];
      if (status == BoycottStatus.boycott && alts.isNotEmpty) {
        buffer.write('\n💡 **Yerli ve Temiz Alternatifler:**\n');
        buffer.write('• ${alts.take(4).map((a) => a.name).join('\n• ')}');
      }

      final proofUrl = directBrandResult['proofUrl'] as String?;
      if (proofUrl != null && proofUrl.isNotEmpty) {
        sources.add(ChatSource(label: 'Gerekçe & Kanıt', url: proofUrl));
      }
    }

    return ChatMessage(
      role: ChatRole.assistant,
      text: buffer.toString().trim(),
      sources: sources,
    );
  }

  /// Kullanıcı sorusundan veya önceki konuşma bağlamından hedef şirket/kavram adını çıkarır
  String? _extractTargetEntity(String question, List<ChatMessage> history) {
    final q = question.trim();

    // 1. Belirgin soru kalıpları: "X nedir", "X kimdir", "X ne iş yapar", "X neresi", "X hakkında bilgi", "X şirketi"
    final pattern = RegExp(
      r'^(?:peki\s+)?([A-Za-z0-9ÇĞİÖŞÜçğiöşü\s\.\-&'
      "'"
      r'"]+?)(?:\s+(?:nedir|kimdir|ne\s+demek|ne\s+iş\s+yapar|neresi|nerede|hakkında\s+bilgi|hakkında|şirketi|firması|kurumu|organizasyonu|kimin))\b',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(q);
    if (match != null) {
      var candidate = match.group(1)?.trim() ?? '';
      candidate = candidate
          .replaceAll(
            RegExp(r'^(bu|şu|o)\s+(şirket|kurum|organizasyon|firma|yer)?\s*', caseSensitive: false),
            '',
          )
          .trim();
      if (candidate.isNotEmpty && candidate.length >= 2) {
        return candidate;
      }
    }

    // 2. Zamir kullanımı: "bu şirket ne iş yapar?", "bu nedir?", "sahibi kim?", "nerede kuruldu?"
    final isPronounRef = RegExp(
      r'^(bu|şu|o|peki\s+bu|peki\s+şu)\s*(şirket|firma|kurum|yer|marka)?\s*(ne|nedir|ne\s+iş\s+yapar|kimin|sahibi\s+kim|nerede|kimdir)',
      caseSensitive: false,
    ).hasMatch(q);

    if (isPronounRef && history.isNotEmpty) {
      for (final m in history.reversed) {
        if (!m.isUser && !m.isNotice && m.text.isNotEmpty) {
          final extracted = _extractEntityFromAssistantText(m.text);
          if (extracted != null && extracted.isNotEmpty) {
            return extracted;
          }
        }
      }
    }

    // 3. Kısa tekil şirket/kavram girişi (Örn: "SodaStream", "Stellantis", "Atarot")
    final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length <= 3 && !q.contains('?') && words.first.length >= 3) {
      return q.replaceAll(RegExp(r'[^\w\s\-]'), '').trim();
    }

    return null;
  }

  /// Asistanın son mesajındaki belirgin şirket ve kurum isimlerini tespit eder
  String? _extractEntityFromAssistantText(String text) {
    // Tırnak içindeki özel isimler: "SodaStream", "Im Tirtzu"
    final quoteMatch = RegExp(r'"([^"]{3,30})"').firstMatch(text);
    if (quoteMatch != null) return quoteMatch.group(1);

    // "X şirketi", "X firması", "X grubu", "X örgütü", "X tesisleri" kalıpları
    final companyMatch = RegExp(
      r'([A-ZÇĞİÖŞÜ][A-Za-z0-9ÇĞİÖŞÜçğiöşü\-]+(?:\s+[A-ZÇĞİÖŞÜ][A-Za-z0-9ÇĞİÖŞÜçğiöşü\-]+)?)\s+(?:şirketi|şirketini|firması|firmasını|grubu|grubunu|örgütü|tesisi|ortaklığı)',
    ).firstMatch(text);
    if (companyMatch != null) return companyMatch.group(1);

    return null;
  }

  /// Boykot veritabanındaki gerekçe metinlerinde bu şirketin veya terimin geçip geçmediğini arar
  Future<List<Map<String, String>>> _searchBoycottMentions(String entity) async {
    final lower = entity.toLowerCase().trim();
    if (lower.length < 3) return [];

    final results = <Map<String, String>>[];

    // 1. BYKT.ORG Arşivini tara
    if (!_byktService.isInitialized) {
      await _byktService.init();
    }

    // bykt.org marka listesi içindeki gerekçeler
    final allBrands = _byktService.searchSuggestions('', limit: 2000);
    for (final b in allBrands) {
      final reason = b['reason'] as String? ?? '';
      if (reason.toLowerCase().contains(lower)) {
        final paragraphs = reason.split('\n\n');
        for (final p in paragraphs) {
          if (p.toLowerCase().contains(lower)) {
            final trimmed = p.trim();
            if (trimmed.length > 30) {
              results.add({
                'brand': b['name'] as String? ?? '',
                'paragraph': trimmed,
              });
              break;
            }
          }
        }
      }
      if (results.length >= 3) break;
    }

    // 2. OfflineBoycottDatabase gerekçelerini tara
    if (results.length < 3) {
      for (final entry in OfflineBoycottDatabase.brandDatabase.entries) {
        final reason = entry.value['reason'] as String? ?? '';
        if (reason.toLowerCase().contains(lower)) {
          final trimmed = reason.trim();
          results.add({
            'brand': entry.key.toUpperCase(),
            'paragraph': trimmed,
          });
          if (results.length >= 3) break;
        }
      }
    }

    return results;
  }

  /// Vikipedi REST API'sinden özet ansiklopedik bilgi çeker
  Future<Map<String, dynamic>?> _queryWikipedia(String term) async {
    final clean = term.trim();
    if (clean.isEmpty) return null;

    // 1. Türkçe Vikipedi
    try {
      final res = await _dio.get(
        'https://tr.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(clean)}',
      );
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data is Map ? res.data as Map<String, dynamic> : jsonDecode(res.data.toString()) as Map<String, dynamic>;
        final type = data['type'] as String? ?? '';
        final extract = data['extract'] as String? ?? '';
        if (type != 'disambiguation' && extract.isNotEmpty && !extract.contains('şu anlamlara gelebilir')) {
          return {
            'title': data['title'] ?? clean,
            'extract': extract,
            'url': data['content_urls']?['desktop']?['page'] ?? 'https://tr.wikipedia.org/wiki/${Uri.encodeComponent(clean)}',
          };
        }
      }
    } catch (_) {}

    // 2. Türkçe Vikipedi - Şirket Belirteci ile (Örn: "Puma (şirket)")
    try {
      final res = await _dio.get(
        'https://tr.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent('$clean (şirket)')}',
      );
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data is Map ? res.data as Map<String, dynamic> : jsonDecode(res.data.toString()) as Map<String, dynamic>;
        final extract = data['extract'] as String? ?? '';
        if (extract.isNotEmpty) {
          return {
            'title': data['title'] ?? clean,
            'extract': extract,
            'url': data['content_urls']?['desktop']?['page'] ?? 'https://tr.wikipedia.org/wiki/${Uri.encodeComponent('$clean (şirket)')}',
          };
        }
      }
    } catch (_) {}

    // 3. İngilizce Vikipedi (Global veya Türkçe sayfası olmayan terimler için)
    try {
      final res = await _dio.get(
        'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(clean)}',
      );
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data is Map ? res.data as Map<String, dynamic> : jsonDecode(res.data.toString()) as Map<String, dynamic>;
        final extract = data['extract'] as String? ?? '';
        if (extract.isNotEmpty) {
          return {
            'title': data['title'] ?? clean,
            'extract': extract,
            'url': data['content_urls']?['desktop']?['page'] ?? 'https://en.wikipedia.org/wiki/${Uri.encodeComponent(clean)}',
          };
        }
      }
    } catch (_) {}

    return null;
  }
}
