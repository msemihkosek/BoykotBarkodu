# 🛑 Boykot Barkodu

**Boykot Barkodu**, alışveriş yaparken ürünlerin barkodunu telefon kamerasıyla saniyeler içinde okuyarak boykot durumunu, boykot gerekçesini ve güvenilir yerli/temiz alternatif ürünleri gösteren modern bir mobil uygulamadır.

<p align="center">
  <img src="assets/images/app_logo.jpg" alt="Boykot Barkodu Logo" width="160" style="border-radius: 24px;" />
</p>

---

## ✨ Temel Özellikler

- **⚡ Hızlı Barkod Okuma:** EAN-13, EAN-8 ve UPC standartlarındaki perakende barkodlarını kamera ile anında algılar.
- **🛡️ Güvenilir Boykot Tespiti:**
  - **Boykot Dedektifi** (`boykotdedektifi.com`) ve **Boykot.co** güncel veritabanları ile canlı sorgulama.
  - Sık tüketilen yüzlerce ürün ve marka için **çevrimdışı (offline) hızlı veri tabanı**.
  - 729 ile başlayan barkodlar için otomatik menşei analizi.
- **🌱 Yerli ve Temiz Alternatifler:** Boykotlu bir ürün tarandığında, aynı kategorideki güvenilir yerli muadil ürün önerileri listelenir.
- **🤖 Boykot AI Asistanı ("AI'a Sor"):**
  - Yalnızca boykot konularına odaklı soru-cevap asistanı.
  - *"Ariel neden boykotta?"*, *"Nescafe yerine ne alabilirim?"*, *"729 barkod ne anlama gelir?"* gibi sorulara doğrulanmış kaynaklarla anında yanıt verir.
- **✍️ Akıllı Kullanıcı Düzeltmesi:** Barkod veritabanlarında bulunamayan veya yanlış algılanan ürünleri kullanıcı cihazında doğrudan doğru marka ile eşleştirebilir.
- **📋 Tarama Geçmişi:** Daha önce taranan ürünleri ve boykot istatistiklerini cihazınızda saklar.
- **🌙 Modern Koyu Tema:** Markette ve loş ışıkta rahat kullanım sağlayan koyu renk paleti ve akıcı kullanıcı arayüzü.

---

## 📱 Ekranlar & Akış

1. **Tarayıcı Ekranı:** Hızlı tarama alanı, flaş butonu, geçmiş ve AI asistan kısayolları.
2. **Sonuç Kartı:** Durum rozeti (Boykot / Temiz / Bilinmiyor), gerekçe metni, kaynak bağlantısı ve alternatif ürün kartları.
3. **Manuel Arama:** Barkodu yıpranmış veya okunamayan ürünler için isimle arama.
4. **AI Sohbet Ekranı:** Boykot gerekçeleri ve alternatifler hakkında etkileşimli sohbet.

---

## 🚀 Başlangıç & Kurulum

### Gereksinimler
- Flutter SDK (3.24+ veya üzeri)
- Dart SDK
- Android Studio / VS Code ve Android SDK

### Adımlar

1. Depoyu klonlayın:
   ```bash
   git clone https://github.com/KULLANICI_ADINIZ/boykotbarkodu.git
   cd boykotbarkodu
   ```

2. Bağımlılıkları yükleyin:
   ```bash
   flutter pub get
   ```

3. Uygulamayı çalıştırın:
   ```bash
   flutter run
   ```

### Testleri Çalıştırma
```bash
flutter test
```

---

## 🛠️ Kullanılan Teknolojiler

- **Flutter & Dart**
- **mobile_scanner:** Yüksek performanslı kamera barkod tarama
- **dio & html:** Canlı veri doğrulama ve web ayrıştırma
- **shared_preferences:** Yerel geçmiş ve kullanıcı tanımlı barkod önbelleği
- **google_fonts:** Modern tipografi

---

## 📄 Lisans

Bu proje açık kaynaklıdır ve eğitim/bilinçlendirme amacıyla geliştirilmiştir.
