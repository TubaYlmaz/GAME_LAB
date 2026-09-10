// lib/screens/host_login_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:socket_io_client/socket_io_client.dart'
    as io; // 🔌 Soket kütüphanesini ekledik[cite: 4]
import '../config.dart'; // ⚙️ Config dosyamızı çektik[cite: 4]
import 'host_screen.dart'; //[cite: 4]
import 'player_screen.dart'; //[cite: 4]

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

  late io.Socket _socket; // 🔌 Canlı soket değişkenimiz[cite: 4]
  bool _isSocketConnected = false;

  String _selectedMod = 'Klasik';
  String _selectedCategory = 'Rastgele';

  final TextEditingController _impostorCountController = TextEditingController(
    text: '1',
  );

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
    _socket = io.io(
      AppConfig.serverUrl,
      io.OptionBuilder()
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
        _kategoriler = ['Rastgele', ...data.keys];
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

  void _showHowToPlay() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xFF21191B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0x99E08A6D)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.person_search_rounded,
                      color: Color(0xFFE08A6D),
                      size: 30,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'NASIL OYNANIR?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildInfoSection(
                  Icons.flag_rounded,
                  'Oyunun amacı',
                  'Oyuncular aynı gizli kelime hakkında sırayla ipucu verir. '
                      'Impostor ise kelimeyi bilmeden kendini belli etmemeye çalışır.',
                ),
                _buildInfoSection(
                  Icons.forum_rounded,
                  'Oyun nasıl ilerler?',
                  'Herkes kelimeyi doğrudan söylemeden kısa bir ipucu verir. '
                      'İpuçları tamamlandığında şüpheli oyuncular değerlendirilir ve oylama yapılır.',
                ),
                _buildInfoSection(
                  Icons.groups_rounded,
                  'Oyuncular nasıl kazanır?',
                  'Oyuncular doğru Impostor’u oylamada bulup oyundan çıkarırsa kazanır.',
                ),
                _buildInfoSection(
                  Icons.visibility_off_rounded,
                  'Impostor nasıl kazanır?',
                  'Impostor, ipuçlarından gizli kelimeyi anlamaya ve yakalanmamaya çalışır. '
                      'Sonuna kadar fark edilmezse kazanır.',
                  isLast: true,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('ANLADIM'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE08A6D),
                      foregroundColor: const Color(0xFF21191B),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: .7,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(
    IconData icon,
    String title,
    String description, {
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF302427),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFFE08A6D), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
            colors: [Color(0xFF33272A), Color(0xFF241C1E), Color(0xFF171315)],
          ),
        ),
        child: Stack(
          children: [
            // 🎯 Orijinal Form Tasarımın (Aynen Korundu)
            Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: 28.0,
                    bottom: 24.0,
                    left: 16.0,
                    right: 16.0,
                  ), // Butona basılmasını kolaylaştırmak için üstten boşluk verdik
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 520),
                    decoration: BoxDecoration(
                      color: const Color(0xFF21191B).withValues(alpha: 0.85),
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
                        const SizedBox(height: 20),
                        // Oyunun kimlik simgesi; bağlantı sorunu varsa rengi değişir.
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_search_rounded,
                              size: 46,
                              color: _isSocketConnected
                                  ? const Color(0xFFE08A6D)
                                  : Colors.redAccent,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'IMPOSTOR',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),

                        TabBar(
                          controller: _tabController,
                          indicatorColor: Colors.redAccent,
                          labelColor: Colors.redAccent,
                          unselectedLabelColor: Colors.grey,
                          indicatorWeight: 3,
                          tabs: const [
                            Tab(text: 'ODA KUR'),
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
                            : SizedBox(
                                width: double.infinity,
                                child: AnimatedBuilder(
                                  animation: _tabController,
                                  builder: (context, child) {
                                    return AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      child: _tabController.index == 0
                                          ? KeyedSubtree(
                                              key: const ValueKey('host-form'),
                                              child: _buildHostForm(),
                                            )
                                          : KeyedSubtree(
                                              key: const ValueKey('join-form'),
                                              child: _buildJoinForm(),
                                            ),
                                    );
                                  },
                                ),
                              ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 18,
              bottom: 18,
              child: SafeArea(
                child: Tooltip(
                  message: 'Nasıl oynanır?',
                  child: Material(
                    color: const Color(0xFF21191B),
                    shape: const CircleBorder(
                      side: BorderSide(color: Color(0xFFE08A6D), width: 1.5),
                    ),
                    elevation: 6,
                    child: IconButton(
                      onPressed: _showHowToPlay,
                      icon: const Icon(Icons.info_outline_rounded),
                      color: const Color(0xFFE08A6D),
                      iconSize: 25,
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
      padding: const EdgeInsets.all(20.0),
      child: Theme(
        data: Theme.of(context).copyWith(canvasColor: const Color(0xFF302427)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _hostNameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Kurucu adı',
                labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                filled: true,
                fillColor: const Color(0xFF302427),
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
            const SizedBox(height: 12),

            const Text(
              'Oyun modu',
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
                        height: 92,
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedMod == 'Klasik'
                              ? const Color(0xFF302427)
                              : const Color(0xFF281E21),
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
                              size: 18,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Klasik',
                              style: TextStyle(
                                color: _selectedMod == 'Klasik'
                                    ? Colors.white
                                    : Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Kelimeyi görmez',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _selectedMod == 'Klasik'
                                    ? Colors.white70
                                    : Colors.grey,
                                fontSize: 10,
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
                        height: 92,
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedMod == 'Yakin Kelime'
                              ? const Color(0xFF302427)
                              : const Color(0xFF281E21),
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
                              size: 18,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Yakın Kelime',
                              style: TextStyle(
                                color: _selectedMod == 'Yakin Kelime'
                                    ? Colors.white
                                    : Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Yakın bir kelime görür',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _selectedMod == 'Yakin Kelime'
                                    ? Colors.white70
                                    : Colors.grey,
                                fontSize: 10,
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
            const SizedBox(height: 12),

            const Text(
              'Kategori',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),

            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              dropdownColor: const Color(0xFF302427),
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF302427),
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
            const SizedBox(height: 12),

            const Text(
              'Impostor sayısı',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _impostorCountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF302427),
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
                'ODAYI KUR',
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
      padding: const EdgeInsets.all(20.0),
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
              fillColor: const Color(0xFF302427),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFE08A6D),
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
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: '6 haneli oda kodu',
              labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              filled: true,
              fillColor: const Color(0xFF302427),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFE08A6D),
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
              backgroundColor: const Color(0xFF584047),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: const BorderSide(color: Color(0xFFE08A6D), width: 1),
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
