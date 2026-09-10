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
  bool _settingsExpanded = false;
  int _activeTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() => _activeTab = _tabController.index);
      }
    });
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
    _socket?.dispose();
    super.dispose();
  }

  String _generateRoomCode() {
    const chars = '1234567890';
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

  void _showHowToPlay() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xFF3A171F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0x99E7B5A2)),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 570,
            maxHeight: MediaQuery.sizeOf(dialogContext).height * .88,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.menu_book_rounded,
                      color: Color(0xFFE7B5A2),
                      size: 30,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'NASIL OYNANIR?',
                      style: TextStyle(
                        color: Color(0xFFFBE9E2),
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const _VkRuleCard(
                  icon: '🎯',
                  title: 'OYUNUN AMACI',
                  text:
                      'Köylüler konuşmaları ve oylamayı kullanarak köydeki bütün tehditleri bulmaya çalışır. Vampirler ve Seri Katil ise kimliklerini gizleyerek rakiplerini saf dışı bırakmayı amaçlar.',
                ),
                const _VkRuleCard(
                  icon: '🌙',
                  title: 'GECE AŞAMASI',
                  text:
                      'Vampirler birlikte bir hedef seçer. Doktor, Vampir saldırısından korumak istediği oyuncuyu belirler; kendisini koruyabilir ancak bunu iki gece üst üste yapamaz. Seri Katil ise tek başına ayrı bir hedef seçer. Gece seçimleri gizlidir.',
                ),
                const _VkRuleCard(
                  icon: '☀️',
                  title: 'GÜNDÜZ VE OYLAMA',
                  text:
                      'Gece sonucu açıklandıktan sonra hayatta kalan oyuncular konuşur ve şüphelendikleri kişiyi seçer. En çok oy alan oyuncu elenir ve yeni tur başlar.',
                ),
                const _VkRuleCard(
                  icon: '🧛',
                  title: 'VAMPİR',
                  text:
                      'Geceleri diğer Vampirlerle birlikte bir oyuncuyu hedef alır. Birden fazla Vampir varsa hepsinin aynı hedefte anlaşması gerekir. Gündüz kendini Köylü gibi göstererek kimliğini saklar. Vampirler, hayatta kalan diğer oyunculara sayıca eşit veya üstün olduğunda kazanır.',
                ),
                const _VkRuleCard(
                  icon: '🩺',
                  title: 'DOKTOR',
                  text:
                      'Her gece hayatta olan bir oyuncuyu Vampir saldırısından korur. Vampir ile Doktor aynı kişiyi seçerse saldırı engellenir ve o oyuncu hayatta kalır. Doktor kendisini de koruyabilir; ancak kendisini iki gece üst üste seçemez. Doktorun koruması Seri Katilin saldırısını engellemez.',
                ),
                const _VkRuleCard(
                  icon: '🔪',
                  title: 'SERİ KATİL',
                  text:
                      'Herhangi bir takıma bağlı değildir ve tek başına oynar. Her gece kendi hedefini seçer; saldırısı Doktorun korumasından etkilenmez. Gündüz şüphe çekmeden oylamada kalmaya çalışır. Oyunda kalan son tehdit olduğunda kazanır.',
                ),
                const _VkRuleCard(
                  icon: '🧑‍🌾',
                  title: 'KÖYLÜ',
                  text:
                      'Gece kimseye saldırmaz; kendisine verilen matematik görevini tamamlar. Gündüz konuşmaları, gece sonuçlarını ve oyuncuların davranışlarını değerlendirir. Vampirleri ve Seri Katili oylamayla eleyerek köyü kurtarmaya çalışır.',
                ),
                const _VkRuleCard(
                  icon: '🏆',
                  title: 'NASIL KAZANILIR?',
                  text:
                      'Köylüler bütün Vampirleri ve Seri Katili elerse kazanır. Vampirler diğer oyunculara sayıca üstün gelirse kazanır. Seri Katil son hayatta kalan tehdit olursa oyunu kazanır.',
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('ANLADIM'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE7B5A2),
                      foregroundColor: const Color(0xFF3A171F),
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
            errorBuilder: (_, _, _) =>
                Container(color: const Color(0xFF13132B)),
          ),
          Container(color: const Color(0xFF1A0E12).withValues(alpha: 0.78)),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'VAMPİR KÖYLÜ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFF5DED2),
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      shadows: [
                        Shadow(color: Color(0xFF8C3F3F), blurRadius: 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Köyünü savun, ipuçlarını takip et ve geceyi atlat.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 32),

                  Container(
                    width: min(size.width, 520),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A171F).withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFD6B58C).withValues(alpha: 0.55),
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
                            color: const Color(
                              0xFFF5DED2,
                            ).withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicatorSize: TabBarIndicatorSize.tab,
                            indicator: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: const Color(
                                0xFF7A2E3C,
                              ).withValues(alpha: 0.45),
                              border: Border.all(
                                color: const Color(0xFFE7B5A2),
                                width: 1.5,
                              ),
                            ),
                            labelColor: const Color(0xFFFBE9E2),
                            unselectedLabelColor: Colors.white54,
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            tabs: const [
                              Tab(text: 'KÖY KUR'),
                              Tab(text: 'KÖYE KATIL'),
                            ],
                          ),
                        ),

                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          height: _activeTab == 0
                              ? (_settingsExpanded ? 500 : 330)
                              : 360,
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
          Positioned(
            left: 18,
            bottom: 18,
            child: _InfoButton(onPressed: _showHowToPlay),
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
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _settingsExpanded = !_settingsExpanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFF52232D),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF8E5A60)),
            ),
            child: Row(
              children: [
                const Icon(Icons.tune, color: Color(0xFFE7B5A2), size: 19),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'OYUN AYARLARI',
                    style: TextStyle(
                      color: Color(0xFFFBE9E2),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Text(
                  '$totalPlayersInVillage oyuncu',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(width: 8),
                Icon(
                  _settingsExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white70,
                ),
              ],
            ),
          ),
        ),
        if (_settingsExpanded) ...[
          const SizedBox(height: 10),
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
        ],

        const SizedBox(height: 24),
        _NeonButton(
          label: 'KÖYÜ KUR',
          icon: Icons.castle,
          color: const Color(0xFFE7B5A2),
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
          Text(
            title,
            style: const TextStyle(fontSize: 14, color: Colors.white),
          ),
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
          label: 'Köy Kodu',
          icon: Icons.vpn_key,
          hint: 'Örn: VK-123456',
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
          color: const Color(0xFFC66A73),
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
        labelStyle: const TextStyle(color: Color(0xFFD7BFC1), fontSize: 13),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
        prefixIcon: Icon(icon, color: const Color(0xFFE7B5A2), size: 20),
        filled: true,
        fillColor: const Color(0xFF251015),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: const Color(0xFF8E5A60)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE7B5A2), width: 1.5),
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
          style: TextStyle(color: Color(0xFFD7BFC1), fontSize: 12),
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
                        ? const Color(0xFF6F3A3F)
                        : const Color(0xFF251015),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected == Gender.male
                          ? const Color(0xFFE7B5A2)
                          : Colors.transparent,
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '👨 Erkek',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
                onTap: () => onChanged(Gender.female),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected == Gender.female
                        ? const Color(0xFF7C4148)
                        : const Color(0xFF251015),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected == Gender.female
                          ? const Color(0xFFC66A73)
                          : Colors.transparent,
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '👩 Kadın',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
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
    this.large = false,
  }) : enabled = true;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? color : color.withValues(alpha: 0.25);
    final foregroundColor = enabled
        ? const Color(0xFFFFF4EF)
        : const Color(0xFFB99CA1);
    final radius = BorderRadius.circular(large ? 14 : 10);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      elevation: enabled ? 7 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.65),
      child: Ink(
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF8A4050), Color(0xFF632735)],
                )
              : null,
          color: enabled ? null : const Color(0xFF352126),
          borderRadius: radius,
          border: Border.all(color: effectiveColor, width: large ? 2 : 1.5),
        ),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: radius,
          splashColor: const Color(0xFFFBE9E2).withValues(alpha: 0.18),
          highlightColor: Colors.black.withValues(alpha: 0.12),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: large ? 36 : 24,
              vertical: large ? 15 : 11,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: foregroundColor, size: large ? 19 : 15),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: large ? 14 : 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _InfoButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Nasıl oynanır?',
      child: Material(
        color: const Color(0xFF3A171F),
        shape: const CircleBorder(
          side: BorderSide(color: Color(0xFFE7B5A2), width: 1.5),
        ),
        elevation: 8,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: const SizedBox(
            width: 52,
            height: 52,
            child: Icon(
              Icons.info_outline_rounded,
              color: Color(0xFFFBE9E2),
              size: 27,
            ),
          ),
        ),
      ),
    );
  }
}

class _VkRuleCard extends StatelessWidget {
  const _VkRuleCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  final String icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF4A2028),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0x33E7B5A2)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFE7B5A2),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  height: 1.4,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
