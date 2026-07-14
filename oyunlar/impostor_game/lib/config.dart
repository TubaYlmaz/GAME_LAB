// lib/config.dart

class AppConfig {
  // Node.js sunucunuz 3000 portunda çalıştığı için burayı 3000 yapıyoruz.
  // Tarayıcıda (Chrome) test ederken 'localhost' kalabilir.
  static const String serverUrl = "http://localhost:3000";

  // 💡 KÜÇÜK BİR TÜYOYLA GELECEĞE YATIRIM:
  // Eğer ileride projeyi telefon emülatöründe (Android) test ederseniz, 
  // emülatör bilgisayarın localhost'unu göremez. O zaman üstteki satırı yorum satırı yapıp
  // alttaki satırı açarsın kanka, şimdiden elinin altında dursun:
  // static const String serverUrl = "http://10.0.2.2:3000";
}