import 'dart:math';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config.dart';
import 'lobby_screen.dart';

enum Gender { male, female }

class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  io.Socket? _socket;

  // Form Controller & State (Köy Kur)
  final TextEditingController _hostNameController = TextEditingController();
  Gender _hostGender = Gender.male;

  // Dinamik Rol Sayacı State'leri
  int _vampireCount = 2;
  int _doctorCount = 1;
  int _serialKillerCount = 1;
  int _villagerCount = 4;

  // Form Controller & State (Köye Katıl)
  final TextEditingController _joinNameController = TextEditingController();
  final TextEditingController _roomCodeController = TextEditingController();
  Gender _joinGender = Gender.female;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initSocket();
  }

  void _initSocket() {
    _socket = io.io(
      AppConfig.serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );
    _socket?.connect();

    _socket?.on('error_message', (data) {
      if (mounted) {
        _showError(data['message'] ?? 'Bir hata oluştu!');
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    final code = List.generate(
      6,
      (index) => chars[rand.nextInt(chars.length)],
    ).join();
    return 'VK-$code';
  }

  void _onCreateVillage() {
    if (_hostNameController.text.trim().isEmpty) {
      _showError('Lütfen kurucu ismini girin!');
      return;
    }

    final roomCode = _generateRoomCode();
    final hostName = _hostNameController.text.trim();

    // 🚀 Backend sunucusunda odayı kuruyoruz
    _socket?.emit('vk_create_room', {
      'roomCode': roomCode,
      'hostName': hostName,
      'gender': _hostGender.name,
      'vampireCount': _vampireCount,
      'doctorCount': _doctorCount,
      'serialKillerCount': _serialKillerCount,
      'villagerCount': _villagerCount,
    });

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LobbyScreen(
          roomCode: roomCode,
          playerName: hostName,
          gender: _hostGender,
          isHost: true,
          vampireCount: _vampireCount,
          doctorCount: _doctorCount,
          serialKillerCount: _serialKillerCount,
          villagerCount: _villagerCount,
        ),
      ),
    );
  }

  void _onJoinVillage() {
    if (_roomCodeController.text.trim().isEmpty) {
      _showError('Lütfen köy kodunu girin!');
      return;
    }
    if (_joinNameController.text.trim().isEmpty) {
      _showError('Lütfen isminizi girin!');
      return;
    }

    String cleanCode = _roomCodeController.text
        .trim()
        .toUpperCase()
        .replaceAll('VK-', '')
        .replaceAll('VK', '');
    
    final fullCode = 'VK-$cleanCode';
    final joinName = _joinNameController.text.trim();

    // 🚀 Backend sunucusunda var olan odaya katılıyoruz
    _socket?.emit('vk_join_room', {
      'roomCode': fullCode,
      'playerName': joinName,
      'gender': _joinGender.name,
    });

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LobbyScreen(
          roomCode: fullCode,
          playerName: joinName,
          gender: _joinGender,
          isHost: false,
          vampireCount: 2,
          doctorCount: 1,
          serialKillerCount: 1,
          villagerCount: 4,
        ),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFE74C3C),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          Image.asset(
            'assets/images/arkaplan.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) =>
                Container(color: const Color(0xFF13132B)),
          ),
          const _StarField(),
          Container(color: const Color(0xFF0D0D2A).withOpacity(0.75)),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '🩸 VAMPIRE VILLAGER 🐺',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF00D2FF),
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      shadows: [
                        Shadow(color: Color(0xFF00D2FF), blurRadius: 20),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Karanlık çöküyor... Köyünü kur veya savaşa katıl!',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 32),

                  Container(
                    width: min(size.width, 520),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A3E).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF00D2FF).withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          margin: const EdgeInsets.all(8),
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D2FF).withOpacity(0.05),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicatorSize: TabBarIndicatorSize.tab,
                            indicator: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: const Color(0xFF00D2FF).withOpacity(0.25),
                              border: Border.all(
                                color: const Color(0xFF00D2FF),
                                width: 1.5,
                              ),
                            ),
                            labelColor: const Color(0xFF00D2FF),
                            unselectedLabelColor: Colors.white54,
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            tabs: const [
                              Tab(text: '🏰 KÖY KUR'),
                              Tab(text: '⚔️ KÖYE KATIL'),
                            ],
                          ),
                        ),

                        SizedBox(
                          height: 500,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildCreateVillageForm(),
                              _buildJoinVillageForm(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateVillageForm() {
    final totalPlayersInVillage =
        _vampireCount + _doctorCount + _serialKillerCount + _villagerCount;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildTextField(
          controller: _hostNameController,
          label: 'Kurucu İsmi',
          icon: Icons.person,
          hint: 'Örn: Vlad',
        ),
        const SizedBox(height: 16),
        _buildGenderSelector(
          selected: _hostGender,
          onChanged: (g) => setState(() => _hostGender = g),
        ),
        const SizedBox(height: 20),
        const Divider(color: Color(0xFF00D2FF), height: 1, thickness: 0.3),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'ROLLER VE KÖY AYARLARI',
              style: TextStyle(
                color: Color(0xFF00D2FF),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            Text(
              'Toplam: $totalPlayersInVillage Kişi',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        _buildRoleCounter(
          title: '🧛 Vampir Sayısı:',
          count: _vampireCount,
          color: const Color(0xFFE74C3C),
          onDecrement: _vampireCount > 1
              ? () => setState(() => _vampireCount--)
              : null,
          onIncrement: () => setState(() => _vampireCount++),
        ),

        _buildRoleCounter(
          title: '🩺 Doktor Sayısı:',
          count: _doctorCount,
          color: const Color(0xFF2ECC71),
          onDecrement: _doctorCount > 0
              ? () => setState(() => _doctorCount--)
              : null,
          onIncrement: () => setState(() => _doctorCount++),
        ),

        _buildRoleCounter(
          title: '🔪 Seri Katil Sayısı:',
          count: _serialKillerCount,
          color: const Color(0xFF9B59B6),
          onDecrement: _serialKillerCount > 0
              ? () => setState(() => _serialKillerCount--)
              : null,
          onIncrement: () => setState(() => _serialKillerCount++),
        ),

        _buildRoleCounter(
          title: '🧑‍🌾 Köylü Sayısı:',
          count: _villagerCount,
          color: const Color(0xFFF1C40F),
          onDecrement: _villagerCount > 0
              ? () => setState(() => _villagerCount--)
              : null,
          onIncrement: () => setState(() => _villagerCount++),
        ),

        const SizedBox(height: 24),
        _NeonButton(
          label: 'KÖYÜ KUR VE ODAYI AÇ',
          icon: Icons.castle,
          color: const Color(0xFF00D2FF),
          large: true,
          onPressed: _onCreateVillage,
        ),
      ],
    );
  }

  Widget _buildRoleCounter({
    required String title,
    required int count,
    required Color color,
    required VoidCallback? onDecrement,
    required VoidCallback? onIncrement,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 14)),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                color: const Color(0xFFE74C3C),
                onPressed: onDecrement,
              ),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 20),
                color: const Color(0xFF2ECC71),
                onPressed: onIncrement,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJoinVillageForm() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 10),
        _buildTextField(
          controller: _roomCodeController,
          label: 'Köy Numarası (Oda Kodu)',
          icon: Icons.vpn_key,
          hint: 'Örn: 9A2X8M',
        ),
        const SizedBox(height: 20),
        _buildTextField(
          controller: _joinNameController,
          label: 'Oyuncu İsminiz',
          icon: Icons.badge,
          hint: 'İsminizi girin...',
        ),
        const SizedBox(height: 20),
        _buildGenderSelector(
          selected: _joinGender,
          onChanged: (g) => setState(() => _joinGender = g),
        ),
        const SizedBox(height: 40),
        _NeonButton(
          label: 'KÖYE KATIL',
          icon: Icons.login,
          color: const Color(0xFF9B59B6),
          large: true,
          onPressed: _onJoinVillage,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF8888BB), fontSize: 13),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
        prefixIcon: Icon(icon, color: const Color(0xFF00D2FF), size: 20),
        filled: true,
        fillColor: const Color(0xFF0D0D2A),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: const Color(0xFF00D2FF).withOpacity(0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00D2FF), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildGenderSelector({
    required Gender selected,
    required ValueChanged<Gender> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cinsiyet Seçimi',
          style: TextStyle(color: Color(0xFF8888BB), fontSize: 12),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(Gender.male),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected == Gender.male
                        ? const Color(0xFF00D2FF).withOpacity(0.2)
                        : const Color(0xFF0D0D2A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected == Gender.male
                          ? const Color(0xFF00D2FF)
                          : Colors.transparent,
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '👨 Erkek',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(Gender.female),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected == Gender.female
                        ? const Color(0xFFEC407A).withOpacity(0.2)
                        : const Color(0xFF0D0D2A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected == Gender.female
                          ? const Color(0xFFEC407A)
                          : Colors.transparent,
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '👩 Kadın',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StarField extends StatelessWidget {
  const _StarField();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _StarPainter(), child: const SizedBox.expand());
  }
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42);
    final paint = Paint()..color = Colors.white;
    for (int i = 0; i < 100; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 1.0 + 0.3;
      paint.color = Colors.white.withOpacity(rng.nextDouble() * 0.4 + 0.1);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _NeonButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final bool enabled;
  final bool large;

  const _NeonButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.enabled = true,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? color : color.withOpacity(0.25);
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: large ? 36 : 24,
          vertical: large ? 14 : 10,
        ),
        decoration: BoxDecoration(
          color: effectiveColor.withOpacity(enabled ? 0.12 : 0.05),
          borderRadius: BorderRadius.circular(large ? 14 : 10),
          border: Border.all(color: effectiveColor, width: large ? 1.5 : 1),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: effectiveColor.withOpacity(0.35),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: effectiveColor, size: large ? 18 : 15),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: effectiveColor,
                fontSize: large ? 14 : 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}