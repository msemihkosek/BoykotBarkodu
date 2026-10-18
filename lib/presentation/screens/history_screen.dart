import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/boycott_result.dart';
import '../../services/history_service.dart';
import '../widgets/result_sheet.dart';
import '../widgets/status_badge.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final HistoryService _historyService = HistoryService();
  List<ProductScanResult> _history = [];
  Map<String, int> _stats = {'total': 0, 'boycott': 0, 'clean': 0, 'unknown': 0};
  bool _isLoading = true;
  String _selectedFilter = 'all'; // 'all', 'boycott', 'clean'

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final list = await _historyService.getHistory();
    final stats = await _historyService.getStats();
    if (mounted) {
      setState(() {
        _history = list;
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  List<ProductScanResult> get _filteredHistory {
    if (_selectedFilter == 'boycott') {
      return _history.where((i) => i.isBoycott).toList();
    } else if (_selectedFilter == 'clean') {
      return _history.where((i) => i.isClean).toList();
    }
    return _history;
  }

  void _showResultSheet(ProductScanResult result) {
    showModalBottomSheet(
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
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Geçmişi Temizle'),
        content: const Text('Tüm taranan ürün geçmişi silinecektir. Emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.boykotRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _historyService.clearHistory();
      _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tarama Geçmişi',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.boykotRed),
              tooltip: 'Geçmişi Temizle',
              onPressed: _confirmClearHistory,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryLight))
          : _history.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    // İstatistik Özeti Kartı
                    _buildStatsCard(isDark),

                    // Filtreleme Butonları (Tümü, Boykotlu, Temiz)
                    _buildFilterTabs(),

                    // Taranan Ürünler Listesi
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        itemCount: _filteredHistory.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = _filteredHistory[index];
                          return _buildHistoryItem(item, isDark);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildStatsCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Alışveriş Karnesi',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.neutralGray),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Toplam', '${_stats['total']}', AppColors.primaryLight),
              Container(width: 1, height: 28, color: Colors.grey.withValues(alpha: 0.2)),
              _buildStatItem('Boykotlu', '${_stats['boycott']}', AppColors.boykotRed),
              Container(width: 1, height: 28, color: Colors.grey.withValues(alpha: 0.2)),
              _buildStatItem('Temiz / Yerli', '${_stats['clean']}', AppColors.safeGreen),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.neutralGray),
        ),
      ],
    );
  }

  Widget _buildFilterTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          _buildFilterChip('Tümü (${_stats['total']})', 'all'),
          const SizedBox(width: 8),
          _buildFilterChip('Boykotlu (${_stats['boycott']})', 'boycott'),
          const SizedBox(width: 8),
          _buildFilterChip('Temiz (${_stats['clean']})', 'clean'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String key) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _selectedFilter = key);
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      side: BorderSide(
        color: isSelected ? AppColors.primaryLight : Colors.grey.withValues(alpha: 0.3),
      ),
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? AppColors.primaryLight : null,
      ),
    );
  }

  Widget _buildHistoryItem(ProductScanResult item, bool isDark) {
    final dateStr = DateFormat('dd MMM, HH:mm').format(item.scannedAt);

    return Dismissible(
      key: Key(item.barcode.isNotEmpty ? item.barcode : item.brandName + item.scannedAt.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.boykotRed,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) async {
        await _historyService.removeFromHistory(item.barcode);
        _loadHistory();
      },
      child: GestureDetector(
        onTap: () => _showResultSheet(item),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: item.isBoycott
                      ? AppColors.boykotRed.withValues(alpha: 0.12)
                      : item.isClean
                          ? AppColors.safeGreen.withValues(alpha: 0.12)
                          : AppColors.warnAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  item.isBoycott
                      ? Icons.cancel_rounded
                      : item.isClean
                          ? Icons.check_circle_rounded
                          : Icons.help_outline_rounded,
                  color: item.isBoycott
                      ? AppColors.boykotRed
                      : item.isClean
                          ? AppColors.safeGreen
                          : AppColors.warnAmber,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.brandName.isNotEmpty ? item.brandName : item.productName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (item.barcode.isNotEmpty) ...[
                          Flexible(
                            child: Text(
                              item.barcode,
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: AppColors.neutralGray,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.neutralGray,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              StatusBadge(status: item.status, text: item.statusText),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: 64,
              color: Colors.grey.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'Henüz Taranan Ürün Yok',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Markette okuttuğunuz ürünler burada listelenecek ve alışveriş geçmişiniz saklanacaktır.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.neutralGray),
            ),
          ],
        ),
      ),
    );
  }
}
