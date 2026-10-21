import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import '../models/boycott_result.dart';
import 'bykt_service.dart';
import 'offline_data.dart';

class BoycottService {
  final ByktService _byktService = ByktService();

  ByktService get byktService => _byktService;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(milliseconds: 4000),
      receiveTimeout: const Duration(milliseconds: 4000),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,application/json,*/*;q=0.8',
      },
    ),
  );

  /// Marka veya ürün adına göre boykot durumunu, gerekçesini ve alternatiflerini getirir
  Future<ProductScanResult> checkBoycott({
    required String barcode,
    required String productName,
    required String brandName,
    String? category,
    String? imageUrl,
  }) async {
    final cleanBarcode = barcode.trim();

    // 0. ADIM: 729 Barkod Öneki Kontrolü (Doğrudan İsrail GS1 Tescili)
    if (cleanBarcode.startsWith('729')) {
      return ProductScanResult(
        barcode: barcode,
        productName: productName.isNotEmpty ? productName : 'İsrail Tescilli Ürün',
        brandName: brandName.isNotEmpty ? brandName : 'İsrail Menşeli',
        category: category,
        imageUrl: imageUrl,
        status: BoycottStatus.boycott,
        statusText: 'Boykot (İsrail Menşeli)',
        reason: 'Bu ürünün barkodu doğrudan İsrail GS1 tescillidir (729 kodu ile başlamaktadır). İsrail merkezli üretici veya ihracatçı şirket ürünüdür.',
        proofUrl: 'https://www.gs1.org/standards/barcodes/ean-upc',
        source: 'GS1 Uluslararası Menşei Tescili',
        alternatives: const [
          AlternativeProduct(name: 'Torku', category: 'Gıda', description: 'Konya Şeker kooperatifi yerli milli üretim'),
          AlternativeProduct(name: 'Eti', category: 'Atıştırmalık', description: 'Bağımsız yerli Türk üretimi'),
          AlternativeProduct(name: 'Bingo / Boron', category: 'Temizlik', description: 'Yerli formüllü temizlik ürünleri'),
        ],
      );
    }

    final queryBrand = brandName.trim().isNotEmpty ? brandName.trim() : productName.trim();

    // 1. ADIM: Yerel doğrulanmış veritabanında kesin BOYKOT varsa doğrudan dön (0 ms yanıt)
    final localMatch = OfflineBoycottDatabase.findBrandInfo(queryBrand);
    if (localMatch != null && localMatch['status'] == BoycottStatus.boycott) {
      final rawAlts = (localMatch['alternatives'] as List<dynamic>?) ?? [];
      final alternatives = rawAlts
          .map((a) => AlternativeProduct(
                name: a['name'] as String,
                category: a['category'] as String?,
                description: a['description'] as String?,
                isLocal: true,
              ))
          .toList();

      return ProductScanResult(
        barcode: barcode,
        productName: productName.isNotEmpty ? productName : queryBrand,
        brandName: brandName.isNotEmpty ? brandName : queryBrand,
        category: category,
        imageUrl: imageUrl,
        status: BoycottStatus.boycott,
        statusText: localMatch['statusText'] as String? ?? 'Boykot Listesinde',
        reason: localMatch['reason'] as String?,
        proofUrl: localMatch['proofUrl'] as String?,
        source: 'Boykot Dedektifi & Boykot.co Arşivi',
        alternatives: alternatives,
      );
    }

    // 2. ADIM: Tüm platformları (BYKT.ORG, Boykot Dedektifi, Boykot.co) eş zamanlı (paralel) tara
    // (Böylece sitelerden biri unutmuş olsa bile diğeri yakalar)
    final futures = await Future.wait([
      _byktService.queryBrand(queryBrand).catchError((_) => null),
      _queryBoykotDedektifi(queryBrand).catchError((_) => null),
      _queryBoykotCo(queryBrand).catchError((_) => null),
    ]);

    final byktRes = futures[0];
    final bdRes = futures[1];
    final bcoRes = futures[2];

    // Yerel eşleşme varsa onu da adaylara ekle
    Map<String, dynamic>? localCandidate;
    if (localMatch != null) {
      final rawAlts = (localMatch['alternatives'] as List<dynamic>?) ?? [];
      final alts = rawAlts
          .map((a) => AlternativeProduct(
                name: a['name'] as String,
                category: a['category'] as String?,
                description: a['description'] as String?,
                isLocal: true,
              ))
          .toList();

      localCandidate = {
        'brandName': queryBrand,
        'status': localMatch['status'] as BoycottStatus,
        'statusText': localMatch['statusText'] as String,
        'reason': localMatch['reason'] as String?,
        'proofUrl': localMatch['proofUrl'] as String?,
        'source': 'Yerel Arşiv',
        'alternatives': alts,
      };
    }

    final candidates = <Map<String, dynamic>>[
      if (localCandidate != null) localCandidate,
      if (byktRes != null) byktRes,
      if (bdRes != null) bdRes,
      if (bcoRes != null) bcoRes,
    ];

    if (candidates.isEmpty) {
      // Hiçbir sitede kayıt bulunamadı
      return ProductScanResult(
        barcode: barcode,
        productName: productName,
        brandName: queryBrand,
        category: category,
        imageUrl: imageUrl,
        status: BoycottStatus.unknown,
        statusText: 'Kayıt Bulunamadı',
        reason: 'Bu marka veya ürün kontrol edilen 3 boykot platformunda (BYKT.ORG, Boykot Dedektifi, Boykot.co) kayıtlı görünmüyor. Üretici ve çatı şirket ilişkisi araştırılmaktadır.',
        proofUrl: null,
        source: 'Sistem Taraması (3 Platform)',
        alternatives: const [],
      );
    }

    // -------------------------------------------------------------
    // TEMEL KURAL: 3 siteden en az BİRİNDE dahi BOYKOT olarak geçiyorsa
    // sonuç KESİN BOYKOT kabul edilir!
    // -------------------------------------------------------------
    final boycottCandidate = candidates.firstWhere(
      (c) => c['status'] == BoycottStatus.boycott,
      orElse: () => const {},
    );

    if (boycottCandidate.isNotEmpty) {
      // Boykot kararı veren tüm platformların isimlerini birleştir
      final boycottSources = candidates
          .where((c) => c['status'] == BoycottStatus.boycott)
          .map((c) => c['source'] as String? ?? 'Boykot Platformu')
          .toSet()
          .join(' & ');

      // Tüm kaynaklardaki alternatifleri birleştir ve tekilleştir
      final combinedAlts = <AlternativeProduct>[];
      for (final c in candidates) {
        final alts = c['alternatives'];
        if (alts is List) {
          for (final a in alts) {
            if (a is AlternativeProduct &&
                !combinedAlts.any((x) => x.name.toLowerCase() == a.name.toLowerCase())) {
              combinedAlts.add(a);
            }
          }
        }
      }

      // Logo/Resim önceliği
      String? foundLogo = imageUrl;
      if (foundLogo == null || foundLogo.isEmpty) {
        for (final c in candidates) {
          final logo = (c['logoUrl'] ?? c['imageUrl']) as String?;
          if (logo != null && logo.isNotEmpty) {
            foundLogo = logo;
            break;
          }
        }
      }

      return ProductScanResult(
        barcode: barcode,
        productName: productName.isNotEmpty ? productName : (boycottCandidate['brandName'] ?? queryBrand),
        brandName: boycottCandidate['brandName'] ?? queryBrand,
        category: category ?? boycottCandidate['category'],
        imageUrl: foundLogo,
        status: BoycottStatus.boycott,
        statusText: boycottCandidate['statusText'] ?? 'Boykot Listesinde',
        reason: boycottCandidate['reason'] as String?,
        proofUrl: boycottCandidate['proofUrl'] as String?,
        source: boycottSources,
        alternatives: combinedAlts,
      );
    }

    // -------------------------------------------------------------
    // İKİNCİ ÖNCELİK: Hiçbiri kesin boykot demedi ama en az biri
    // ŞÜPHELİ / İNSAFA BAĞLI dediyse
    // -------------------------------------------------------------
    final suspectedCandidate = candidates.firstWhere(
      (c) => c['status'] == BoycottStatus.suspected,
      orElse: () => const {},
    );

    if (suspectedCandidate.isNotEmpty) {
      final suspectedSources = candidates
          .where((c) => c['status'] == BoycottStatus.suspected)
          .map((c) => c['source'] as String? ?? 'Boykot Platformu')
          .toSet()
          .join(' & ');

      return ProductScanResult(
        barcode: barcode,
        productName: productName.isNotEmpty ? productName : (suspectedCandidate['brandName'] ?? queryBrand),
        brandName: suspectedCandidate['brandName'] ?? queryBrand,
        category: category ?? suspectedCandidate['category'],
        imageUrl: imageUrl ?? suspectedCandidate['logoUrl'] ?? suspectedCandidate['imageUrl'],
        status: BoycottStatus.suspected,
        statusText: suspectedCandidate['statusText'] ?? 'İnsafa Bağlı / Şüpheli',
        reason: suspectedCandidate['reason'] as String?,
        proofUrl: suspectedCandidate['proofUrl'] as String?,
        source: suspectedSources,
        alternatives: (suspectedCandidate['alternatives'] as List<AlternativeProduct>?) ?? [],
      );
    }

    // -------------------------------------------------------------
    // ÜÇÜNCÜ ÖNCELİK: Hiçbir platform boykot veya şüpheli demedi;
    // Raporlayan platformların tamamı TEMİZ / ALINABİLİR dedi
    // -------------------------------------------------------------
    final cleanCandidate = candidates.firstWhere(
      (c) => c['status'] == BoycottStatus.clean,
      orElse: () => candidates.first,
    );

    final cleanSources = candidates
        .where((c) => c['status'] == BoycottStatus.clean)
        .map((c) => c['source'] as String? ?? 'Boykot Platformu')
        .toSet()
        .join(' & ');

    return ProductScanResult(
      barcode: barcode,
      productName: productName.isNotEmpty ? productName : (cleanCandidate['brandName'] ?? queryBrand),
      brandName: cleanCandidate['brandName'] ?? queryBrand,
      category: category ?? cleanCandidate['category'],
      imageUrl: imageUrl ?? cleanCandidate['logoUrl'] ?? cleanCandidate['imageUrl'],
      status: BoycottStatus.clean,
      statusText: cleanCandidate['statusText'] ?? 'Boykot Değil (Temiz)',
      reason: cleanCandidate['reason'] as String? ?? 'Kontrol edilen platformlarda uygun ürün olarak değerlendirilmiştir.',
      proofUrl: cleanCandidate['proofUrl'] as String?,
      source: cleanSources.isNotEmpty ? cleanSources : 'Doğrulanmış Liste',
      alternatives: const [],
    );
  }

  /// Boykot Dedektifi API ve detay sayfası sorgusu
  Future<Map<String, dynamic>?> _queryBoykotDedektifi(String query) async {
    final searchUrl = 'https://boykotdedektifi.com/api/brands/search?term=${Uri.encodeComponent(query)}';
    final response = await _dio.get(searchUrl);

    if (response.statusCode == 200 && response.data != null) {
      final List items = response.data is String ? jsonDecode(response.data) : response.data;
      if (items.isNotEmpty) {
        final firstItem = items.first;
        final name = firstItem['name'] ?? query;
        final rawStatus = (firstItem['statusName'] ?? firstItem['statusBrandText'] ?? '').toString();
        final detailUrl = firstItem['url'] as String?;
        final logoPath = firstItem['logoPath'] as String?;

        BoycottStatus status = BoycottStatus.unknown;
        String statusText = 'İncelemede';

        if (rawStatus.toLowerCase().contains('boykot')) {
          status = BoycottStatus.boycott;
          statusText = 'Boykot Listesinde';
        } else if (rawStatus.toLowerCase().contains('uygun') || rawStatus.toLowerCase().contains('temiz')) {
          status = BoycottStatus.clean;
          statusText = 'Boykot Değil (Uygun)';
        }

        String? reason;
        String? proofUrl;
        List<AlternativeProduct> alternatives = [];

        // Detay sayfasını çekerek gerekçe ve alternatifleri ayrıştır
        if (detailUrl != null && detailUrl.isNotEmpty) {
          try {
            final pageUrl = 'https://boykotdedektifi.com$detailUrl';
            proofUrl = pageUrl;
            final pageRes = await _dio.get(pageUrl);
            if (pageRes.statusCode == 200 && pageRes.data != null) {
              final document = html_parser.parse(pageRes.data);

              // Gerekçe metni
              final alertBox = document.querySelector('.alert');
              if (alertBox != null) {
                reason = alertBox.text.trim();
              }

              // Alternatifler listesi
              final altCards = document.querySelectorAll('.brand-card');
              for (final card in altCards) {
                final altTitle = card.querySelector('h3')?.text.trim();
                final altDesc = card.querySelector('p')?.text.trim();
                final altImg = card.querySelector('img')?.attributes['src'];

                if (altTitle != null && altTitle.isNotEmpty) {
                  alternatives.add(
                    AlternativeProduct(
                      name: altTitle,
                      description: altDesc,
                      logoUrl: altImg,
                      isLocal: true,
                    ),
                  );
                }
              }
            }
          } catch (_) {}
        }

        return {
          'brandName': name,
          'status': status,
          'statusText': statusText,
          'reason': reason ?? (status == BoycottStatus.boycott ? 'Boykot Dedektifi platformunda boykotlu olarak kayıtlıdır.' : 'Uygun ürün olarak değerlendirilmiştir.'),
          'proofUrl': proofUrl,
          'logoUrl': logoPath,
          'alternatives': alternatives,
        };
      }
    }
    return null;
  }

  /// Boykot.co Arama sorgusu
  Future<Map<String, dynamic>?> _queryBoykotCo(String query) async {
    final response = await _dio.post(
      'https://www.boykot.co/cntrl.php',
      data: 'keyword=${Uri.encodeComponent(query)}',
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
      ),
    );

    if (response.statusCode == 200 && response.data != null) {
      final html = response.data.toString();
      if (html.isNotEmpty && !html.contains('Kayıt Bulunamadı')) {
        final document = html_parser.parse(html);
        final link = document.querySelector('a');
        final brandName = link?.text.trim() ?? query;
        final href = link?.attributes['href'];

        String? reason;
        String? proofUrl;
        List<AlternativeProduct> alternatives = [];

        if (href != null && href.isNotEmpty) {
          final detailUrl = href.startsWith('http') ? href : 'https://www.boykot.co$href';
          proofUrl = detailUrl;

          try {
            final pageRes = await _dio.get(detailUrl);
            if (pageRes.statusCode == 200 && pageRes.data != null) {
              final pageDoc = html_parser.parse(pageRes.data);

              // Başlık ve boykot kontrolü
              final h1 = pageDoc.querySelector('h1')?.text ?? '';
              final isBoycott = h1.toLowerCase().contains('boykot');

              // Neden boykot paragrafı
              final pList = pageDoc.querySelectorAll('p');
              for (final p in pList) {
                if (p.text.length > 50 && !p.text.contains('WhatsApp') && !p.text.contains('Paylaş')) {
                  reason = p.text.trim();
                  break;
                }
              }

              // Alternatifler bölümü
              final altHeader = pageDoc.getElementById('alternatif');
              if (altHeader != null) {
                final parent = altHeader.parent;
                final altText = parent?.text ?? '';
                if (altText.isNotEmpty) {
                  final lines = altText.split('\n');
                  for (final line in lines) {
                    final trimmed = line.trim();
                    if (trimmed.isNotEmpty && trimmed.length < 30 && !trimmed.contains('Alternatif')) {
                      alternatives.add(AlternativeProduct(name: trimmed, isLocal: true));
                    }
                  }
                }
              }

              return {
                'brandName': brandName,
                'status': isBoycott ? BoycottStatus.boycott : BoycottStatus.clean,
                'statusText': isBoycott ? 'Boykot Listesinde' : 'Boykot Değil',
                'reason': reason,
                'proofUrl': proofUrl,
                'alternatives': alternatives,
              };
            }
          } catch (_) {}
        }

        return {
          'brandName': brandName,
          'status': BoycottStatus.boycott,
          'statusText': 'Boykot Listesinde',
          'reason': 'Boykot.co veritabanında boykotlu olarak kayıtlıdır.',
          'proofUrl': proofUrl,
          'alternatives': alternatives,
        };
      }
    }
    return null;
  }
}
