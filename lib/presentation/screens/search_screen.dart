import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/boycott_result.dart';
import '../../services/boycott_service.dart';
import '../../services/history_service.dart';
import '../widgets/result_sheet.dart';
import '../widgets/status_badge.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final BoycottService _boycottService = BoycottService();
  final HistoryService _historyService = HistoryService();

  Timer? _debounce;
  bool _isLoading = false;
  ProductScanResult? _searchResult;
  String? _searchedQuery;

  final List<String> _popularBrands = [
    'Coca-Cola',
    'Ariel',
    'Nescafe',
    'Lipton',
    'Fairy',
    'Doritos',
    'Algida',
    'Milka',
    'Eti',
    'Torku',
    'Bingo',
    'Boron',
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _searchResult = null;
        _searchedQuery = null;
        _isLoading = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _executeSearch(query);
    });
  }

  Future<void> _executeSearch(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    setState(() {
      _isLoading = true;
      _searchedQuery = cleanQuery;
    });

    try {
      final result = await _boycottService.checkBoycott(
        barcode: '',
        productName: cleanQuery,
        brandName: cleanQuery,
      );

      if (mounted) {
        setState(() {
          _searchResult = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showResultSheet(ProductScanResult result) {
    _historyService.addToHistory(result);
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Marka veya Ürün Ara',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              // Arama Kutusu
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _executeSearch,
                  decoration: InputDecoration(
                    hintText: 'Örn: Coca-Cola, Ariel, Lipton...',
                    hintStyle: TextStyle(
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryLight),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Yükleniyor veya Sonuç veya Popüler Aramalar
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: AppColors.primaryLight),
                            SizedBox(height: 14),
                            Text('Boykot veritabanı taranıyor...'),
                          ],
                        ),
                      )
                    : _searchResult != null
                        ? _buildSearchResultCard(_searchResult!)
                        : _buildPopularSection(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopularSection() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sık Aranan Markalar',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _popularBrands.map((brand) {
              return ActionChip(
                label: Text(brand),
                backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                onPressed: () {
                  _searchController.text = brand;
                  _executeSearch(brand);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: AppColors.primaryLight, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'İpucu: Barkodunu okutamadığınız ürünlerin marka ismini doğrudan yazarak anında sorgulama yapabilirsiniz.',
                    style: TextStyle(fontSize: 12.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultCard(ProductScanResult result) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '"$_searchedQuery" için sonuç:',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.neutralGray),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _showResultSheet(result),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: result.isBoycott
                      ? AppColors.boykotRedBorder
                      : result.isClean
                          ? AppColors.safeGreenBorder
                          : AppColors.warnAmberBorder,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          result.brandName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      StatusBadge(status: result.status, text: result.statusText),
                    ],
                  ),
                  if (result.reason != null && result.reason!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      result.reason!,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (result.alternatives.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.swap_horiz_rounded, color: AppColors.safeGreen, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '${result.alternatives.length} alternatif marka mevcut',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.safeGreen,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Detaylar >',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: () => _showResultSheet(result),
              icon: const Icon(Icons.open_in_full_rounded, size: 16),
              label: const Text('Tüm Detayları ve Alternatifleri Gör'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
