import 'package:flutter_test/flutter_test.dart';
import 'package:boykotbarkodu/models/boycott_result.dart';
import 'package:boykotbarkodu/services/barcode_service.dart';
import 'package:boykotbarkodu/services/boycott_service.dart';
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

    test('Torku brand is detected as Clean / Not Boycott', () async {
      final result = await boycottService.checkBoycott(
        barcode: '8697426123456',
        productName: 'Torku Çikolata',
        brandName: 'Torku',
      );

      expect(result.isClean, isTrue);
    });

    test('729 barcode is flagged as Israeli origin', () async {
      final result = await boycottService.checkBoycott(
        barcode: '7290000000001',
        productName: '',
        brandName: '',
      );
      expect(result.isBoycott, isTrue);
    });
  });
}
