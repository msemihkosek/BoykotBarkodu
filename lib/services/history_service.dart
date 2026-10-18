import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/boycott_result.dart';

class HistoryService {
  static const String _keyHistory = 'boykot_scan_history';

  /// Geçmişteki tüm taranmış ürünleri getirir (en yeniden eskiye)
  Future<List<ProductScanResult>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_keyHistory) ?? [];
      return list
          .map((item) => ProductScanResult.fromJson(jsonDecode(item) as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    } catch (_) {
      return [];
    }
  }

  /// Yeni taranan ürünü geçmişe kaydeder
  Future<void> addToHistory(ProductScanResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentList = await getHistory();

      // Aynı barkod varsa önce eskisini çıkar (en başa güncel hali gelecek)
      currentList.removeWhere((item) => item.barcode == result.barcode && item.barcode.isNotEmpty);
      currentList.insert(0, result);

      // En fazla 100 kayıt sakla
      final trimmed = currentList.take(100).toList();

      final jsonList = trimmed.map((item) => jsonEncode(item.toJson())).toList();
      await prefs.setStringList(_keyHistory, jsonList);
    } catch (_) {}
  }

  /// Belirli bir barkodu geçmişten siler
  Future<void> removeFromHistory(String barcode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentList = await getHistory();
      currentList.removeWhere((item) => item.barcode == barcode);

      final jsonList = currentList.map((item) => jsonEncode(item.toJson())).toList();
      await prefs.setStringList(_keyHistory, jsonList);
    } catch (_) {}
  }

  /// Tüm geçmişi temizler
  Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyHistory);
    } catch (_) {}
  }

  /// Market tarama istatistiklerini hesaplar
  Future<Map<String, int>> getStats() async {
    final list = await getHistory();
    int total = list.length;
    int boycottCount = list.where((i) => i.isBoycott).length;
    int cleanCount = list.where((i) => i.isClean).length;
    int unknownCount = total - boycottCount - cleanCount;

    return {
      'total': total,
      'boycott': boycottCount,
      'clean': cleanCount,
      'unknown': unknownCount,
    };
  }
}
