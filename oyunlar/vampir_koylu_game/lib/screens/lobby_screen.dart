import 'dart:math';
import 'package:flutter/material.dart';
import '../services/socket_service.dart';
import 'entry_screen.dart';
import 'game_screen.dart';
import '../widgets/role_reveal_card.dart';

class LobbyScreen extends StatefulWidget {
  final String roomCode;
  final String playerName;
  final Gender gender;
  final bool isHost;

  final int vampireCount;
  final int doctorCount;
  final int serialKillerCount;
  final int villagerCount;

  const LobbyScreen({
    super.key,
    required this.roomCode,
    required this.playerName,
    required this.gender,
    required this.isHost,
    required this.vampireCount,
    this.doctorCount = 1,
    this.serialKillerCount = 1,
    this.villagerCount = 4,
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  List<Map<String, dynamic>> _players = [];
  final SocketService _socketService = SocketService();
  bool _isGameStarting = false;
  bool _isStartRequestInFlight = false;
  late bool _isHost;
  late int _vampireCount;
  late int _doctorCount;
  late int _serialKillerCount;
  late int _villagerCount;

  // Lobi dönüş ve eşzamanlılık takip değişkenleri
  bool _isEveryoneBackToLobby = false;
  Set<String> _returnedPlayersSet = {};
  int _totalPlayersInRoom = 0;
  late String _currentRoomCode; // 🌟 Dinamik oda kodu yönetimi için

  String _myAssignedRole = "Vampir 🧛";
  String _myRoleDescription =
      "Geceleri diğer vampirlerle anlaşıp köylüleri avla. Gündüzleri kendini belli etme!";
  Color _myRoleColor = const Color(0xFFE74C3C);
  List<String> _myTeamMates = [];
  String _myTeamMatesLabel = 'EKİP ARKADAŞLARIN:';

  @override
  void initState() {
    super.initState();
    _currentRoomCode = widget.roomCode;
    _isHost = widget.isHost;
    _vampireCount = widget.vampireCount;
    _doctorCount = widget.doctorCount;
    _serialKillerCount = widget.serialKillerCount;
    _villagerCount = widget.villagerCount;
    _initSocket();
  }

  void _initSocket() {
    _socketService.currentRoomCode = _currentRoomCode;
    _socketService.connect();

    // Dinleyicileri temizleme
    _socketService.socket?.off('vk_players_updated');
    _socketService.socket?.off('vk_game_started');
    _socketService.socket?.off('vk_lobby_return_status');
    _socketService.socket?.off('vk_lobby_status_updated');
    _socketService.socket?.off('vk_start_game_error');
    _socketService.socket?.off('vk_redirect_to_new_room');
    _socketService.socket?.off('vk_host_changed');
    _socketService.socket?.off('vk_room_config_updated');
    _socketService.socket?.off('vk_room_config_error');
    _socketService.socket?.off('connect');

    // 1. Oyuncu Listesi Güncellendiğinde
    _socketService.socket?.on('vk_players_updated', (data) {
      if (mounted) {
        setState(() {
          _players = List<Map<String, dynamic>>.from(data);
          final myPlayer = _players.cast<Map<String, dynamic>>().firstWhere(
            (player) =>
                player['name']?.toString().trim().toLowerCase() ==
                widget.playerName.trim().toLowerCase(),
            orElse: () => <String, dynamic>{},
          );
          if (myPlayer.containsKey('isHost')) {
            _isHost = myPlayer['isHost'] == true;
          }
          _isEveryoneBackToLobby =
              _returnedPlayersSet.length >= _players.length;
        });
      }
    });

    // 2. Lobiye Dönen Oyuncuların Canlı Takibi
    _socketService.socket?.on('vk_lobby_status_updated', (data) {
      if (mounted && data != null) {
        final List returned = data['returnedPlayers'] ?? [];
        setState(() {
          _totalPlayersInRoom = data['totalPlayersCount'] ?? _players.length;
          _returnedPlayersSet = returned
              .map((e) => e.toString().trim().toLowerCase())
              .toSet();

          int targetCount = _players.isNotEmpty
              ? _players.length
              : _totalPlayersInRoom;
          _isEveryoneBackToLobby =
              targetCount > 0 && _returnedPlayersSet.length >= targetCount;
        });
      }
    });

    _socketService.socket?.on('vk_host_changed', (data) {
      if (!mounted || data is! Map || data['newHost'] == null) return;
      setState(() {
        _isHost = data['newHost'].toString().trim().toLowerCase() ==
            widget.playerName.trim().toLowerCase();
      });
    });

    _socketService.socket?.on('vk_room_config_updated', (data) {
      if (!mounted || data is! Map) return;
      setState(() {
        _vampireCount = int.tryParse('${data['vampireCount']}') ?? _vampireCount;
        _doctorCount = int.tryParse('${data['doctorCount']}') ?? _doctorCount;
        _serialKillerCount =
            int.tryParse('${data['serialKillerCount']}') ?? _serialKillerCount;
        _villagerCount = int.tryParse('${data['villagerCount']}') ?? _villagerCount;
      });
    });

    _socketService.socket?.on('vk_room_config_error', (data) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text((data is Map ? data['message'] : null) ?? 'Ayarlar güncellenemedi.'),
          backgroundColor: Colors.orange,
        ),
      );
    });

    // 🌟 3. YENİ ODA KODUNA OTOMATİK YÖNLENDİRME DİNLEYİCİSİ
    _socketService.socket?.on('vk_redirect_to_new_room', (data) {
      if (mounted && data != null && data['newRoomCode'] != null) {
        final String newCode = data['newRoomCode'];
        if (newCode != _currentRoomCode) {
          setState(() {
            _currentRoomCode = newCode;
            _socketService.currentRoomCode = newCode;
          });
          // Yeni odaya socket üzerinden resmi katılım sağla
          _socketService.socket?.emit('vk_join_room', {
            'roomCode': newCode,
            'playerName': widget.playerName,
            'gender': widget.gender.name,
          });
        }
      }
    });

    // 4. Oyun Başlatıldığında Rol Alma
    _socketService.socket?.on('vk_game_started', (data) {
      if (mounted) {
        if (data != null && data['players'] != null) {
          final List serverPlayers = data['players'];
          final myData = serverPlayers.firstWhere(
            (p) =>
                p['name'].toString().trim().toLowerCase() ==
                widget.playerName.trim().toLowerCase(),
            orElse: () => null,
          );

          if (myData != null) {
            final bool isVamp = myData['isVampire'] ?? false;
            final String myRole = (myData['role'] ?? '').toString().toLowerCase();
            String? teamRole;
            String teamLabel = 'EKİP ARKADAŞLARIN:';
            if (isVamp || myRole.contains('vampir')) {
              teamRole = 'vampir';
              teamLabel = 'DİĞER VAMPİRLER:';
            } else if (myRole.contains('doktor')) {
              teamRole = 'doktor';
              teamLabel = 'DİĞER DOKTORLAR:';
            } else if (myRole.contains('seri') || myRole.contains('katil')) {
              teamRole = 'seri';
              teamLabel = 'DİĞER SERİ KATİLLER:';
            }
            final List<String> teamMates = teamRole == null
                ? []
                : serverPlayers
                    .where((player) {
                      final role = (player['role'] ?? '')
                          .toString()
                          .toLowerCase();
                      final name = player['name']?.toString().trim().toLowerCase();
                      if (name == widget.playerName.trim().toLowerCase()) {
                        return false;
                      }
                      if (teamRole == 'vampir') return role.contains('vampir');
                      if (teamRole == 'doktor') return role.contains('doktor');
                      return role.contains('seri') || role.contains('katil');
                    })
                    .map((player) => player['name'].toString())
                    .toList();
            setState(() {
              _isHost = myData['isHost'] == true;
              _myAssignedRole =
                  myData['role'] ?? (isVamp ? 'Vampir 🧛' : 'Köylü 🧑‍🌾');
              _myRoleColor = isVamp
                  ? const Color(0xFFE74C3C)
                  : const Color(0xFF2ECC71);
              _myRoleDescription = isVamp
                  ? "Geceleri diğer vampirlerle anlaşıp köylüleri avla. Gündüzleri kendini belli etme!"
                  : "Köyünü koru, şüphelileri fark et ve gündüz oylamasında doğru kararı ver!";
              _myTeamMates = teamMates;
              _myTeamMatesLabel = teamLabel;
            });
          }
        }

        setState(() {
          _isGameStarting = true;
          _isStartRequestInFlight = false;
        });
      }
    });

    // 5. Herkes Dönmeden Başlatma Hatası
    _socketService.socket?.on('vk_start_game_error', (data) {
      if (mounted) {
        setState(() {
          _isStartRequestInFlight = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message'] ?? 'Tüm oyuncuların lobiye dönmesi bekleniyor! ⏳',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });

    void sendJoinRoomAndLobbyStatus() {
      _socketService.socket?.emit('vk_join_room', {
        'roomCode': _currentRoomCode,
        'playerName': widget.playerName,
        'gender': widget.gender.name,
      });

      _socketService.socket?.emit('vk_player_returned_to_lobby', {
        'roomCode': _currentRoomCode,
        'playerName': widget.playerName,
      });
    }

    if (_socketService.socket?.connected ?? false) {
      sendJoinRoomAndLobbyStatus();
      _socketService.socket?.emit('vk_get_players', {
        'roomCode': _currentRoomCode,
      });
    }

    _socketService.socket?.on('connect', (_) {
      sendJoinRoomAndLobbyStatus();
      _socketService.socket?.emit('vk_get_players', {
        'roomCode': _currentRoomCode,
      });
    });
  }

  @override
  void dispose() {
    _socketService.socket?.off('vk_players_updated');
    _socketService.socket?.off('vk_game_started');
    _socketService.socket?.off('vk_lobby_status_updated');
    _socketService.socket?.off('vk_lobby_return_status');
    _socketService.socket?.off('vk_start_game_error');
    _socketService.socket?.off('vk_redirect_to_new_room');
    _socketService.socket?.off('vk_host_changed');
    _socketService.socket?.off('vk_room_config_updated');
    _socketService.socket?.off('vk_room_config_error');
    super.dispose();
  }

  String _getAvatarAsset(Gender gender) {
    return gender == Gender.female
        ? 'assets/images/k_kiz.png'
        : 'assets/images/k_erkek.png';
  }

  void _navigateToGameScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(
          roomCode: _currentRoomCode,
          playerName: widget.playerName,
          gender: widget.gender,
          isHost: _isHost,
          vampireCount: _vampireCount,
          doctorCount: _doctorCount,
          serialKillerCount: _serialKillerCount,
          villagerCount: _villagerCount,
        ),
      ),
    );
  }

  void _startGame() {
    if (_isHost) {
      if (_isStartRequestInFlight) return;

      final bool canStart =
          _isEveryoneBackToLobby && _players.isNotEmpty;

      if (!canStart) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Tüm oyuncuların lobiye dönmesi bekleniyor!'),
            backgroundColor: Colors.amber,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      setState(() {
        _isStartRequestInFlight = true;
      });
      _socketService.socket?.emit('vk_start_game', {
        'roomCode': _currentRoomCode,
      });
    } else {
      setState(() {
        _isGameStarting = true;
      });
    }
  }

  void _saveRoleConfig() {
    _socketService.socket?.emit('vk_update_room_config', {
      'roomCode': _currentRoomCode,
      'vampireCount': _vampireCount,
      'doctorCount': _doctorCount,
      'serialKillerCount': _serialKillerCount,
      'villagerCount': _villagerCount,
    });
  }

  Widget _buildRoleCounter({
    required String label,
    required int value,
    required Color color,
    required VoidCallback? onDecrease,
    required VoidCallback onIncrease,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          IconButton(
            onPressed: onDecrease,
            icon: const Icon(Icons.remove_circle_outline),
            color: Colors.redAccent,
          ),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            onPressed: onIncrease,
            icon: const Icon(Icons.add_circle_outline),
            color: Colors.greenAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsDrawer() {
    final total =
        _vampireCount + _doctorCount + _serialKillerCount + _villagerCount;
    return Drawer(
      backgroundColor: const Color(0xFF121229),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune_rounded, color: Color(0xFF00D2FF)),
                  SizedBox(width: 10),
                  Text(
                    'YENİ OYUN AYARLARI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Seçilen rol dağılımı: $total kişi',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const Divider(color: Colors.white24, height: 28),
              _buildRoleCounter(
                label: '🧛 Vampir',
                value: _vampireCount,
                color: Colors.redAccent,
                onDecrease: _vampireCount > 1
                    ? () => setState(() => _vampireCount--)
                    : null,
                onIncrease: () => setState(() => _vampireCount++),
              ),
              _buildRoleCounter(
                label: '🩺 Doktor',
                value: _doctorCount,
                color: Colors.greenAccent,
                onDecrease: _doctorCount > 0
                    ? () => setState(() => _doctorCount--)
                    : null,
                onIncrease: () => setState(() => _doctorCount++),
              ),
              _buildRoleCounter(
                label: '🔪 Seri Katil',
                value: _serialKillerCount,
                color: Colors.purpleAccent,
                onDecrease: _serialKillerCount > 0
                    ? () => setState(() => _serialKillerCount--)
                    : null,
                onIncrease: () => setState(() => _serialKillerCount++),
              ),
              _buildRoleCounter(
                label: '🧑‍🌾 Köylü',
                value: _villagerCount,
                color: Colors.amberAccent,
                onDecrease: _villagerCount > 0
                    ? () => setState(() => _villagerCount--)
                    : null,
                onIncrease: () => setState(() => _villagerCount++),
              ),
              const Spacer(),
              _NeonButton(
                label: 'AYARLARI KAYDET',
                icon: Icons.save_rounded,
                color: const Color(0xFF00D2FF),
                large: true,
                onPressed: () {
                  _saveRoleConfig();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: _isHost ? _buildSettingsDrawer() : null,
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

          if (!_isGameStarting)
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Spacer(),
                        if (_isHost)
                          Builder(
                            builder: (drawerContext) => IconButton(
                              icon: const Icon(
                                Icons.tune_rounded,
                                color: Color(0xFF00D2FF),
                              ),
                              tooltip: 'Yeni oyun ayarları',
                              onPressed: () => Scaffold.of(drawerContext).openEndDrawer(),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 24,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A3E).withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF00D2FF).withOpacity(0.4),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'KÖYLÜLER İÇİN ODA KODU',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _currentRoomCode,
                                  style: const TextStyle(
                                    color: Color(0xFF00D2FF),
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Katılan Oyuncular',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF00D2FF,
                                  ).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF00D2FF,
                                    ).withOpacity(0.5),
                                  ),
                                ),
                                child: Text(
                                  '${_players.length} Oyuncu',
                                  style: const TextStyle(
                                    color: Color(0xFF00D2FF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _players.length,
                            itemBuilder: (context, index) {
                              final player = _players[index];
                              final String pName = player['name'] ?? 'Oyuncu';
                              final bool isHostPlayer =
                                  player['isHost'] ?? false;
                              final Gender pGender = player['gender'] is Gender
                                  ? player['gender']
                                  : (player['gender'] == 'female'
                                        ? Gender.female
                                        : Gender.male);
                              final String avatarPath = _getAvatarAsset(
                                pGender,
                              );

                              final bool isReturned = _returnedPlayersSet
                                  .contains(pName.trim().toLowerCase());

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF1A1A3E,
                                  ).withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isReturned
                                        ? const Color(
                                            0xFF00FF88,
                                          ).withOpacity(0.4)
                                        : const Color(
                                            0xFFFFB300,
                                          ).withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isReturned
                                              ? const Color(0xFF00FF88)
                                              : const Color(0xFFFFB300),
                                          width: 1.5,
                                        ),
                                        image: DecorationImage(
                                          image: AssetImage(avatarPath),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      pName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (isHostPlayer) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF00D2FF,
                                          ).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFF00D2FF),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: const Text(
                                          'MUHTAR',
                                          style: TextStyle(
                                            color: Color(0xFF00D2FF),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const Spacer(),

                                    if (isReturned)
                                      const Row(
                                        children: [
                                          Text(
                                            "LOBİDE ",
                                            style: TextStyle(
                                              color: Color(0xFF00FF88),
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Icon(
                                            Icons.check_circle_rounded,
                                            color: Color(0xFF00FF88),
                                            size: 20,
                                          ),
                                        ],
                                      )
                                    else
                                      const Row(
                                        children: [
                                          Text(
                                            "BEKLENİYOR ",
                                            style: TextStyle(
                                              color: Color(0xFFFFB300),
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Icon(
                                            Icons.hourglass_top_rounded,
                                            color: Color(0xFFFFB300),
                                            size: 18,
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: _NeonButton(
                      label: _isHost
                          ? ((_isEveryoneBackToLobby && _players.isNotEmpty)
                                ? 'YENİ OYUNU BAŞLAT 🚀'
                                : 'OYUNCULARIN LOBİYE DÖNMESİ BEKLENİYOR...')
                          : 'MUHTAR BEKLENİYOR...',
                      icon: Icons.play_arrow_rounded,
                      color: const Color(0xFF00D2FF),
                      enabled:
                          _isHost &&
                          _isEveryoneBackToLobby &&
                          _players.isNotEmpty &&
                          !_isStartRequestInFlight,
                      large: true,
                      onPressed: _startGame,
                    ),
                  ),
                ],
              ),
            ),

          if (_isGameStarting)
            Center(
              child: RoleRevealCard(
                roleName: _myAssignedRole,
                roleDescription: _myRoleDescription,
                roleColor: _myRoleColor,
                teamMates: _myTeamMates,
                teamMatesLabel: _myTeamMatesLabel,
                onDismiss: _navigateToGameScreen,
              ),
            ),
        ],
      ),
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
  final VoidCallback? onPressed;
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        child: Ink(
          decoration: BoxDecoration(
            color: effectiveColor.withOpacity(enabled ? 0.18 : 0.05),
            borderRadius: BorderRadius.circular(large ? 14 : 10),
            border: Border.all(color: effectiveColor, width: large ? 1.5 : 1),
          ),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: large ? 16 : 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: effectiveColor, size: large ? 20 : 16),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: effectiveColor,
                    fontSize: large ? 15 : 13,
                    fontWeight: FontWeight.bold,
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
