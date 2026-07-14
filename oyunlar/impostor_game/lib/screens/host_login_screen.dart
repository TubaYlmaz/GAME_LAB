// lib/screens/host_login_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Rakam sınırlaması ve JSON okumak için kanka
import 'host_screen.dart';
import 'player_screen.dart'; 

class HostLoginScreen extends StatefulWidget {
  const HostLoginScreen({super.key});

  @override
  State<HostLoginScreen> createState() => _HostLoginScreenState();
}

class _HostLoginScreenState extends State<HostLoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _hostNameController = TextEditingController();
  final TextEditingController _playerNameController = TextEditingController();
  final TextEditingController _roomCodeController = TextEditingController();

  // =========================================================================
  // ⚙️ GÜNCELLENEN YER: HOST AYAR DEĞİŞKENLERİ VE CONTROLLER
  // =========================================================================
  String _selectedMod = 'Klasik';
  String _selectedCategory = 'Rastgele';
  
  // İmpostor sayısını klavyeden elle almak için text controller ekledik kanka
  final TextEditingController _impostorCountController = TextEditingController(text: '1');

  final List<String> _oyunModlari = ['Klasik', 'Yakin Kelime'];
  List<String> _kategoriler = ['Rastgele']; 
  bool _isJsonLoading = true; // JSON yüklenirken bekletmek için kanka
  // =========================================================================

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _kategorileriYukle(); // Ekran açılır açılmaz JSON'ı tarıyoruz kanka 🔥
  }

  // JSON dosyasının içindeki kategori isimlerini dinamik çeken fonksiyon kanka
  Future<void> _kategorileriYukle() async {
    try {
      final String response = await rootBundle.loadString('dictionary.json');
      final Map<String, dynamic> data = json.decode(response);
      
      setState(() {
        _kategoriler = ['Rastgele', ...data.keys.toList()];
        _isJsonLoading = false;
      });
    } catch (e) {
      debugPrint("JSON okuma hatası kanka: $e");
      setState(() { _isJsonLoading = false; });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hostNameController.dispose();
    _playerNameController.dispose();
    _roomCodeController.dispose();
    _impostorCountController.dispose(); // Bellek sızıntısı yapmasın diye dispose ediyoruz kanka
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F2027),
              Color(0xFF203A43),
              Color(0xFF2C5364),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 450),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F1E).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white10, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 30),
                    const Icon(Icons.videogame_asset_rounded, size: 60, color: Colors.redAccent),
                    const SizedBox(height: 10),
                    const Text(
                      'IMPOSTOR GAME',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    
                    // Üst Sekmeler
                    TabBar(
                      controller: _tabController,
                      indicatorColor: Colors.redAccent,
                      labelColor: Colors.redAccent,
                      unselectedLabelColor: Colors.grey,
                      indicatorWeight: 3,
                      tabs: const [
                        Tab(text: 'ODA KUR (HOST)'),
                        Tab(text: 'ODAYA KATIL'),
                      ],
                    ),
                    
                    // JSON yüklenirken spinner dönüyor, yüklenince içerik geliyor kanka
                    _isJsonLoading
                        ? const Padding(
                            padding: EdgeInsets.all(40.0),
                            child: CircularProgressIndicator(color: Colors.redAccent),
                          )
                        : IntrinsicHeight(
                            child: SizedBox(
                              width: double.infinity,
                              child: AnimatedBuilder(
                                animation: _tabController,
                                builder: (context, child) {
                                  return IndexedStack(
                                    index: _tabController.index,
                                    children: [
                                      _buildHostForm(),
                                      _buildJoinForm(),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

// 1. Sekme: ODA KURMA FORMU 🚀
  Widget _buildHostForm() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Theme(
        data: Theme.of(context).copyWith(canvasColor: const Color(0xFF1A1A2E)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // İsim Girişi
            TextField(
              controller: _hostNameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'İsminiz (Öğretmen/Host)',
                labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 2)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
              ),
            ),
            const SizedBox(height: 16),

            // OYUN MODU SEÇİM KARTLARI 🚀
            const Text(
              'Oyun Modu Seçiniz',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            
            RepaintBoundary(
              child: Row(
                children: [
                  // 1. Kart: Klasik Mod
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedMod = 'Klasik';
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 8),
                        decoration: BoxDecoration(
                          color: _selectedMod == 'Klasik'
                              ? const Color(0xFF1A1A2E)
                              : const Color(0xFF101026),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedMod == 'Klasik'
                                ? Colors.redAccent
                                : Colors.white10,
                            width: _selectedMod == 'Klasik' ? 2 : 1,
                          ),
                          boxShadow: _selectedMod == 'Klasik'
                              ? [
                                  BoxShadow(
                                    color: Colors.redAccent.withOpacity(0.2),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  )
                                ]
                              : [],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.visibility_off_rounded,
                              color: _selectedMod == 'Klasik'
                                  ? Colors.redAccent
                                  : Colors.grey,
                              size: 28,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Klasik',
                              style: TextStyle(
                                color: _selectedMod == 'Klasik'
                                    ? Colors.white
                                    : Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'İmpostor kelimeyi görmez',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _selectedMod == 'Klasik'
                                    ? Colors.white70
                                    : Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // 2. Kart: Yakın Kelime Modu
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedMod = 'Yakin Kelime';
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 8),
                        decoration: BoxDecoration(
                          color: _selectedMod == 'Yakin Kelime'
                              ? const Color(0xFF1A1A2E)
                              : const Color(0xFF101026),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedMod == 'Yakin Kelime'
                                ? Colors.redAccent
                                : Colors.white10,
                            width: _selectedMod == 'Yakin Kelime' ? 2 : 1,
                          ),
                          boxShadow: _selectedMod == 'Yakin Kelime'
                              ? [
                                  BoxShadow(
                                    color: Colors.redAccent.withOpacity(0.2),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  )
                                ]
                              : [],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.compare_arrows_rounded,
                              color: _selectedMod == 'Yakin Kelime'
                                  ? Colors.redAccent
                                  : Colors.grey,
                              size: 28,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Yakın Kelime',
                              style: TextStyle(
                                color: _selectedMod == 'Yakin Kelime'
                                    ? Colors.white
                                    : Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'İmpostor benzer kelime alır',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _selectedMod == 'Yakin Kelime'
                                    ? Colors.white70
                                    : Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 📂 GERİ EKLENEN KATEGORİ SEÇİM ALANI (DROPDOWN) 🚀
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              dropdownColor: const Color(0xFF1A1A2E),
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                labelText: 'Kelime Kategorisi Seçin',
                labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white10),
                ),
              ),
              items: _kategoriler.map((String kategori) {
                return DropdownMenuItem<String>(
                  value: kategori,
                  child: Text(kategori),
                );
              }).toList(),
              onChanged: (String? yeniDeger) {
                if (yeniDeger != null) {
                  setState(() {
                    _selectedCategory = yeniDeger;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // İmpostor Sayısı Giriş Alanı
            TextField(
              controller: _impostorCountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'İmpostor Sayısı (Örn: 2, 5...)',
                labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 2)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
              ),
            ),
            const SizedBox(height: 24),

            // ODA OLUŞTUR BUTONU
            ElevatedButton(
              onPressed: () {
                if (_hostNameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lütfen isminizi girin!')),
                  );
                  return;
                }
                
                int parsedImpostorCount = int.tryParse(_impostorCountController.text.trim()) ?? 1;
                if (parsedImpostorCount < 1) parsedImpostorCount = 1;

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HostScreen(
                      gameMode: _selectedMod,
                      category: _selectedCategory, // 👈 Seçilen kategori artık buraya aslanlar gibi gidiyor!
                      impostorCount: parsedImpostorCount,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 5,
              ),
              child: const Text('ODA OLUŞTUR', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }

  // 2. Sekme: ODAYA KATILMA FORMU
  Widget _buildJoinForm() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _playerNameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Oyuncu Adı',
              labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              filled: true,
              fillColor: const Color(0xFF1A1A2E),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent, width: 2)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _roomCodeController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Oda Kodu',
              labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              filled: true,
              fillColor: const Color(0xFF1A1A2E),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent, width: 2)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              String pName = _playerNameController.text.trim();
              String rCode = _roomCodeController.text.trim().toUpperCase();

              if (pName.isEmpty || rCode.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lütfen isim ve oda kodunu eksiksiz doldurun!')),
                );
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PlayerScreen(playerName: pName, roomCode: rCode),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E2E5C),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: const BorderSide(color: Color(0xFF00D2FF), width: 1),
            ),
            child: const Text('ODAYA KATIL', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15, letterSpacing: 1)),
          ),
        ],
      ),
    );
  }
}