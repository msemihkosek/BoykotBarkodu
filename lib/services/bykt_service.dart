import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:html/parser.dart' as html_parser;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/boycott_result.dart';

/// https://bykt.org/ veri kaynağı servisi.
///
/// 1300'den fazla markayı, detaylı gerekçeleri, kanıt kaynaklarını ve
/// alternatifleri hem çevrimdışı (asset ve yerel önbellek) hem de çevrimiçi
/// canlı sorgulama ile sunar.
class ByktService {
  static final ByktService _instance = ByktService._internal();
  factory ByktService() => _instance;
  ByktService._internal();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(milliseconds: 4000),
      receiveTimeout: const Duration(milliseconds: 4000),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'application/json, text/html, */*',
      },
    ),
  );

  static const String brandsJsonUrl = 'https://bykt.org/brands.json';
  static const String fallbackStorageUrl =
      'https://firebasestorage.googleapis.com/v0/b/boykot-listesi-e7b96.firebasestorage.app/o/brands.json?alt=media';
  static const String versionJsonUrl = 'https://bykt.org/version.json';
  static const String assetDataPath = 'assets/data/bykt_brands.json';
  static const String cachePrefKey = 'cached_bykt_brands_v1';
  static const String cacheTimestampPrefKey = 'cached_bykt_timestamp_v1';

  bool _isInitialized = false;
  bool _isSyncing = false;

  final List<Map<String, dynamic>> _brands = [];
  final Map<String, Map<String, dynamic>> _byNormalizedName = {};
  final Map<String, Map<String, dynamic>> _byStripped = {};
  final Map<String, Map<String, dynamic>> _bySlug = {};
  final Map<String, List<Map<String, dynamic>>> _byParent = {};
  final Map<String, List<AlternativeProduct>> _cleanBySector = {};

  bool get isInitialized => _isInitialized;
  int get brandCount => _brands.length;

  /// Servisi başlatır; önce disk önbelleğinden, yoksa bundled asset'ten yükler.
  /// Ardından arka planda sunucudan güncelleme kontrolü yapar.
  Future<void> init() async {
    if (_isInitialized && _brands.isNotEmpty) return;

    // 1. SharedPreferences önbelleğini dene
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(cachePrefKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final List decoded = jsonDecode(cachedJson);
        if (decoded.isNotEmpty) {
          _loadList(decoded);
          _isInitialized = true;
          _syncRemoteInBackground();
          return;
        }
      }
    } catch (_) {}

    // 2. Bundled Asset dosyasını dene (İlk açılışta bile 1300+ marka hazır)
    try {
      final assetString = await rootBundle.loadString(assetDataPath);
      final List decoded = jsonDecode(assetString);
      if (decoded.isNotEmpty) {
        _loadList(decoded);
        _isInitialized = true;
        _syncRemoteInBackground();
        return;
      }
    } catch (_) {
      // Test veya CLI ortamında doğrudan dosya sisteminden oku
      try {
        final file = File(assetDataPath);
        if (file.existsSync()) {
          final content = await file.readAsString();
          final List decoded = jsonDecode(content);
          if (decoded.isNotEmpty) {
            _loadList(decoded);
            _isInitialized = true;
            return;
          }
        }
      } catch (_) {}
    }

    // 3. Asset yüklenemediyse doğrudan uzaktan çek
    try {
      await _fetchRemote(saveToCache: true);
      _isInitialized = true;
    } catch (_) {}
  }

  /// Liste verilerini hafızaya alıp hızlı arama indekslerini kurar.
  void _loadList(List rawList) {
    _brands.clear();
    _byNormalizedName.clear();
    _byStripped.clear();
    _bySlug.clear();
    _byParent.clear();
    _cleanBySector.clear();

    for (final item in rawList) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final name = (map['name'] as String? ?? '').trim();
      if (name.isEmpty) continue;

      _brands.add(map);

      final norm = normalize(name);
      final stripped = strip(name);
      final slug = toSlug(name);

      _byNormalizedName[norm] = map;
      _byStripped[stripped] = map;
      _bySlug[slug] = map;

      // Çatı şirket indeksi
      final parent = (map['parentCompany'] as String? ?? '').trim();
      if (parent.isNotEmpty) {
        final normParent = normalize(parent);
        _byParent.putIfAbsent(normParent, () => []).add(map);
      }

      // Sektör bazlı temiz / alternatif ürün havuzu
      final status = (map['status'] as String? ?? '').toLowerCase();
      final sector = (map['sector'] as String? ?? '').trim();
      if (status == 'green' && sector.isNotEmpty) {
        final logo = map['logo'] as String?;
        _cleanBySector.putIfAbsent(sector, () => []).add(
              AlternativeProduct(
                name: name,
                category: sector,
                logoUrl: logo,
                description: 'BYKT.ORG veritabanında yerli/temiz alternatif olarak kayıtlıdır.',
                isLocal: true,
              ),
            );
      }
    }
  }

  /// Arka planda sunucudan güncelleme kontrolü
  void _syncRemoteInBackground() {
    if (_isSyncing) return;
    _isSyncing = true;
    Future.microtask(() async {
      try {
        await _fetchRemote(saveToCache: true);
      } catch (_) {
      } finally {
        _isSyncing = false;
      }
    });
  }

  /// Uzak sunucudan (bykt.org/brands.json veya fallback) veriyi çeker.
  Future<void> _fetchRemote({bool saveToCache = true}) async {
    Response? response;
    try {
      response = await _dio.get(brandsJsonUrl);
    } catch (_) {
      // Birincil adres başarısızsa Firebase Storage fallback'ini dene
      try {
        response = await _dio.get(fallbackStorageUrl);
      } catch (_) {}
    }

    if (response != null && response.statusCode == 200 && response.data != null) {
      final List rawList = response.data is List
          ? response.data as List
          : jsonDecode(response.data.toString()) as List;

      if (rawList.isNotEmpty) {
        _loadList(rawList);

        if (saveToCache) {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(cachePrefKey, jsonEncode(rawList));
            await prefs.setInt(cacheTimestampPrefKey, DateTime.now().millisecondsSinceEpoch);
          } catch (_) {}
        }
      }
    }
  }

  /// Marka sorgusu yapar:
  /// 1) Hafızadaki 1300+ markalık indeks taranır (Tam isim, slug, strip, token, çatı şirket)
  /// 2) Hafızada bulunamazsa canlı olarak `https://bykt.org/marka/:slug` sayfasına sorgu atılır.
  Future<Map<String, dynamic>?> queryBrand(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return null;

    if (!_isInitialized) {
      await init();
    }

    // 1. ADIM: Hafıza İndeksinde Arama
    final memoryMatch = _findInMemory(cleanQuery);
    if (memoryMatch != null) {
      return _formatResult(memoryMatch, cleanQuery);
    }

    // 2. ADIM: Canlı Web Sorgulaması (bykt.org/marka/:slug)
    try {
      final liveMatch = await _queryLiveBrandPage(cleanQuery);
      if (liveMatch != null) {
        return liveMatch;
      }
    } catch (_) {}

    return null;
  }

  /// Hafızadaki indeksten en iyi eşleşmeyi bulur
  Map<String, dynamic>? _findInMemory(String query) {
    final normQ = normalize(query);
    final stripQ = strip(query);
    final slugQ = toSlug(query);

    // 1. Doğrudan tam eşleşme
    if (_byNormalizedName.containsKey(normQ)) return _byNormalizedName[normQ];
    if (_byStripped.containsKey(stripQ)) return _byStripped[stripQ];
    if (_bySlug.containsKey(slugQ)) return _bySlug[slugQ];

    // 2. Query bilinen bir markayı tam kelime olarak içeriyor mu? (Örn: "Coca-Cola Zero 330ml")
    final qPadded = ' $normQ ';
    Map<String, dynamic>? bestSub;
    int bestLen = 0;
    for (final entry in _byNormalizedName.entries) {
      final bPadded = ' ${entry.key} ';
      if (qPadded.contains(bPadded) && entry.key.length > bestLen) {
        bestSub = entry.value;
        bestLen = entry.key.length;
      }
    }
    if (bestSub != null) return bestSub;

    // 3. Marka ismi query'yi içeriyor mu? (Örn: "L'Oréal" -> "Loreal Paris", "P&G" -> "Procter & Gamble (P&G)")
    if (stripQ.length >= 3) {
      Map<String, dynamic>? bestContain;
      int shortestLen = 999999;
      for (final entry in _byStripped.entries) {
        if (entry.key.contains(stripQ)) {
          if (entry.key.startsWith(stripQ)) {
            return entry.value;
          }
          if (entry.key.length < shortestLen) {
            bestContain = entry.value;
            shortestLen = entry.key.length;
          }
        }
      }
      if (bestContain != null) return bestContain;
    }

    // 4. Çatı şirket araması (Örn: "The Coca-Cola Company" veya "Stellantis")
    if (_byParent.containsKey(normQ)) {
      final list = _byParent[normQ]!;
      if (list.isNotEmpty) return list.first;
    }

    return null;
  }

  /// bykt.org üzerindeki tekil marka sayfasını canlı sorgular
  Future<Map<String, dynamic>?> _queryLiveBrandPage(String brandName) async {
    final slug = toSlug(brandName);
    if (slug.isEmpty) return null;

    final url = 'https://bykt.org/marka/$slug';
    final response = await _dio.get(url);

    if (response.statusCode == 200 && response.data != null) {
      final html = response.data.toString();
      final document = html_parser.parse(html);

      // Sayfa başlığı ve açıklaması
      final title = document.querySelector('title')?.text ?? '';
      if (!title.toLowerCase().contains('bykt.org')) {
        return null;
      }

      // JSON-LD bloklarından marka bilgisi çek
      final scriptTags = document.querySelectorAll('script[type="application/ld+json"]');
      String? reason;
      String? statusStr;
      String? logoUrl;
      String parsedBrandName = brandName;

      for (final script in scriptTags) {
        try {
          final json = jsonDecode(script.text);
          if (json is Map) {
            if (json['@type'] == 'Article') {
              final desc = json['description'] as String? ?? '';
              if (desc.contains('boykot durumu:')) {
                final match = RegExp(r'boykot durumu:\s*([^\.]+)\.').firstMatch(desc);
                if (match != null) {
                  statusStr = match.group(1)?.trim();
                }
              }
              if (desc.length > 30) {
                reason = desc;
              }
            } else if (json['@type'] == 'WebPage' && json['mainEntity'] is Map) {
              final brandEntity = json['mainEntity'] as Map;
              parsedBrandName = brandEntity['name'] as String? ?? parsedBrandName;
              logoUrl = brandEntity['image'] as String? ?? logoUrl;
              final desc = brandEntity['description'] as String?;
              if (desc != null && desc.isNotEmpty) {
                reason = desc;
              }
            }
          }
        } catch (_) {}
      }

      BoycottStatus status = BoycottStatus.boycott;
      String statusText = 'Kesin Boykot';

      if (statusStr != null) {
        final s = statusStr.toLowerCase();
        if (s.contains('alınabilir') || s.contains('uygun') || s.contains('temiz')) {
          status = BoycottStatus.clean;
          statusText = 'Boykot Değil (Alınabilir)';
        } else if (s.contains('insaf') || s.contains('şüpheli') || s.contains('supheli')) {
          status = BoycottStatus.suspected;
          statusText = 'İnsafa Bağlı (Şüpheli)';
        }
      }

      return {
        'brandName': parsedBrandName,
        'status': status,
        'statusText': statusText,
        'reason': reason ?? 'BYKT.ORG platformunda kayıtlıdır.',
        'proofUrl': url,
        'logoUrl': logoUrl,
        'category': null,
        'source': 'BYKT.ORG',
        'alternatives': <AlternativeProduct>[],
      };
    }
    return null;
  }

  /// Hafıza veya API verisini standart boykot sonucuna dönüştürür
  Map<String, dynamic> _formatResult(Map<String, dynamic> match, String originalQuery) {
    final rawStatus = (match['status'] as String? ?? '').toLowerCase();
    BoycottStatus status;
    String statusText;

    if (rawStatus == 'red' || rawStatus.contains('boykot')) {
      status = BoycottStatus.boycott;
      statusText = 'Boykot (Kesin Boykot)';
    } else if (rawStatus == 'orange' ||
        rawStatus.contains('insaf') ||
        rawStatus.contains('supheli') ||
        rawStatus.contains('şüpheli')) {
      status = BoycottStatus.suspected;
      statusText = 'İnsafa Bağlı (Şüpheli)';
    } else if (rawStatus == 'green' ||
        rawStatus.contains('al') ||
        rawStatus.contains('temiz') ||
        rawStatus.contains('uygun')) {
      status = BoycottStatus.clean;
      statusText = 'Boykot Değil (Alınabilir)';
    } else {
      status = BoycottStatus.unknown;
      statusText = 'İncelemede';
    }

    final brandName = (match['name'] as String? ?? originalQuery).trim();
    final sector = (match['sector'] as String?)?.trim();
    final reason = (match['reason'] as String?)?.trim();
    final logoUrl = (match['logo'] as String?)?.trim();
    final origin = (match['origin'] as String?)?.trim();
    final parentCompany = (match['parentCompany'] as String?)?.trim();

    // Alternatifler listesi
    final List<AlternativeProduct> alternatives = [];
    final rawAlts = (match['alternatives'] as List?) ?? [];
    for (final a in rawAlts) {
      if (a is Map) {
        final aName = (a['name'] as String? ?? '').trim();
        if (aName.isNotEmpty) {
          alternatives.add(
            AlternativeProduct(
              name: aName,
              category: sector,
              description: 'BYKT.ORG alternatif önerisi',
              isLocal: true,
            ),
          );
        }
      }
    }

    // Özel alternatif belirtilmemişse ve boykotluysa aynı sektörden yeşil alternatifleri öner
    if (alternatives.isEmpty && sector != null && _cleanBySector.containsKey(sector)) {
      final sectorAlts = _cleanBySector[sector]!;
      for (final alt in sectorAlts.take(4)) {
        if (alt.name.toLowerCase() != brandName.toLowerCase()) {
          alternatives.add(alt);
        }
      }
    }

    // Kanıt URL'si
    String? proofUrl;
    final reasonSources = (match['reasonSources'] as List?) ?? [];
    if (reasonSources.isNotEmpty && reasonSources.first is Map) {
      proofUrl = reasonSources.first['url'] as String?;
    }
    if (proofUrl == null || proofUrl.isEmpty) {
      proofUrl = 'https://bykt.org/marka/${toSlug(brandName)}';
    }

    return {
      'brandName': brandName,
      'status': status,
      'statusText': statusText,
      'reason': reason ??
          (status == BoycottStatus.boycott
              ? 'BYKT.ORG veritabanında boykotlu olarak kayıtlıdır.'
              : 'BYKT.ORG veritabanında güvenle tercih edilebilir olarak kayıtlıdır.'),
      'proofUrl': proofUrl,
      'logoUrl': logoUrl,
      'category': sector,
      'origin': origin,
      'parentCompany': parentCompany,
      'source': 'BYKT.ORG',
      'alternatives': alternatives,
    };
  }

  /// Tüm kayıtlı markaların listesi
  List<Map<String, dynamic>> get allBrands => List.unmodifiable(_brands);

  /// Marka arama önerileri listesi (Autocomplete & Search için)
  List<Map<String, dynamic>> searchSuggestions(String query, {int limit = 10}) {
    final clean = query.trim();
    if (clean.isEmpty) {
      return _brands.take(limit).toList();
    }

    final normQ = normalize(clean);
    final stripQ = strip(clean);

    final results = <Map<String, dynamic>>[];
    for (final b in _brands) {
      final name = b['name'] as String? ?? '';
      final norm = normalize(name);
      final stripped = strip(name);

      if (norm.startsWith(normQ) || stripped.startsWith(stripQ) || norm.contains(normQ)) {
        results.add(b);
        if (results.length >= limit) break;
      }
    }
    return results;
  }

  // --- Yardımcı Metin İşleme Fonksiyonları ---

  /// Türkçe karakterleri sadeleştirip alfabetik ve nümerik hale getirir
  static String normalize(String text) {
    return text
        .replaceAll('İ', 'i')
        .replaceAll('I', 'i')
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('&', ' ')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  /// Tüm boşluk ve noktalama işaretlerini silerek arama yapar (örn: "L'Oréal" -> "loreal")
  static String strip(String text) {
    return normalize(text).replaceAll(' ', '');
  }

  /// bykt.org URL slug formatına dönüştürür (örn: "Coca-Cola" -> "coca-cola")
  static String toSlug(String text) {
    return normalize(text)
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .join('-');
  }
}
