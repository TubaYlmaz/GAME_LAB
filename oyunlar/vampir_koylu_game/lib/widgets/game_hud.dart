import 'package:flutter/material.dart';
import '../screens/entry_screen.dart';
import '../player_model.dart';

class GameHud extends StatelessWidget {
  final Size screenSize;
  final int round;
  final GamePhase phase;
  final List<String> logs;
  final List<PlayerModel> players;
  final String? selectedVoteTargetId;
  final PlayerModel myPlayer;
  final bool hasVotedInCurrentRound; // Oy kullanıldı mı durumu

  final VoidCallback onShowRoleCard;
  final VoidCallback onShowDebugDialog;
  final ValueChanged<String?> onSelectPlayer;
  final VoidCallback onStartNight;
  final VoidCallback onStartDay;
  final VoidCallback onStartVoting;
  final VoidCallback onSubmitVote;

  const GameHud({
    super.key,
    required this.screenSize,
    required this.round,
    required this.phase,
    required this.logs,
    required this.players,
    required this.selectedVoteTargetId,
    required this.myPlayer,
    required this.hasVotedInCurrentRound,
    required this.onShowRoleCard,
    required this.onShowDebugDialog,
    required this.onSelectPlayer,
    required this.onStartNight,
    required this.onStartDay,
    required this.onStartVoting,
    required this.onSubmitVote,
  });

  String get _phaseText {
    switch (phase) {
      case GamePhase.night:
        return 'Gece 🌙';
      case GamePhase.dayDiscussion:
        return 'Gündüz ☀️';
      case GamePhase.voting:
        return 'Oylama 🗳️';
    }
  }

  List<PlayerModel> get _aliveTargets =>
      players.where((p) => p.isAlive && p.id != myPlayer.id).toList();

  void _showVoteTargetPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A0D22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Oylamak İstediğin Oyuncuyu Seç',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _aliveTargets.length,
                  itemBuilder: (context, index) {
                    final target = _aliveTargets[index];
                    final isSelected = target.id == selectedVoteTargetId;

                    return Card(
                      color: isSelected
                          ? const Color(0xFF00D2FF).withOpacity(0.2)
                          : const Color(0xFF13132B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFF00D2FF)
                              : Colors.transparent,
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: target.avatarColor,
                          child: Text(
                            target.name[0],
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          target.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle,
                                color: Color(0xFF00D2FF))
                            : null,
                        onTap: () {
                          onSelectPlayer(target.id);
                          Navigator.pop(ctx);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedPlayerName = players
        .firstWhere(
          (p) => p.id == selectedVoteTargetId,
          orElse: () => myPlayer,
        )
        .name;

    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12.0, left: 16.0, right: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                constraints: const BoxConstraints(maxWidth: 550),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0D22).withOpacity(0.92),
                  borderRadius: BorderRadius.circular(35),
                  border: Border.all(
                    color: const Color(0xFF00D2FF).withOpacity(0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // BİLGİ BARI
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildInfoChip(Icons.numbers, 'Tur $round', Colors.amber),
                        Container(width: 1, height: 14, color: Colors.white24),
                        _buildInfoChip(Icons.person_outline, myPlayer.role,
                            const Color(0xFF00D2FF)),
                        Container(width: 1, height: 14, color: Colors.white24),
                        _buildInfoChip(
                            Icons.timelapse, _phaseText, Colors.purpleAccent),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // AKSİYON VE İKON BARI
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.article_outlined,
                              color: Color(0xFF00D2FF), size: 28),
                          onPressed: onShowRoleCard,
                          tooltip: 'Rol Kartım',
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00D2FF),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                elevation: 4,
                              ),
                              onPressed: () {
                                if (phase == GamePhase.dayDiscussion) {
                                  if (round == 1) {
                                    onStartNight();
                                  } else {
                                    onStartVoting();
                                  }
                                } else if (phase == GamePhase.night) {
                                  onStartDay();
                                } else if (phase == GamePhase.voting) {
                                  if (hasVotedInCurrentRound) {
                                    // Oy verilmişse butona basınca GECEYE GEÇER!
                                    onStartNight();
                                  } else if (selectedVoteTargetId == null) {
                                    // Oy verilmemiş ve hedef seçilmemişse modal açar
                                    _showVoteTargetPicker(context);
                                  } else {
                                    // Oy verilir
                                    onSubmitVote();
                                  }
                                }
                              },
                              child: Text(
                                _getActionButtonText(selectedPlayerName),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            phase == GamePhase.voting
                                ? Icons.how_to_vote
                                : Icons.people_alt_outlined,
                            color: const Color(0xFF00D2FF),
                            size: 28,
                          ),
                          onPressed: () {
                            if (phase == GamePhase.voting) {
                              _showVoteTargetPicker(context);
                            } else {
                              onShowDebugDialog();
                            }
                          },
                          tooltip: phase == GamePhase.voting
                              ? 'Hedef Seç'
                              : 'Oyuncular & Debug',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getActionButtonText(String selectedPlayerName) {
    if (phase == GamePhase.dayDiscussion) {
      return round == 1 ? 'GECEYİ BAŞLAT 🌙' : 'OYLAMAYI BAŞLAT 🗳️';
    } else if (phase == GamePhase.night) {
      return 'GÜNDÜZÜ BAŞLAT ☀️';
    } else if (phase == GamePhase.voting) {
      if (hasVotedInCurrentRound) {
        return 'GECEYE GEÇ 🌙'; // Oylama bitti, yeni buton!
      } else if (selectedVoteTargetId != null) {
        return 'OYLA: $selectedPlayerName';
      }
      return 'HEDEF SEÇ / OYLA';
    }
    return '';
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}