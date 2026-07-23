import 'dart:math';
import 'package:flutter/material.dart';
import '../screens/entry_screen.dart';
import '../player_model.dart';

class GameHud extends StatelessWidget {
  final Size screenSize;
  final String roomCode;
  final int round;
  final GamePhase phase;
  final List<String> logs;
  final List<PlayerModel> players;
  final String? selectedVoteTargetId;
  final VoidCallback onShowRoleCard;
  final VoidCallback onShowDebugDialog;
  final Function(String id) onSelectPlayer;
  final VoidCallback onStartDay;
  final VoidCallback onStartVoting;
  final VoidCallback onSubmitVote;

  const GameHud({
    super.key,
    required this.screenSize,
    required this.roomCode,
    required this.round,
    required this.phase,
    required this.logs,
    required this.players,
    required this.selectedVoteTargetId,
    required this.onShowRoleCard,
    required this.onShowDebugDialog,
    required this.onSelectPlayer,
    required this.onStartDay,
    required this.onStartVoting,
    required this.onSubmitVote,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(top: 0, left: 0, right: 0, child: _buildTopBar()),
        Positioned(left: 16, bottom: 16, child: _buildGameLog()),
        Positioned(right: 16, bottom: 16, child: _buildPlayerStatusPanel()),
        Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          child: _buildBottomControls(),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D2A).withOpacity(0.9),
        border: const Border(
          bottom: BorderSide(color: Color(0xFF00D2FF), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text(
            'KÖY: $roomCode',
            style: const TextStyle(
              color: Color(0xFF00D2FF),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.style, color: Color(0xFF00D2FF)),
            tooltip: 'Gizli Rolünü Gör',
            onPressed: onShowRoleCard,
          ),
          IconButton(
            icon: const Icon(
              Icons.bug_report_outlined,
              color: Colors.orangeAccent,
            ),
            tooltip: 'Algoritma Rol Çıktısı',
            onPressed: onShowDebugDialog,
          ),
          const SizedBox(width: 12),
          Text(
            'Tur $round',
            style: const TextStyle(color: Color(0xFF8888BB), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildGameLog() {
    final w = min(screenSize.width * 0.28, 340.0);
    return Container(
      width: w,
      height: 180,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A22).withOpacity(0.82),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00D2FF).withOpacity(0.3)),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: logs.length,
        reverse: true,
        itemBuilder: (_, i) => Text(
          logs[logs.length - 1 - i],
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildPlayerStatusPanel() {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A22).withOpacity(0.82),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00D2FF).withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: players.map((p) {
          final isSelected = selectedVoteTargetId == p.id;
          return GestureDetector(
            onTap: () {
              if (phase == GamePhase.voting && p.isAlive) {
                onSelectPlayer(p.id);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.redAccent.withOpacity(0.3)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: isSelected
                      ? Border.all(color: Colors.redAccent)
                      : null,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 4,
                      backgroundColor: p.isAlive ? p.avatarColor : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p.name,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.yellow
                              : (p.isAlive ? Colors.white : Colors.white30),
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (phase == GamePhase.night)
          ElevatedButton(
            onPressed: onStartDay,
            child: const Text('GÜNDÜZÜ BAŞLAT'),
          ),
        if (phase == GamePhase.dayDiscussion)
          ElevatedButton(
            onPressed: onStartVoting,
            child: const Text('OYLAMAYI BAŞLAT'),
          ),
        if (phase == GamePhase.voting)
          ElevatedButton(
            onPressed: selectedVoteTargetId != null ? onSubmitVote : null,
            child: Text(
              selectedVoteTargetId != null ? 'OYU GÖNDER' : 'KİŞİ SEÇİN',
            ),
          ),
      ],
    );
  }
}
