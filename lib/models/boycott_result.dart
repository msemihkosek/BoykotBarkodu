enum BoycottStatus {
  boycott, // 🔴 Boykot listesinde
  clean,   // 🟢 Boykot değil / Temiz / Yerli
  suspected, // 🟡 İncelemede / Şüpheli
  unknown, // ⚪ Bilgi bulunamadı
}

class AlternativeProduct {
  final String name;
  final String? category;
  final String? logoUrl;
  final String? description;
  final bool isLocal;

  const AlternativeProduct({
    required this.name,
    this.category,
    this.logoUrl,
    this.description,
    this.isLocal = true,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'category': category,
    'logoUrl': logoUrl,
    'description': description,
    'isLocal': isLocal,
  };

  factory AlternativeProduct.fromJson(Map<String, dynamic> json) => AlternativeProduct(
    name: json['name'] as String? ?? '',
    category: json['category'] as String?,
    logoUrl: json['logoUrl'] as String?,
    description: json['description'] as String?,
    isLocal: json['isLocal'] as bool? ?? true,
  );
}

class ProductScanResult {
  final String barcode;
  final String productName;
  final String brandName;
  final String? category;
  final String? imageUrl;
  final BoycottStatus status;
  final String statusText;
  final String? reason;
  final String? proofUrl;
  final String source;
  final List<AlternativeProduct> alternatives;
  final DateTime scannedAt;

  /// Ürün adı/markası doğrulanmamış bir kaynaktan (web araması) tahmin edildiyse true.
  final bool isGuess;

  ProductScanResult({
    required this.barcode,
    required this.productName,
    required this.brandName,
    this.category,
    this.imageUrl,
    required this.status,
    required this.statusText,
    this.reason,
    this.proofUrl,
    this.source = 'Boykot Veri Havuzu',
    this.alternatives = const [],
    DateTime? scannedAt,
    this.isGuess = false,
  }) : scannedAt = scannedAt ?? DateTime.now();

  ProductScanResult copyWith({bool? isGuess}) => ProductScanResult(
        barcode: barcode,
        productName: productName,
        brandName: brandName,
        category: category,
        imageUrl: imageUrl,
        status: status,
        statusText: statusText,
        reason: reason,
        proofUrl: proofUrl,
        source: source,
        alternatives: alternatives,
        scannedAt: scannedAt,
        isGuess: isGuess ?? this.isGuess,
      );

  bool get isBoycott => status == BoycottStatus.boycott;
  bool get isClean => status == BoycottStatus.clean;
  bool get isUnknown => status == BoycottStatus.unknown;

  Map<String, dynamic> toJson() => {
    'barcode': barcode,
    'productName': productName,
    'brandName': brandName,
    'category': category,
    'imageUrl': imageUrl,
    'status': status.name,
    'statusText': statusText,
    'reason': reason,
    'proofUrl': proofUrl,
    'source': source,
    'alternatives': alternatives.map((a) => a.toJson()).toList(),
    'scannedAt': scannedAt.toIso8601String(),
    'isGuess': isGuess,
  };

  factory ProductScanResult.fromJson(Map<String, dynamic> json) {
    BoycottStatus status = BoycottStatus.unknown;
    final statusStr = json['status'] as String?;
    if (statusStr != null) {
      status = BoycottStatus.values.firstWhere(
        (e) => e.name == statusStr,
        orElse: () => BoycottStatus.unknown,
      );
    }

    final altList = (json['alternatives'] as List<dynamic>?)
            ?.map((e) => AlternativeProduct.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return ProductScanResult(
      barcode: json['barcode'] as String? ?? '',
      productName: json['productName'] as String? ?? '',
      brandName: json['brandName'] as String? ?? '',
      category: json['category'] as String?,
      imageUrl: json['imageUrl'] as String?,
      status: status,
      statusText: json['statusText'] as String? ?? 'Bilinmiyor',
      reason: json['reason'] as String?,
      proofUrl: json['proofUrl'] as String?,
      source: json['source'] as String? ?? 'Boykot Veri Havuzu',
      alternatives: altList,
      scannedAt: json['scannedAt'] != null
          ? DateTime.tryParse(json['scannedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      isGuess: json['isGuess'] as bool? ?? false,
    );
  }
}
