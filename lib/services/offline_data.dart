import '../models/boycott_result.dart';

class OfflineBoycottDatabase {
  /// GS1 Barkod Önekine Göre Menşei Ülke Tespiti
  static String getCountryFromBarcode(String barcode) {
    final clean = barcode.trim();
    if (clean.startsWith('729')) return 'İsrail';
    if (clean.startsWith('868') || clean.startsWith('869')) return 'Türkiye';
    if (clean.startsWith('50') || clean.startsWith('500') || clean.startsWith('509')) return 'Birleşik Krallık (İngiltere)';
    if (clean.startsWith('40') || clean.startsWith('41') || clean.startsWith('42') || clean.startsWith('43') || clean.startsWith('44')) return 'Almanya';
    if (clean.startsWith('30') || clean.startsWith('31') || clean.startsWith('32') || clean.startsWith('33') || clean.startsWith('34') || clean.startsWith('35') || clean.startsWith('36') || clean.startsWith('37')) return 'Fransa';
    if (clean.startsWith('80') || clean.startsWith('81') || clean.startsWith('82') || clean.startsWith('83')) return 'İtalya';
    if (clean.startsWith('76')) return 'İsviçre';
    if (clean.startsWith('84')) return 'İspanya';
    if (clean.startsWith('87')) return 'Hollanda';
    if (clean.startsWith('00') || clean.startsWith('01') || clean.startsWith('02') || clean.startsWith('03') || clean.startsWith('04') || clean.startsWith('05') || clean.startsWith('06') || clean.startsWith('07') || clean.startsWith('08') || clean.startsWith('09')) return 'ABD / Kanada';
    return 'Uluslararası';
  }

  /// SADECE gerçek ürün üzerinden doğrulanmış barkodlar burada tutulur.
  /// (Tahmini/uydurma barkod eklenmez; diğer ürünler API ve kullanıcı eşleştirmesiyle çözülür.)
  static final Map<String, Map<String, dynamic>> knownBarcodes = {
    '5449000000996': {'name': 'Coca-Cola 330ml Kutu', 'brand': 'Coca-Cola', 'category': 'Gazlı İçecek'},
  };

  /// Genişletilmiş Boykotlu ve Temiz Markalar Veritabanı
  static final Map<String, Map<String, dynamic>> brandDatabase = {
    // --- ÇATI ŞİRKETLER & MARKALARI (BOYKOTLU) ---
    'coca-cola': {
      'status': BoycottStatus.boycott,
      'statusText': 'Boykot Listesinde',
      'reason': 'The Coca-Cola Company, İsrail\'in işgal altındaki Batı Şeria Atarot yasadışı yerleşiminde ticari tesis işletmiş ve İsrail ordusu ile sponsorluk bağları belgelenmiştir.',
      'proofUrl': 'https://boykotdedektifi.com/b/coca-cola-26',
      'alternatives': [
        {'name': 'Cola Turka', 'category': 'Gazlı İçecek', 'description': 'Yerli sermaye ile üretilen gazlı içecek'},
        {'name': 'Uludağ Gazoz', 'category': 'Gazlı İçecek', 'description': 'Geleneksel Türk gazozu'},
        {'name': 'Beypazarı', 'category': 'Maden Suyu', 'description': 'Ankara Beypazarı doğal maden suyu'},
        {'name': 'Didi', 'category': 'Soğuk Çay', 'description': 'ÇAYKUR\'un yerli ve milli soğuk çayı'},
        {'name': 'Kızılay', 'category': 'İçecek', 'description': 'Milli üretim maden suları'},
      ],
    },
    'fanta': {
      'status': BoycottStatus.boycott,
      'statusText': 'Boykot Listesinde',
      'reason': 'The Coca-Cola Company çatısı altındadır.',
      'proofUrl': 'https://boykotdedektifi.com/b/coca-cola-26',
      'alternatives': [
        {'name': 'Uludağ Portakal', 'category': 'Gazlı İçecek', 'description': 'Yerli portakallı gazoz'},
        {'name': 'Niğde Gazozu', 'category': 'Gazlı İçecek', 'description': 'Yerli gazoz markası'},
      ],
    },
    'sprite': {
      'status': BoycottStatus.boycott,
      'statusText': 'Boykot Listesinde',
      'reason': 'The Coca-Cola Company çatısı altındadır.',
      'proofUrl': 'https://boykotdedektifi.com/b/coca-cola-26',
      'alternatives': [
        {'name': 'Çamlıca Gazoz', 'category': 'Gazlı İçecek', 'description': 'Yerli limon aromalı gazoz'},
        {'name': 'Uludağ Gazoz', 'category': 'Gazlı İçecek', 'description': 'Bursa menşeli yerli gazoz'},
      ],
    },
    'cappy': {
      'status': BoycottStatus.boycott,
      'statusText': 'Boykot Listesinde',
      'reason': 'The Coca-Cola Company grubuna aittir.',
      'proofUrl': 'https://boykotdedektifi.com/b/coca-cola-26',
      'alternatives': [
        {'name': 'Dimes', 'category': 'Meyve Suyu', 'description': 'Tokat merkezli yerli meyve suyu üreticisi'},
        {'name': 'Aroma', 'category': 'Meyve Suyu', 'description': 'Bursa menşeli yerli meyve suyu'},
        {'name': 'Meysu', 'category': 'Meyve Suyu', 'description': 'Kayseri menşeli yerli üretim'},
      ],
    },
    'fuse tea': {
      'status': BoycottStatus.boycott,
      'statusText': 'Boykot Listesinde',
      'reason': 'The Coca-Cola Company çatısı altındadır.',
      'proofUrl': 'https://boykotdedektifi.com/b/coca-cola-26',
      'alternatives': [
        {'name': 'Didi', 'category': 'Soğuk Çay', 'description': 'ÇAYKUR yerli soğuk çay'},
      ],
    },
    'pepsi': {
      'status': BoycottStatus.boycott,
      'statusText': 'Boykot Listesinde',
      'reason': 'PepsiCo, işgal topraklarındaki İsrailli SodaStream şirketini satın almış ve İsrail endüstrisine devasa yatırımlar yapmaktadır.',
      'proofUrl': 'https://boykotdedektifi.com/b/pepsi-27',
      'alternatives': [
        {'name': 'Cola Turka', 'category': 'Gazlı İçecek', 'description': 'Yerli kola alternatifi'},
        {'name': 'Uludağ Gazoz', 'category': 'Gazlı İçecek', 'description': 'Yerli gazoz'},
      ],
    },
    'yedigun': {
      'status': BoycottStatus.boycott,
      'statusText': 'Boykot Listesinde',
      'reason': 'PepsiCo bünyesindedir.',
      'proofUrl': 'https://boykotdedektifi.com/b/pepsi-27',
      'alternatives': [
        {'name': 'Uludağ Portakal', 'category': 'Gazlı İçecek', 'description': 'Yerli portakallı gazoz'},
      ],
    },
    'lipton': {
      'status': BoycottStatus.boycott,
      'statusText': 'Boykot Listesinde',
      'reason': 'Unilever grubuna ait olup İsrail ekonomisine ve küresel işgal Ar-Ge fonlarına doğrudan destek sunmaktadır.',
      'proofUrl': 'https://boykotdedektifi.com/b/lipton-37',
      'alternatives': [
        {'name': 'Çaykur / Didi', 'category': 'Çay / Soğuk Çay', 'description': 'Rize çayından üretilen milli marka'},
        {'name': 'Doğuş Çay', 'category': 'Çay', 'description': 'Türkiye menşeli yerli çay'},
        {'name': 'Karali Çay', 'category': 'Çay', 'description': 'Yerli Karadeniz çayı'},
      ],
    },
    'nescafe': {
      'status': BoycottStatus.boycott,
      'statusText': 'Boykot Listesinde',
      'reason': 'Nestlé şirketine aittir. Nestlé, İsrail merkezli gıda devi Osem\'in %100 kontrolüne sahiptir ve bölgede fabrikaları mevcuttur.',
      'proofUrl': 'https://boykotdedektifi.com/b/nescafe-112',
      'alternatives': [
        {'name': 'Kurukahveci Mehmet Efendi', 'category': 'Kahve', 'description': '1871\'den beri Türk kahvesi geleneği'},
        {'name': 'Mahmood Coffee', 'category': 'Kahve', 'description': 'Altunkaya Grubu yerli hazır kahve'},
        {'name': 'Shazel', 'category': 'Kahve', 'description': 'Yerli kahve üreticisi'},
        {'name': 'Kahve Dünyası', 'category': 'Kahve', 'description': 'Türkiye merkezli yerli kahve markası'},
      ],
    },
    'nestle': {
      'status': BoycottStatus.boycott,
      'statusText': 'Boykot Listesinde',
      'reason': 'Nestlé, İsrail\'in en büyük gıda üreticilerinden Osem\'in sahibidir ve İsrail ekonomisine doğrudan kaynak aktarmaktadır.',
      'proofUrl': 'https://boykotdedektifi.com/b/nestle-113',
      'alternatives': [
        {'name': 'Torku', 'category': 'Gıda', 'description': 'Konya Şeker çiftçi kooperatifi milli markası'},
        {'name': 'Eti', 'category': 'Gıda', 'description': 'Eskişehir menşeli yerli gıda markası'},
        {'name': 'Ülker', 'category': 'Gıda', 'description': 'Yıldız Holding yerli üretimi'},
      ],
    },
    'ariel': {
      'status': BoycottStatus.boycott,
      'statusText': 'Boykot Listesinde',
      'reason': 'Procter & Gamble (P&G), Tel Aviv\'deki Ar-Ge merkezi için yılda 2 milyar dolar kaynak aktarmaktadır. Barkan bölgesindeki yasadışı fabrikalarla ticari ortaklığı raporlanmıştır.',
      'proofUrl': 'https://boykotdedektifi.com/b/ariel-603',
      'alternatives': [
        {'name': 'Bingo', 'category': 'Deterjan', 'description': 'Hayat Kimya bünyesinde yerli üretim'},
        {'name': 'Boron', 'category': 'Deterjan', 'description': 'Eti Maden üretimi doğal bor deterjanı'},
        {'name': 'ABC Deterjan', 'category': 'Deterjan', 'description': 'Osmaniye / Bahçe fabrikasında üretilen yerli marka'},
        {'name': 'Peros', 'category': 'Deterjan', 'description': 'Beyaz Kağıt Adana tesisleri yerli üretimi'},
      ],
    },
    'fairy': {
      'status': BoycottStatus.boycott,
      'statusText': 'Boykot Listesinde',
      'reason': 'Procter & Gamble (P&G) çatısı altındadır.',
      'proofUrl': 'https://boykotdedektifi.com/b/fairy-604',
      'alternatives': [
        {'name': 'Bingo Sıvı Bulaşık', 'category': 'Bulaşık Deterjanı', 'description': 'Yerli formül'},
        {'name': 'Boron Bulaşık', 'category': 'Bulaşık Deterjanı', 'description': 'Eti Maden yerli bor mineralli bulaşık sıvısı'},
        {'name': 'Peros Bulaşık', 'category': 'Bulaşık Deterjanı', 'description': 'Yerli bulaşık deterjanı'},
      ],
    },
    'alo': {
      'status': BoycottStatus.boycott,
      'statusText': 'Boykot Listesinde',
      'reason': 'Procter & Gamble (P&G) çatısı altındadır.',
      'proofUrl': 'https://boykotdedektifi.com/b/alo-605',
      'alternatives': [
        {'name': 'Bingo', 'category': 'Deterjan', 'description': 'Yerli deterjan'},
        {'name': 'Boron', 'category': 'Deterjan', 'description': 'Doğal bor deterjanı'},
        {'name': 'ABC', 'category': 'Deterjan', 'description': 'Yerli deterjan'},
      ],
    },
    'domestos': {
      'status': BoycottStatus.boycott,
      'statusText': 'Boykot Listesinde',
      'reason': 'Unilever bünyesinde çamaşır suyu ve hijyen markasıdır.',
      'proofUrl': 'https://boykotdedektifi.com/b/domestos-38',
      'alternatives': [
        {'name': 'Bingo Çamaşır Suyu', 'category': 'Temizlik', 'description': 'Yerli üretim'},
        {'name': 'Porçöz', 'category': 'Temizlik', 'description': 'Levent Kimya yerli üretimi'},
        {'name': 'Asperox', 'category': 'Temizlik', 'description': 'Yerli çok amaçlı temizlik'},
      ],
    },
    'omo': {
      'status': BoycottStatus.boycott,
      'statusText': 'Boykot Listesinde',
      'reason': 'Unilever bünyesindedir.',
      'proofUrl': 'https://boykotdedektifi.com/b/omo-39',
      'alternatives': [
        {'name': 'Bingo', 'category': 'Deterjan', 'description': 'Yerli üretim'},
        {'name': 'Boron', 'category': 'Deterjan', 'description': 'Milli bor deterjanı'},
        {'name': 'Peros', 'category': 'Deterjan', 'description': 'Yerli deterjan'},
      ],
    },
    'cif': {
      'status': BoycottStatus.boycott,
      'statusText': 'Boykot Listesinde',
      'reason': 'Unilever bünyesindedir.',
      'proofUrl': 'https://boykotdedektifi.com/b/cif-40',
      'alternatives': [
        {'name': 'Asperox Sarı & Mavi Güç', 'category': 'Temizlik', 'description': 'Yerli yüzey temizleyici'},
        {'name': 'Bingo Krem', 'category': 'Temizlik', 'description': 'Yerli krem temizleyici'},
      ],
    },
    'doritos': {
      'status': BoycottStatus.boycott,
      'statusText': 'Boykot Listesinde',
      'reason': 'PepsiCo grubuna aittir. PepsiCo, İsrail SodaStream şirketini satın almıştır.',
      'proofUrl': 'https://boykotdedektifi.com/b/doritos-42',
      'alternatives': [
        {'name': 'Patos', 'category': 'Cips', 'description': 'Doğuş Yiyecek yerli mısır cipsi'},
        {'name': 'Cipso', 'category': 'Cips', 'description': 'Doğuş Yiyecek yerli patates cipsi'},
        {'name': 'Çerezos', 'category': 'Cips', 'description': 'Yerli mısır çerezi'},
      ],
    },
    'ruffles': {
      'status': BoycottStatus.boycott,
      'statusText': 'Boykot Listesinde',
      'reason': 'PepsiCo bünyesindedir.',
      'proofUrl': 'https://boykotdedektifi.com/b/ruffles-43',
      'alternatives': [
        {'name': 'Cipso', 'category': 'Cips', 'description': 'Doğuş yerli patates cipsi'},
        {'name': 'Patos', 'category': 'Cips', 'description': 'Yerli cips alternatifi'},
      ],
    },
    'lays': {
      'status': BoycottStatus.boycott,
      'statusText': 'Boykot Listesinde',
      'reason': 'PepsiCo bünyesindedir.',
      'proofUrl': 'https://boykotdedektifi.com/b/lays-44',
      'alternatives': [
        {'name': 'Cipso', 'category': 'Cips', 'description': 'Yerli patates cipsi'},
        {'name': 'Patos', 'category': 'Cips', 'description': 'Yerli cips'},
      ],
    },
    'algida': {
      'status': BoycottStatus.boycott,
      'statusText': 'Boykot Listesinde',
      'reason': 'Unilever bünyesindedir.',
      'proofUrl': 'https://boykotdedektifi.com/b/algida-46',
      'alternatives': [
        {'name': 'Golf Dondurma', 'category': 'Dondurma', 'description': 'Natura Gıda yerli dondurma üreticisi'},
        {'name': 'Mado', 'category': 'Dondurma', 'description': 'Kahramanmaraş dövme dondurması'},
        {'name': 'Akdo', 'category': 'Dondurma', 'description': 'Yerli Maraş dondurması'},
      ],
    },
    'milka': {
      'status': BoycottStatus.boycott,
      'statusText': 'Boykot Listesinde',
      'reason': 'Mondelez International bünyesindedir. Mondelez, İsrailli gıda teknolojisi fonu The Kitchen Hub ile stratejik ortaklık yapmaktadır.',
      'proofUrl': 'https://boykotdedektifi.com/b/milka-89',
      'alternatives': [
        {'name': 'Torku Çikolata', 'category': 'Çikolata', 'description': 'Pancar şekerli yerli çikolata'},
        {'name': 'Eti', 'category': 'Çikolata', 'description': 'Karam, Canga, Browni yerli ürünler'},
        {'name': 'Ülker', 'category': 'Çikolata', 'description': 'Yerli çikolata çeşitleri'},
      ],
    },
    'danone': {
      'status': BoycottStatus.boycott,
      'statusText': 'Boykot Listesinde',
      'reason': 'Danone, İsrailli süt üreticisi Strauss Group ile ortaklık kurarak İsrail gıda teknolojisi girişimlerine fon aktarmaktadır.',
      'proofUrl': 'https://boykotdedektifi.com/b/danone-71',
      'alternatives': [
        {'name': 'Sütaş', 'category': 'Süt Ürünleri', 'description': 'Bursa Karacabey yerli süt devi'},
        {'name': 'Pınar', 'category': 'Süt Ürünleri', 'description': 'Yaşar Holding yerli süt üreticisi'},
        {'name': 'Torku', 'category': 'Süt Ürünleri', 'description': 'Doğal çiftçi kooperatifi sütü'},
        {'name': 'Yörükoğlu', 'category': 'Süt Ürünleri', 'description': 'Antalya menşeli yerli süt markası'},
        {'name': 'Kebir', 'category': 'Süt Ürünleri', 'description': 'Trabzon menşeli yerli tereyağı ve süt ürünleri'},
      ],
    },
    'erikli': {
      'status': BoycottStatus.boycott,
      'statusText': 'Boykot Listesinde',
      'reason': 'Erikli, İsviçre merkezli Nestlé grubuna aittir. Nestlé, İsrailli gıda devi Osem\'in %100 kontrolüne sahiptir ve İsrail\'de yoğun tesisleri bulunmaktadır.',
      'proofUrl': 'https://boykotdedektifi.com/b/erikli-114',
      'alternatives': [
        {'name': 'Pınar Su', 'category': 'Su', 'description': 'Yaşar Holding yerli doğal kaynak suyu'},
        {'name': 'Hamidiye Su', 'category': 'Su', 'description': 'Milli ve yerli doğal kaynak suyu'},
        {'name': 'Saka Su', 'category': 'Su', 'description': 'Doğal mineralli su'},
        {'name': 'Abant Su', 'category': 'Su', 'description': 'Bolu Abant yerli kaynak suyu'},
        {'name': 'Munzur Su', 'category': 'Su', 'description': 'Ovacık kooperatifi yerli doğal kaynak suyu'},
        {'name': 'Taşkesti Su', 'category': 'Su', 'description': 'Bolu yerli mineralli kaynak suyu'},
        {'name': 'Buzdağı Su', 'category': 'Su', 'description': 'Sakarya yerli kaynak suyu'},
      ],
    },
    'hayat': {
      'status': BoycottStatus.boycott,
      'statusText': 'Boykot Listesinde',
      'reason': 'Hayat Su, Fransız Danone grubuna aittir. Danone, İsrailli Strauss Group ile ortaklık yapmakta ve İsrail merkezli girişimleri fonlamaktadır.',
      'proofUrl': 'https://boykotdedektifi.com/b/hayat-su-72',
      'alternatives': [
        {'name': 'Pınar Su', 'category': 'Su', 'description': 'Yerli kaynak suyu'},
        {'name': 'Hamidiye Su', 'category': 'Su', 'description': 'Yerli milli kaynak suyu'},
        {'name': 'Saka Su', 'category': 'Su', 'description': 'Doğal mineralli su'},
        {'name': 'Abant Su', 'category': 'Su', 'description': 'Bolu Abant kaynak suyu'},
        {'name': 'Buzdağı Su', 'category': 'Su', 'description': 'Sakarya yerli kaynak suyu'},
      ],
    },
    'sirma': {
      'status': BoycottStatus.boycott,
      'statusText': 'Boykot Listesinde',
      'reason': 'Sırma Su ve Maden Suyu, Fransız Danone grubuna aittir.',
      'proofUrl': 'https://boykotdedektifi.com/b/sirma-73',
      'alternatives': [
        {'name': 'Beypazarı', 'category': 'Maden Suyu', 'description': 'Ankara Beypazarı yerli maden suyu'},
        {'name': 'Kızılay', 'category': 'Maden Suyu', 'description': 'Milli Kızılay maden suları'},
        {'name': 'Pınar Su', 'category': 'Su', 'description': 'Yerli kaynak suyu'},
      ],
    },
    'damla': {
      'status': BoycottStatus.boycott,
      'statusText': 'Boykot Listesinde',
      'reason': 'The Coca-Cola Company bünyesinde yer alan su markasıdır.',
      'proofUrl': 'https://boykotdedektifi.com/b/coca-cola-26',
      'alternatives': [
        {'name': 'Hamidiye Su', 'category': 'Su', 'description': 'Yerli kaynak suyu'},
        {'name': 'Pınar Su', 'category': 'Su', 'description': 'Yerli su markası'},
        {'name': 'Saka Su', 'category': 'Su', 'description': 'Doğal mineralli su'},
        {'name': 'Taşkesti Su', 'category': 'Su', 'description': 'Yerli doğal kaynak suyu'},
      ],
    },
    'pinar su': {
      'status': BoycottStatus.clean,
      'statusText': 'Boykot Değil (Yerli)',
      'reason': 'Yaşar Holding bünyesinde Türkiye merkezli yerli doğal kaynak suyu üreticisidir.',
      'proofUrl': null,
      'alternatives': [],
    },
    'saka su': {
      'status': BoycottStatus.clean,
      'statusText': 'Boykot Değil (Yerli / Temiz)',
      'reason': 'Sakarya Hendek ve Çamlıca kaynaklı doğal mineralli su markasıdır. Boykot kapsamında değildir.',
      'proofUrl': null,
      'alternatives': [],
    },
    'hamidiye': {
      'status': BoycottStatus.clean,
      'statusText': 'Boykot Değil (Milli / Yerli)',
      'reason': '1902 yılından beri Sultan II. Abdülhamid tarafından kurulan İstanbul kaynaklı milli su markasıdır.',
      'proofUrl': null,
      'alternatives': [],
    },
    'munzur': {
      'status': BoycottStatus.clean,
      'statusText': 'Boykot Değil (Yerli)',
      'reason': 'Tunceli Ovacık dağlarından çıkan %100 yerli ve kooperatif kaynak suyudur.',
      'proofUrl': null,
      'alternatives': [],
    },
    'abant su': {
      'status': BoycottStatus.clean,
      'statusText': 'Boykot Değil (Yerli)',
      'reason': 'Bolu Abant dağları kaynaklı Türk sermayeli doğal kaynak suyu üreticisidir.',
      'proofUrl': null,
      'alternatives': [],
    },
    'taskesti': {
      'status': BoycottStatus.clean,
      'statusText': 'Boykot Değil (Yerli)',
      'reason': 'Bolu Taşkesti beldesi kaynaklı yerli doğal mineralli kaynak suyudur.',
      'proofUrl': null,
      'alternatives': [],
    },
    'buzdagi': {
      'status': BoycottStatus.clean,
      'statusText': 'Boykot Değil (Yerli)',
      'reason': 'Sakarya Geyve kaynaklı bağımsız yerli doğal mineralli kaynak suyudur.',
      'proofUrl': null,
      'alternatives': [],
    },
    'javsu': {
      'status': BoycottStatus.clean,
      'statusText': 'Boykot Değil (Milli Vakıf)',
      'reason': 'Jandarma Asayiş Vakfı iştiraki olan milli doğal mineralli sudur.',
      'proofUrl': null,
      'alternatives': [],
    },

    // --- TEMİZ & YERLİ TÜRK MARKALARI ---
    'torku': {
      'status': BoycottStatus.clean,
      'statusText': 'Boykot Değil (Milli / Kooperatif)',
      'reason': 'Konya Şeker çiftçi kooperatifinin %100 yerli ve milli gıda markasıdır. Güvenle tüketebilirsiniz.',
      'proofUrl': null,
      'alternatives': [],
    },
    'eti': {
      'status': BoycottStatus.clean,
      'statusText': 'Boykot Değil (Yerli)',
      'reason': 'Eskişehir merkezli bağımsız Türk bisküvi, kek ve çikolata üreticisidir. Boykot kapsamında değildir.',
      'proofUrl': null,
      'alternatives': [],
    },
    'ulker': {
      'status': BoycottStatus.clean,
      'statusText': 'Boykot Değil (Yerli)',
      'reason': 'Yıldız Holding bünyesinde Türkiye merkezli gıda üreticisidir. Boykot kapsamında değildir.',
      'proofUrl': null,
      'alternatives': [],
    },
    'caykur': {
      'status': BoycottStatus.clean,
      'statusText': 'Boykot Değil (Milli)',
      'reason': 'Türkiye Cumhuriyeti Çay İşletmeleri Genel Müdürlüğü milli çay üreticisidir.',
      'proofUrl': null,
      'alternatives': [],
    },
    'didi': {
      'status': BoycottStatus.clean,
      'statusText': 'Boykot Değil (Milli)',
      'reason': 'ÇAYKUR tarafından Rize çayından üretilen yerli ve milli soğuk çay markasıdır.',
      'proofUrl': null,
      'alternatives': [],
    },
    'bingo': {
      'status': BoycottStatus.clean,
      'statusText': 'Boykot Değil (Yerli)',
      'reason': 'Hayat Kimya bünyesinde %100 Türk sermayeli deterjan ve temizlik markasıdır.',
      'proofUrl': null,
      'alternatives': [],
    },
    'boron': {
      'status': BoycottStatus.clean,
      'statusText': 'Boykot Değil (Milli Bor)',
      'reason': 'Eti Maden İşletmeleri tarafından Türk bor minerallerinden üretilen milli temizlik markasıdır.',
      'proofUrl': null,
      'alternatives': [],
    },
    'peros': {
      'status': BoycottStatus.clean,
      'statusText': 'Boykot Değil (Yerli)',
      'reason': 'Beyaz Kağıt Sanayi bünyesinde Adana fabrikasında üretilen yerli temizlik markasıdır.',
      'proofUrl': null,
      'alternatives': [],
    },
    'asperox': {
      'status': BoycottStatus.clean,
      'statusText': 'Boykot Değil (Yerli)',
      'reason': 'Beyaz Kağıt tarafından üretilen Sarı ve Mavi Güç yerli temizlik ürünleridir.',
      'proofUrl': null,
      'alternatives': [],
    },
    'abc': {
      'status': BoycottStatus.clean,
      'statusText': 'Boykot Değil (Yerli)',
      'reason': 'Başer Kimya Osmaniye tesislerinde üretilen yerli deterjan markasıdır.',
      'proofUrl': null,
      'alternatives': [],
    },
    'duru': {
      'status': BoycottStatus.clean,
      'statusText': 'Boykot Değil (Yerli)',
      'reason': 'Evyap bünyesinde %100 Türk sermayeli sabun ve kişisel bakım markasıdır.',
      'proofUrl': null,
      'alternatives': [],
    },
    'arko': {
      'status': BoycottStatus.clean,
      'statusText': 'Boykot Değil (Yerli)',
      'reason': 'Evyap bünyesinde yerli krem ve tıraş ürünleri markasıdır.',
      'proofUrl': null,
      'alternatives': [],
    },
    'eyup sabri tuncer': {
      'status': BoycottStatus.clean,
      'statusText': 'Boykot Değil (Yerli)',
      'reason': '1923 yılından beri faaliyet gösteren Türk kolonya ve kişisel bakım markasıdır.',
      'proofUrl': null,
      'alternatives': [],
    },
    'sutas': {
      'status': BoycottStatus.clean,
      'statusText': 'Boykot Değil (Yerli)',
      'reason': 'Bursa Karacabey merkezli Türk süt ve süt ürünleri üreticisidir.',
      'proofUrl': null,
      'alternatives': [],
    },
    'pinar': {
      'status': BoycottStatus.clean,
      'statusText': 'Boykot Değil (Yerli)',
      'reason': 'Yaşar Holding bünyesinde Türkiye merkezli süt ve gıda markasıdır.',
      'proofUrl': null,
      'alternatives': [],
    },
    'beypazari': {
      'status': BoycottStatus.clean,
      'statusText': 'Boykot Değil (Yerli Doğal)',
      'reason': 'Ankara Beypazarı doğal maden suyu kaynağında şişelenen yerli içecektir.',
      'proofUrl': null,
      'alternatives': [],
    },
    'kizilay': {
      'status': BoycottStatus.clean,
      'statusText': 'Boykot Değil (Milli)',
      'reason': 'Türk Kızılayı maden suyu ve içecek üretimidir. Geliri insani yardımlara aktarılır.',
      'proofUrl': null,
      'alternatives': [],
    },
    'uludag': {
      'status': BoycottStatus.clean,
      'statusText': 'Boykot Değil (Yerli)',
      'reason': 'Bursa menşeli Erbak-Uludağ İçecek A.Ş. yerli gazoz ve meşrubat üreticisidir.',
      'proofUrl': null,
      'alternatives': [],
    },
  };

  /// Marka ismini temizleyip normalize ederek arar
  static Map<String, dynamic>? findBrandInfo(String query) {
    return _matchBrand(query)?.value;
  }

  /// Serbest metin (web başlığı, ürün adı) içinde bilinen bir marka geçiyorsa
  /// o markanın anahtarını döndürür. Sadece tam kelime eşleşmesi yapar.
  static String? findBrandKeyInText(String text) => _matchBrand(text)?.key;

  /// Tam kelime (token) eşleşmesi; en uzun marka adı kazanır.
  /// Böylece "su" gibi kısa sorgular veya "eti" gibi kelime parçaları yanlış marka eşleştirmez.
  static MapEntry<String, Map<String, dynamic>>? _matchBrand(String text) {
    final queryTokens = _tokens(text);
    if (queryTokens.isEmpty) return null;
    final padded = ' ${queryTokens.join(' ')} ';

    MapEntry<String, Map<String, dynamic>>? best;
    int bestLen = 0;
    for (final entry in brandDatabase.entries) {
      final keyTokens = _tokens(entry.key);
      if (keyTokens.isEmpty) continue;
      final keyPadded = ' ${keyTokens.join(' ')} ';
      if (padded.contains(keyPadded) && keyPadded.length > bestLen) {
        best = entry;
        bestLen = keyPadded.length;
      }
    }
    return best;
  }

  /// Türkçe karakterleri sadeleştirip kelimelere ayırır (sohbet modülü de kullanır).
  static List<String> tokenize(String text) => _tokens(text);

  static List<String> _tokens(String text) {
    return text
        .replaceAll('İ', 'i')
        .replaceAll('I', 'i')
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .split(' ')
        .where((t) => t.isNotEmpty)
        .toList();
  }
}
