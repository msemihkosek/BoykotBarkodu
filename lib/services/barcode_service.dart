import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:shared_preferences/shared_preferences.dart';
import 'offline_data.dart';

class BarcodeLookupResult {
  final String barcode;
  final String productName;
  final String brandName;
  final String? category;
  final String? imageUrl;
  final String originCountry;
  final String source;
  final bool isFromCache;

  /// Doğrulanmamış (web araması vb.) tahmini sonuç ise true
  final bool isGuess;

  const BarcodeLookupResult({
    required this.barcode,
    required this.productName,
    required this.brandName,
    this.category,
    this.imageUrl,
    this.originCountry = 'Bilinmiyor',
    this.source = 'Açık Veritabanı',
    this.isFromCache = false,
    this.isGuess = false,
  });
}

class BarcodeService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(milliseconds: 3500),
      receiveTimeout: const Duration(milliseconds: 3500),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,application/json,*/*;q=0.8',
        'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
      },
    ),
  );

  static const String _userBarcodesKey = 'user_custom_barcodes';

  /// Kullanıcının kendi eklediği veya eşleştirdiği barkodları yerel hafızaya kaydeder
  Future<void> saveUserBarcodeMapping(String barcode, String brandName, String productName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_userBarcodesKey);
      Map<String, dynamic> map = raw != null ? jsonDecode(raw) : {};
      map[barcode.trim()] = {
        'brand': brandName.trim(),
        'name': productName.trim().isNotEmpty ? productName.trim() : brandName.trim(),
      };
      await prefs.setString(_userBarcodesKey, jsonEncode(map));
    } catch (_) {}
  }

  /// Çok katmanlı ücretsiz arama motoru ile barkodu çözer
  Future<BarcodeLookupResult> lookupBarcode(String barcode) async {
    final cleanBarcode = barcode.trim();
    final country = OfflineBoycottDatabase.getCountryFromBarcode(cleanBarcode);

    // 1. KATMAN: Kullanıcının düzelttiği/eşleştirdiği barkodlar (her zaman en yüksek öncelik)
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_userBarcodesKey);
      if (raw != null) {
        final Map<String, dynamic> userMap = jsonDecode(raw);
        if (userMap.containsKey(cleanBarcode)) {
          final data = userMap[cleanBarcode];
          return BarcodeLookupResult(
            barcode: cleanBarcode,
            productName: data['name'] ?? 'Kullanıcı Kayıtlı Ürün',
            brandName: data['brand'] ?? '',
            originCountry: country,
            source: 'Kullanıcı Tanımlı',
            isFromCache: true,
          );
        }
      }
    } catch (_) {}

    // 2. KATMAN: Dahili doğrulanmış barkodlar
    if (OfflineBoycottDatabase.knownBarcodes.containsKey(cleanBarcode)) {
      final data = OfflineBoycottDatabase.knownBarcodes[cleanBarcode]!;
      return BarcodeLookupResult(
        barcode: cleanBarcode,
        productName: data['name'] ?? 'Ürün',
        brandName: data['brand'] ?? '',
        category: data['category'],
        originCountry: country,
        source: 'Dahili Hızlı Bellek',
        isFromCache: true,
      );
    }

    // 3. KATMAN: Open Food Facts API (Gıda Ürünleri)
    try {
      final offResult = await _queryOpenFacts('https://world.openfoodfacts.org/api/v2/product/$cleanBarcode.json', cleanBarcode, country);
      if (offResult != null) return offResult;
    } catch (_) {}

    // 4. KATMAN: Open Beauty Facts API (Kişisel Bakım, Şampuan, Sabun, Diş Macunu)
    try {
      final obfResult = await _queryOpenFacts('https://world.openbeautyfacts.org/api/v2/product/$cleanBarcode.json', cleanBarcode, country);
      if (obfResult != null) return obfResult;
    } catch (_) {}

    // 5. KATMAN: Open Products Facts API (Deterjan ve Temizlik Ürünleri)
    try {
      final opfResult = await _queryOpenFacts('https://world.openproductsfacts.org/api/v2/product/$cleanBarcode.json', cleanBarcode, country);
      if (opfResult != null) return opfResult;
    } catch (_) {}

    // 6. KATMAN: Açık Web Arama Motoru (DuckDuckGo Search Scraper - 100% Ücretsiz)
    try {
      final webResult = await _queryWebFallback(cleanBarcode, country);
      if (webResult != null) return webResult;
    } catch (_) {}

    // 7. KATMAN: Hiçbir yerde yoksa GS1 Menşei Bilgisiyle Jenerik Obje
    return BarcodeLookupResult(
      barcode: cleanBarcode,
      productName: cleanBarcode.startsWith('729')
          ? 'İsrail Tescilli Ürün ($cleanBarcode)'
          : 'Barkod: $cleanBarcode',
      brandName: cleanBarcode.startsWith('729') ? 'İsrail Menşeli' : '',
      originCountry: country,
      source: 'GS1 Menşei Analizi',
      isFromCache: false,
    );
  }

  /// Open Food/Beauty/Products Facts sorgulayıcı
  Future<BarcodeLookupResult?> _queryOpenFacts(String url, String barcode, String country) async {
    Response response;
    try {
      response = await _dio.get(url);
    } on DioException catch (e) {
      // Open Food Facts anonim kullanıcılara bazen 503 döner; sadece sunucu hatasında bir kez tekrar dene
      final code = e.response?.statusCode;
      if (code != null && code >= 500) {
        await Future.delayed(const Duration(milliseconds: 600));
        response = await _dio.get(url);
      } else {
        return null;
      }
    }
    if (response.statusCode == 200 && response.data != null) {
      final data = response.data is String ? jsonDecode(response.data) : response.data;
      if (data['status'] == 1 && data['product'] != null) {
        final product = data['product'];

        String pName = product['product_name_tr'] ??
            product['product_name'] ??
            product['generic_name_tr'] ??
            product['generic_name'] ??
            '';

        String bName = '';
        if (product['brands'] != null && (product['brands'] as String).isNotEmpty) {
          bName = (product['brands'] as String).split(',').first.trim();
        } else if (product['brands_tags'] != null && (product['brands_tags'] as List).isNotEmpty) {
          bName = (product['brands_tags'][0] as String).replaceAll('en:', '').replaceAll('-', ' ').trim();
        }

        if (bName.isEmpty && pName.isNotEmpty) {
          bName = pName.split(' ').first;
        }

        String? category;
        if (product['categories'] != null && (product['categories'] as String).isNotEmpty) {
          category = (product['categories'] as String).split(',').first.trim();
        }

        String? imageUrl = product['image_front_url'] ??
            product['image_front_small_url'] ??
            product['image_url'];

        if (pName.isNotEmpty || bName.isNotEmpty) {
          return BarcodeLookupResult(
            barcode: barcode,
            productName: pName.isNotEmpty ? pName : bName,
            brandName: bName.isNotEmpty ? bName : pName,
            category: category,
            imageUrl: imageUrl,
            originCountry: country,
            source: 'Açık Ürün Veritabanı',
            isFromCache: false,
          );
        }
      }
    }
    return null;
  }

  /// DuckDuckGo HTML üzerinden ürün adını ve markasını arayıp çıkaran web arama motoru (Sıkı doğrulama ile)
  Future<BarcodeLookupResult?> _queryWebFallback(String barcode, String country) async {
    final cleanBarcode = barcode.trim();
    final url = 'https://html.duckduckgo.com/html/?q=${Uri.encodeComponent(cleanBarcode)}';
    
    try {
      final response = await _dio.get(
        url,
        options: Options(
          responseType: ResponseType.plain,
          sendTimeout: const Duration(milliseconds: 3000),
          receiveTimeout: const Duration(milliseconds: 3000),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final document = html_parser.parse(response.data.toString());
        final resultBodies = document.querySelectorAll('.result__body');

        // En az 8 haneli son basamakları da kontrol et
        final minDigits = cleanBarcode.length >= 8
            ? cleanBarcode.substring(cleanBarcode.length - 8)
            : cleanBarcode;

        for (final body in resultBodies) {
          final titleEl = body.querySelector('.result__title a');
          final snippetEl = body.querySelector('.result__snippet');

          String title = titleEl?.text.trim() ?? '';
          String snippet = snippetEl?.text.trim() ?? '';
          final combined = '$title $snippet'.toLowerCase();

          // KESİN DOĞRULAMA: Sonuçta barkod numarası açıkça geçiyor mu?
          final hasBarcode = combined.contains(cleanBarcode.toLowerCase()) ||
              combined.contains(minDigits.toLowerCase());

          if (!hasBarcode) {
            // Sonuçta barkod numarası yoksa, DuckDuckGo'nun ilgisiz genel reklam/arama sonucudur (örn. WWE figürleri). Atla!
            continue;
          }

          // Arama artığı veya jenerik web sitesi başlıklarını ele
          final lowerTitle = title.toLowerCase();
          if (lowerTitle.contains('duckduckgo') ||
              lowerTitle.contains('barcode lookup') ||
              lowerTitle.contains('upc lookup') ||
              lowerTitle.contains('verified by gs1') ||
              lowerTitle.contains('ean search') ||
              lowerTitle.contains('search results')) {
            continue;
          }

          // Temiz ürün ve marka adı ayrıştırma
          String pName = title;
          if (pName.contains('|')) pName = pName.split('|').first.trim();
          if (pName.contains('-')) pName = pName.split('-').first.trim();
          if (pName.contains(':')) pName = pName.split(':').last.trim();

          // Sitenin sonuna eklenen '... - Trendyol' vb. etiketleri temizle
          pName = pName.replaceAll(RegExp(r'\s+'), ' ').trim();

          if (pName.length < 3 || pName.length > 70) continue;

          // Marka SADECE bilinen markalar listesinde tam kelime olarak geçiyorsa belirlenir.
          // (Önceden ilk kelime marka sanılıyordu; bu yanlış eşleşmelere yol açıyordu.)
          final knownKey = OfflineBoycottDatabase.findBrandKeyInText('$title $snippet');
          final bName = knownKey ?? '';

          return BarcodeLookupResult(
            barcode: cleanBarcode,
            productName: pName,
            brandName: bName,
            originCountry: country,
            source: 'Web Araması (tahmini)',
            isFromCache: false,
            isGuess: true,
          );
        }
      }
    } catch (_) {}
    return null;
  }
}
