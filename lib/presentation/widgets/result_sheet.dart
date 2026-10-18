import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../models/boycott_result.dart';
import '../../services/barcode_service.dart';
import '../../services/boycott_service.dart';
import '../../services/history_service.dart';
import '../../services/offline_data.dart';
import '../screens/chat_screen.dart';
import 'status_badge.dart';

class ProductResultSheet extends StatefulWidget {
  final ProductScanResult result;
  final VoidCallback onRescan;

  const ProductResultSheet({
    super.key,
    required this.result,
    required this.onRescan,
  });

  @override
  State<ProductResultSheet> createState() => _ProductResultSheetState();
}

class _ProductResultSheetState extends State<ProductResultSheet> {
  late ProductScanResult _currentResult;
  final BarcodeService _barcodeService = BarcodeService();
  final BoycottService _boycottService = BoycottService();
  final HistoryService _historyService = HistoryService();
  bool _isRechecking = false;

  @override
  void initState() {
    super.initState();
    _currentResult = widget.result;
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Barkod için doğrudan Google / DuckDuckGo araması açar (100% ücretsiz dış teyit)
  Future<void> _searchOnGoogle() async {
    final query = _currentResult.barcode.isNotEmpty
        ? _currentResult.barcode
        : _currentResult.brandName;
    final url = 'https://www.google.com/search?q=${Uri.encodeComponent(query)}';
    await _launchUrl(url);
  }

  /// Kullanıcının bu barkodu bir marka ile eşleştirmesini sağlayan modal
  void _openManualBrandLinkDialog() {
    final brandController = TextEditingController(text: _currentResult.brandName);
    final productController = TextEditingController(
      text: _currentResult.productName != _currentResult.brandName ? _currentResult.productName : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Marka & Ürünü Tanıt',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Bu barkod için marka adını yazın; boykot veritabanından anında sorgulanıp telefonunuza kaydedilecektir.',
                  style: TextStyle(fontSize: 13, color: AppColors.neutralGray),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: brandController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Marka Adı (Örn: Lipton, Çamlıca, Eti, Bingo)*',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: productController,
                  decoration: InputDecoration(
                    labelText: 'Ürün Adı (İsteğe bağlı, örn: Şeftali Soğuk Çay 1L)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: () async {
                    final enteredBrand = brandController.text.trim();
                    if (enteredBrand.isEmpty) return;

                    Navigator.pop(ctx);
                    setState(() => _isRechecking = true);

                    // 1. Kullanıcı eşleştirmesini kaydet
                    if (_currentResult.barcode.isNotEmpty) {
                      await _barcodeService.saveUserBarcodeMapping(
                        _currentResult.barcode,
                        enteredBrand,
                        productController.text.trim(),
                      );
                    }

                    // 2. Boykot durumunu yeniden sorgula
                    final newResult = await _boycottService.checkBoycott(
                      barcode: _currentResult.barcode,
                      productName: productController.text.trim().isNotEmpty
                          ? productController.text.trim()
                          : enteredBrand,
                      brandName: enteredBrand,
                    );

                    if (mounted) {
                      await _historyService.addToHistory(newResult);
                      setState(() {
                        _currentResult = newResult;
                        _isRechecking = false;
                      });
                    }
                  },
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Kaydet ve Boykot Durumunu Sorgula'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final country = _currentResult.barcode.isNotEmpty
        ? OfflineBoycottDatabase.getCountryFromBarcode(_currentResult.barcode)
        : null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Üst çekme çubuğu
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Durum Rozeti
              Center(
                child: StatusBadge(
                  status: _currentResult.status,
                  text: _currentResult.statusText,
                  isLarge: true,
                ),
              ),
              const SizedBox(height: 16),

              if (_isRechecking)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primaryLight),
                  ),
                )
              else ...[
                // Ürün Başlığı ve Görsel
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardDark : AppColors.neutralGrayLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF475569) : AppColors.borderLight,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _currentResult.imageUrl != null && _currentResult.imageUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: _currentResult.imageUrl!,
                              fit: BoxFit.contain,
                              placeholder: (_, __) => const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (_, __, ___) => _buildFallbackIcon(),
                            )
                          : _buildFallbackIcon(),
                    ),
                    const SizedBox(width: 14),

                    // İsim ve Kategori Bilgisi
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentResult.brandName.isNotEmpty
                                ? _currentResult.brandName
                                : _currentResult.productName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_currentResult.brandName.isNotEmpty &&
                              _currentResult.productName != _currentResult.brandName) ...[
                            const SizedBox(height: 3),
                            Text(
                              _currentResult.productName,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 8),

                          // Barkod ve Menşei Etiketleri
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (_currentResult.barcode.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _currentResult.barcode,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              if (country != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: country.contains('İsrail')
                                        ? AppColors.boykotRed.withValues(alpha: 0.15)
                                        : country.contains('Türkiye')
                                            ? AppColors.safeGreen.withValues(alpha: 0.15)
                                            : Colors.grey.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        country.contains('Türkiye')
                                            ? '🇹🇷 $country'
                                            : country.contains('İsrail')
                                                ? '🚨 $country'
                                                : '🌐 $country',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: country.contains('İsrail')
                                              ? AppColors.boykotRed
                                              : country.contains('Türkiye')
                                                  ? AppColors.safeGreen
                                                  : (isDark ? Colors.white70 : Colors.black87),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Tahmini (doğrulanmamış) ürün uyarısı
                if (_currentResult.isGuess) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warnAmber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.warnAmberBorder),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: AppColors.warnAmber, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Bu ürün adı web aramasından tahmin edildi ve yanlış olabilir. Paketteki markayı kontrol edin; yanlışsa aşağıdan düzeltin.',
                            style: TextStyle(fontSize: 12.5, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Gerekçe ve Açıklama Alanı
                if (_currentResult.reason != null && _currentResult.reason!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _currentResult.isBoycott
                          ? (isDark ? const Color(0xFF2C151B) : AppColors.boykotRedLight)
                          : _currentResult.isClean
                              ? (isDark ? const Color(0xFF132A24) : AppColors.safeGreenLight)
                              : (isDark ? const Color(0xFF2B2515) : AppColors.warnAmberLight),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _currentResult.isBoycott
                            ? AppColors.boykotRedBorder
                            : _currentResult.isClean
                                ? AppColors.safeGreenBorder
                                : AppColors.warnAmberBorder,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _currentResult.isBoycott
                                  ? Icons.info_outline_rounded
                                  : _currentResult.isClean
                                      ? Icons.verified_outlined
                                      : Icons.help_outline_rounded,
                              size: 18,
                              color: _currentResult.isBoycott
                                  ? AppColors.boykotRed
                                  : _currentResult.isClean
                                      ? AppColors.safeGreen
                                      : AppColors.warnAmber,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _currentResult.isBoycott
                                  ? 'Boykot Gerekçesi ve Arka Plan'
                                  : _currentResult.isClean
                                      ? 'Üretici ve Güvenilirlik Bilgisi'
                                      : 'Sistem Değerlendirmesi',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _currentResult.isBoycott
                                  ? AppColors.boykotRed
                                  : _currentResult.isClean
                                      ? AppColors.safeGreen
                                      : AppColors.warnAmber,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _currentResult.reason!,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.55,
                            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                          ),
                        ),
                        if (_currentResult.proofUrl != null && _currentResult.proofUrl!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () => _launchUrl(_currentResult.proofUrl!),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Detaylı Kanıt ve Kaynağı İncele',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: _currentResult.isBoycott ? AppColors.boykotRed : AppColors.primary,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.open_in_new_rounded,
                                    size: 14,
                                    color: _currentResult.isBoycott ? AppColors.boykotRed : AppColors.primary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                // Bulunamayan veya Bilinmeyen Ürünler İçin Hızlı Çözüm Kutusu
                if (_currentResult.isUnknown || _currentResult.brandName.isEmpty || _currentResult.isGuess) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.auto_fix_high_rounded, color: AppColors.primaryLight, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Ürün Net Bulunamadı mı?',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Ürünün paketindeki marka adını girerek anında boykot veritabanından sorgulayabilir ve bu barkodu hafızaya kaydedebilirsiniz.',
                          style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.neutralGray),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _openManualBrandLinkDialog,
                                icon: const Icon(Icons.edit_note_rounded, size: 18),
                                label: const Text('Markayı Tanıt / Eşleştir'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primaryLight,
                                  side: const BorderSide(color: AppColors.primaryLight),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.outlined(
                              onPressed: _searchOnGoogle,
                              icon: const Icon(Icons.search_rounded),
                              tooltip: 'Google\'da Ara',
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryLight,
                                side: const BorderSide(color: AppColors.primaryLight),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Önerilen Alternatifler (Boykotlu ise veya alternatif mevcutsa)
                if (_currentResult.alternatives.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Önerilen Yerli & Temiz Alternatifler',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.safeGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_currentResult.alternatives.length} Marka',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.safeGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _currentResult.alternatives.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final alt = _currentResult.alternatives[index];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.cardDark : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.safeGreen.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.verified_rounded,
                                color: AppColors.safeGreen,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        alt.name,
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      if (alt.isLocal)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: AppColors.safeGreen.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'YERLİ',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.safeGreen,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (alt.description != null && alt.description!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      alt.description!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],

                // Her sonuç için: yanlış gösterilen ürünü düzeltme bağlantısı
                if (!(_currentResult.isUnknown || _currentResult.brandName.isEmpty || _currentResult.isGuess)) ...[
                  Center(
                    child: TextButton.icon(
                      onPressed: _openManualBrandLinkDialog,
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Sonuç yanlış mı? Markayı düzelt'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.neutralGray),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],

                // Marka hakkında AI'a soru sorma butonu
                if (_currentResult.brandName.trim().isNotEmpty) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final brand = _currentResult.brandName;
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              initialQuestion: '$brand neden boykotta, alternatifi var mı?',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.forum_rounded, size: 18),
                      label: Text(
                        'AI\'a Sor: "${_currentResult.brandName}"',
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryLight,
                        side: BorderSide(color: AppColors.primaryLight.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Alt Butonlar
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: widget.onRescan,
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: const Text('Yeni Ürün Tara'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackIcon() {
    final text = _currentResult.brandName.isNotEmpty
        ? _currentResult.brandName[0].toUpperCase()
        : '?';
    return Center(
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: AppColors.primaryLight,
        ),
      ),
    );
  }
}
