// lib/screens/host_login_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:socket_io_client/socket_io_client.dart'
    as IO; // 🔌 Soket kütüphanesini ekledik[cite: 4]
import '../config.dart'; // ⚙️ Config dosyamızı çektik[cite: 4]
import 'host_screen.dart'; //[cite: 4]
import 'player_screen.dart'; //[cite: 4]
import 'dart:html' as html; // 🌐 Tarayıcı yönlendirmesi için ekledik[cite: 4]

class HostLoginScreen extends StatefulWidget {
  const HostLoginScreen({super.key});

  @override
  State<HostLoginScreen> createState() => _HostLoginScreenState();
}

class _HostLoginScreenState extends State<HostLoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _hostNameController = TextEditingController();
  final TextEditingController _playerNameController = TextEditingController();
  final TextEditingController _roomCodeController = TextEditingController();

  late IO.Socket _socket; // 🔌 Canlı soket değişkenimiz[cite: 4]
  bool _isSocketConnected = false;

  String _selectedMod = 'Klasik';
  String _selectedCategory = 'Rastgele';

  final TextEditingController _impostorCountController = TextEditingController(
    text: '1',
  );

  final List<String> _oyunModlari = ['Klasik', 'Yakin Kelime'];
  List<String> _kategoriler = ['Rastgele'];
  bool _isJsonLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _kategorileriYukle();
    _initSocket(); // 🔌 Soketi hemen ayağa kaldırıyoruz kanka![cite: 4]
  }

  // Canlı soket bağlantısını kuran fonksiyon kanka[cite: 4]
  void _initSocket() {
    _socket = IO.io(
      AppConfig.serverUrl,
      IO.OptionBuilder()
          .setTransports([
            'websocket',
          ]) // WebAssembly ve mobil uyumluluğu için önemli[cite: 4]
          .disableAutoConnect()
          .build(),
    );

    _socket.connect();

    _socket.onConnect((_) {
      if (!mounted) return;
      setState(() {
        _isSocketConnected = true;
      });
      debugPrint("🔌 [SOKET] Başarıyla bağlandı: ${_socket.id}");
    });

    _socket.onDisconnect((_) {
      if (!mounted) return;
      setState(() {
        _isSocketConnected = false;
      });
      debugPrint("❌ [SOKET] Bağlantı koptu.");
    });
  }

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
      setState(() {
        _isJsonLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hostNameController.dispose();
    _playerNameController.dispose();
    _roomCodeController.dispose();
    _impostorCountController.dispose();
    _socket
        .dispose(); // Bellek sızıntısı yapmasın diye soketi kapatıyoruz kanka[cite: 4]
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
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          ),
        ),
        child: Stack(
          children: [
            // ⬅️ ANA SAYFAYA DÖNÜŞ BUTONU (Sol Üstte Sabit)[cite: 4]
            Positioned(
              top: 20,
              left: 20,
              child: ElevatedButton.icon(
                onPressed: () {
                  html.window.location.href =
                      '/'; // Tarayıcıyı kök dizindeki launcher'a yollar[cite: 4]
                },
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                label: const Text(
                  'EĞİTİM MERKEZİNE DÖN',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16162E),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(
                      color: Color(0xFF00D2FF),
                      width: 1,
                    ), // Launcher neon rengi[cite: 4]
                  ),
                  elevation: 5,
                ),
              ),
            ),

            // 🎯 Orijinal Form Tasarımın (Aynen Korundu)
            Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: 80.0,
                    bottom: 16.0,
                    left: 16.0,
                    right: 16.0,
                  ), // Butona basılmasını kolaylaştırmak için üstten boşluk verdik
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 450),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0F1E).withOpacity(0.85),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white10, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 30),
                        // Bağlantı durumunu gösteren oyun simgesi[cite: 4]
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.videogame_asset_rounded,
                              size: 60,
                              color: _isSocketConnected
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'IMPOSTOR GAME',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),

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

                        _isJsonLoading
                            ? const Padding(
                                padding: EdgeInsets.all(40.0),
                                child: CircularProgressIndicator(
                                  color: Colors.redAccent,
                                ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildHostForm() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Theme(
        data: Theme.of(context).copyWith(canvasColor: const Color(0xFF1A1A2E)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _hostNameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'İsminiz (Öğretmen/Host)',
                labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Colors.redAccent,
                    width: 2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white10),
                ),
              ),
            ),
            const SizedBox(height: 16),

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
                        padding: const EdgeInsets.symmetric(
                          vertical: 28,
                          horizontal: 8,
                        ),
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
                                    color: Colors.redAccent.withValues(
                                      alpha: 0.2,
                                    ),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
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
                        padding: const EdgeInsets.symmetric(
                          vertical: 28,
                          horizontal: 8,
                        ),
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
                                    color: Colors.redAccent.withValues(
                                      alpha: 0.2,
                                    ),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
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
                  borderSide: const BorderSide(
                    color: Colors.redAccent,
                    width: 2,
                  ),
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
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Colors.redAccent,
                    width: 2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white10),
                ),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () {
                if (_hostNameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lütfen isminizi girin!')),
                  );
                  return;
                }

                int parsedImpostorCount =
                    int.tryParse(_impostorCountController.text.trim()) ?? 1;
                if (parsedImpostorCount < 1) parsedImpostorCount = 1;

                // 🔌 Soketi ve Host ismini HostScreen'e paslıyoruz!
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HostScreen(
                      gameMode: _selectedMod,
                      category: _selectedCategory,
                      impostorCount: parsedImpostorCount,
                      socket: _socket, // 🔌 Ekledik
                      hostName: _hostNameController.text
                          .trim(), // 🧑‍🏫 Ekledik
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 5,
              ),
              child: const Text(
                'ODA OLUŞTUR',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Colors.blueAccent,
                  width: 2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white10),
              ),
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
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Colors.blueAccent,
                  width: 2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white10),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              String pName = _playerNameController.text.trim();
              String rCode = _roomCodeController.text.trim().toUpperCase();

              if (pName.isEmpty || rCode.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Lütfen isim ve oda kodunu eksiksiz doldurun!',
                    ),
                  ),
                );
                return;
              }

              // 🔌 Soketi PlayerScreen'e paslıyoruz!
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PlayerScreen(
                    playerName: pName,
                    roomCode: rCode,
                    socket: _socket, // 🔌 Ekledik
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E2E5C),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: const BorderSide(color: Color(0xFF00D2FF), width: 1),
            ),
            child: const Text(
              'ODAYA KATIL',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 15,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
