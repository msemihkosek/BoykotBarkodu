import 'package:flutter_test/flutter_test.dart';
import 'package:boykotbarkodu/models/boycott_result.dart';
import 'package:boykotbarkodu/services/barcode_service.dart';
import 'package:boykotbarkodu/services/boycott_service.dart';
import 'package:boykotbarkodu/services/bykt_service.dart';
import 'package:boykotbarkodu/services/offline_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Brand matching (whole-word)', () {
    test('short generic words do not match a brand', () {
      expect(OfflineBoycottDatabase.findBrandInfo('Su'), isNull);
      expect(OfflineBoycottDatabase.findBrandInfo('WWE Figuren'), isNull);
    });

    test('longest brand name wins', () {
      final info = OfflineBoycottDatabase.findBrandInfo('Pınar Su Doğal 1.5L');
      expect(info, isNotNull);
      expect(info!['status'], BoycottStatus.clean);
    });

    test('brand found inside free text', () {
      expect(OfflineBoycottDatabase.findBrandKeyInText('ARIEL Dağ Esintisi 4kg'), 'ariel');
      expect(OfflineBoycottDatabase.findBrandKeyInText('Coca-Cola 330ml'), 'coca-cola');
    });
  });

  group('BarcodeService Tests', () {
    final service = BarcodeService();

    test('Verified Coca-Cola barcode resolves offline', () async {
      final result = await service.lookupBarcode('5449000000996');
      expect(result.brandName, 'Coca-Cola');
      expect(result.isFromCache, isTrue);
    });

    test('User correction overrides everything', () async {
      await service.saveUserBarcodeMapping('5449000000996', 'Bingo', 'Bingo Deterjan');
      final result = await service.lookupBarcode('5449000000996');
      expect(result.brandName, 'Bingo');
      expect(result.source, 'Kullanıcı Tanımlı');
    });
  });

  group('BYKT.ORG Service Tests', () {
    final bykt = ByktService();

    test('Loads 1300+ brands and resolves Alfa Romeo as Boycott', () async {
      final result = await bykt.queryBrand('Alfa Romeo');
      expect(result, isNotNull);
      expect(result!['status'], BoycottStatus.boycott);
      expect(result['statusText'], contains('Boykot'));
      expect(result['source'], 'BYKT.ORG');
      expect(result['reason'], isNotNull);
    });

    test('Resolves Beyoğlu Gazozu as Clean / Not Boycott', () async {
      final result = await bykt.queryBrand('Beyoğlu Gazozu');
      expect(result, isNotNull);
      expect(result!['status'], BoycottStatus.clean);
      expect(result['statusText'], contains('Alınabilir'));
      expect(result['source'], 'BYKT.ORG');
    });

    test('Normalizes and strips brand names like Asics and Loreal', () async {
      final asics = await bykt.queryBrand('asics');
      expect(asics, isNotNull);
      expect(asics!['status'], BoycottStatus.boycott);

      final loreal = await bykt.queryBrand("L'Oreal");
      expect(loreal, isNotNull);
      expect(loreal!['brandName'], contains('Loreal'));
    });
  });

  group('BoycottService Tests', () {
    final boycottService = BoycottService();

    test('Ariel brand is detected as Boycott with alternatives', () async {
      final result = await boycottService.checkBoycott(
        barcode: '8001090123456',
        productName: 'Ariel Dağ Esintisi',
        brandName: 'Ariel',
      );

      expect(result.isBoycott, isTrue);
      expect(result.reason, isNotNull);
      expect(result.alternatives.any((a) => a.name.contains('Bingo') || a.name.contains('Boron')), isTrue);
    });

    test('Eti brand is detected as Clean / Not Boycott', () async {
      final result = await boycottService.checkBoycott(
        barcode: '8690526012345',
        productName: 'Eti Karam Gurme',
        brandName: 'Eti',
      );

      expect(result.isClean, isTrue);
    });

    test('Consensus rule: If even one platform flags brand as Boycott, it becomes Boycott', () async {
      // Torku is clean in local database, but BYKT.ORG lists it as Boycott.
      // The consensus rule guarantees Boycott takes priority.
      final result = await boycottService.checkBoycott(
        barcode: '8697426123456',
        productName: 'Torku Çikolata',
        brandName: 'Torku',
      );

      expect(result.isBoycott, isTrue);
      expect(result.source, contains('BYKT.ORG'));
    });

    test('729 barcode is flagged as Israeli origin', () async {
      final result = await boycottService.checkBoycott(
        barcode: '7290000000001',
        productName: '',
        brandName: '',
      );
      expect(result.isBoycott, isTrue);
    });

    test('Resolves newly added BYKT.ORG brand Alfa Romeo correctly', () async {
      final result = await boycottService.checkBoycott(
        barcode: '',
        productName: 'Alfa Romeo Giulietta',
        brandName: 'Alfa Romeo',
      );

      expect(result.isBoycott, isTrue);
      expect(result.source, 'BYKT.ORG');
      expect(result.reason, contains('Stellantis'));
    });
  });
}
