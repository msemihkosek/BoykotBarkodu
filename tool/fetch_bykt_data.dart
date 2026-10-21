// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';

/// BYKT.ORG verilerini çekip assets/data/bykt_brands.json dosyasına kaydeden script.
/// Çalıştırmak için: dart run tool/fetch_bykt_data.dart
void main() async {
  print('🚀 BYKT.ORG veri çekme işlemi başlatılıyor...');

  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'application/json, text/html, */*',
      },
    ),
  );

  const primaryUrl = 'https://bykt.org/brands.json';
  const fallbackUrl =
      'https://firebasestorage.googleapis.com/v0/b/boykot-listesi-e7b96.firebasestorage.app/o/brands.json?alt=media';

  Response? response;
  try {
    print('📥 $primaryUrl adresinden veri indiriliyor...');
    response = await dio.get(primaryUrl);
  } catch (e) {
    print('⚠️ Birincil adres başarısız ($e), yedek depolama deneniyor...');
    try {
      response = await dio.get(fallbackUrl);
    } catch (e2) {
      print('❌ İki adres de başarısız oldu: $e2');
      exit(1);
    }
  }

  if (response.statusCode != 200 || response.data == null) {
    print('❌ Başarısız HTTP yanıtı: ${response.statusCode}');
    exit(1);
  }

  final dynamic rawData = response.data;
  final List list = rawData is List ? rawData : jsonDecode(rawData.toString()) as List;

  print('✅ Başarıyla ${list.length} marka verisi alındı.');

  // İstatistikler
  int red = 0, orange = 0, green = 0;
  for (final item in list) {
    if (item is Map) {
      final status = (item['status'] as String? ?? '').toLowerCase();
      if (status == 'red') red++;
      if (status == 'orange') orange++;
      if (status == 'green') green++;
    }
  }

  print('📊 İstatistikler:');
  print('   🔴 Kesin Boykot (Red): $red');
  print('   🟡 İnsafa Bağlı (Orange): $orange');
  print('   🟢 Alınabilir / Temiz (Green): $green');

  final targetFile = File('assets/data/bykt_brands.json');
  targetFile.parent.createSync(recursive: true);
  final prettyJson = const JsonEncoder.withIndent('  ').convert(list);
  targetFile.writeAsStringSync(prettyJson);

  print('💾 Dosya kaydedildi: ${targetFile.path} (${(targetFile.lengthSync() / 1024).toStringAsFixed(1)} KB)');
  print('🎉 İşlem tamamlandı!');
}
