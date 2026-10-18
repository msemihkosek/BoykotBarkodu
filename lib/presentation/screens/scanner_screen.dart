import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/app_theme.dart';
import '../../models/boycott_result.dart';
import '../../services/barcode_service.dart';
import '../../services/boycott_service.dart';
import '../../services/history_service.dart';
import '../widgets/result_sheet.dart';
import '../widgets/scanner_overlay.dart';
import 'chat_screen.dart';
import 'history_screen.dart';
import 'search_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  late final MobileScannerController _scannerController;
  final BarcodeService _barcodeService = BarcodeService();
  final BoycottService _boycottService = BoycottService();
  final HistoryService _historyService = HistoryService();

  bool _isProcessing = false;
  bool _isSheetOpen = false;
  bool _isFlashOn = false;
  String? _lastScannedCode;
  DateTime? _lastScannedTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
      returnImage: false,
      formats: const [
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
      ],
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_scannerController.value.isInitialized) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _scannerController.stop();
    } else if (state == AppLifecycleState.resumed) {
      _scannerController.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    // Bottom sheet açıkken, başka sayfa üstteyken veya işlem devam ederken tarama yapma
    if (_isProcessing || _isSheetOpen) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue?.trim();
    if (rawValue == null || rawValue.isEmpty) return;

    // Aynı barkodun 2 saniye içinde tekrar tetiklenmesini engelle
    final now = DateTime.now();
    if (_lastScannedCode == rawValue &&
        _lastScannedTime != null &&
        now.difference(_lastScannedTime!).inSeconds < 2) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _lastScannedCode = rawValue;
      _lastScannedTime = now;
    });

    HapticFeedback.mediumImpact();

    // Yükleniyor diyaloğu veya göstergesi
    _showLoadingIndicator();

    try {
      // 1. Barkod çözümle
      final lookup = await _barcodeService.lookupBarcode(rawValue);

      // 2. Boykot durumunu sorgula
      final checked = await _boycottService.checkBoycott(
        barcode: lookup.barcode,
        productName: lookup.productName,
        brandName: lookup.brandName,
        category: lookup.category,
        imageUrl: lookup.imageUrl,
      );
      final result = lookup.isGuess ? checked.copyWith(isGuess: true) : checked;

      // 3. Geçmişe kaydet
      await _historyService.addToHistory(result);

      if (mounted) {
        // Yükleniyor'u kapat
        Navigator.of(context, rootNavigator: true).pop();

        // Sonuç sayfasını aç ve kullanıcı kapatana kadar bekle
        await _showResultSheet(result);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sorgulama sırasında bir hata oluştu: $e'),
            backgroundColor: AppColors.boykotRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showLoadingIndicator() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: AppColors.primaryLight,
                strokeWidth: 3,
              ),
              SizedBox(height: 16),
              Text(
                'Ürün ve Boykot Bilgisi Sorgulanıyor...',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showResultSheet(ProductScanResult result) async {
    setState(() {
      _isSheetOpen = true;
    });

    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ProductResultSheet(
          result: result,
          onRescan: () {
            Navigator.pop(context);
          },
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSheetOpen = false;
          // Sayfa kapandıktan hemen sonra aynı ürünün kazara tekrar okunmaması için zamanı tazele
          _lastScannedTime = DateTime.now();
        });
      }
    }
  }

  void _toggleFlash() async {
    await _scannerController.toggleTorch();
    setState(() {
      _isFlashOn = !_isFlashOn;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanWindowSize = size.width * 0.76;
    final scanWindow = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: scanWindowSize,
      height: scanWindowSize * 0.72,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Kamera Görüntüsü
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleBarcode,
            errorBuilder: (context, error, child) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam_off_rounded, color: Colors.white70, size: 48),
                      const SizedBox(height: 12),
                      const Text(
                        'Kameraya erişilemedi veya izin verilmedi.',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.errorDetails?.message ?? 'Lütfen uygulama ayarlarından kamera iznini açın.',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 2. Animasyonlu Tarama Katmanı (Overlay)
          ScannerOverlay(scanWindow: scanWindow),

          // 3. Üst Bar (Logo, Flaş, Geçmiş)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo ve İsim
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.asset(
                            'assets/images/app_logo.jpg',
                            width: 22,
                            height: 22,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Boykot Barkodu',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Flaş ve Geçmiş Butonları
                  Row(
                    children: [
                      _buildTopIconButton(
                        icon: _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                        color: _isFlashOn ? Colors.amber : Colors.white,
                        onTap: _toggleFlash,
                      ),
                      const SizedBox(width: 8),
                      _buildTopIconButton(
                        icon: Icons.forum_rounded,
                        color: AppColors.primaryLight,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ChatScreen()),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildTopIconButton(
                        icon: Icons.history_rounded,
                        color: Colors.white,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const HistoryScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 4. Orta Bilgi İpucu
          Positioned(
            top: scanWindow.bottom + 24,
            left: 20,
            right: 20,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: const Text(
                  'Ürün barkodunu kare alanın içine hizalayın',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          // 5. Alt Hızlı Arama Butonu
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: SafeArea(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  );
                },
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.search_rounded, color: AppColors.primaryLight, size: 22),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Barkod okunmuyor mu? Marka adı ile ara...',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
