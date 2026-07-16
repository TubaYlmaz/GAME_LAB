// lib/config.dart

class AppConfig {
  // 1. 💻 Kendi bilgisayarındaki tarayıcı (Chrome) testleri için:
  static const String localWebUrl = "http://localhost:3000";

  // 2. 📱 Telefon testleri için (Telefonun kendi ağındayken bilgisayarının aldığı IP'yi buraya yaz kanka):
  static const String localMobileUrl = "http://10.87.97.21:3000"; 

  // 3. 🚀 Yarın bir gün oyunu canlı sunucuya (AWS, Render vb.) yüklediğinde buraya o adresi yazacaksın:
  static const String productionUrl = "https://gamelab-backend.onrender.com";


  // 🎯 AKTİF BAĞLANTI ADRESİ:
  // Telefonla test ederken burayı 'localMobileUrl' yap kanka.
  // Canlıya çıkarken tek yapman gereken burayı 'productionUrl' olarak değiştirmek!
  static const String serverUrl = localMobileUrl; 
}