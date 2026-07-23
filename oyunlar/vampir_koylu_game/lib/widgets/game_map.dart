import 'dart:math';
import 'package:flutter/material.dart';

import '../screens/entry_screen.dart';
import '../player_model.dart';

class GameMap extends StatelessWidget {
  final Size screenSize; // Telefon ekran boyutu
  final bool isNight;
  final GamePhase phase;
  final List<PlayerModel> players;
  final TransformationController transformationController;

  // Haritanın kendi gerçek, devasa boyutu (Telefon ekranından bağımsız)
  static const Size worldSize = Size(1800.0, 1200.0);

  const GameMap({
    super.key,
    required this.screenSize,
    required this.isNight,
    required this.phase,
    required this.players,
    required this.transformationController,
  });

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: transformationController,
      // constrained: false sayesinde harita ekrana sıkışmaz, kendi boyutunda (1800x1200) kalır.
      constrained: false, 
      minScale: 0.6,
      maxScale: 2.5,
      boundaryMargin: EdgeInsets.zero, // Sınırlarda esnek kaydırma payı
      child: SizedBox(
        width: worldSize.width,
        height: worldSize.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Arkaplan Görseli (Büzüşmeden, kendi boyutunda durur)
            Image.asset(
              'assets/images/arkaplan.png',
              fit: BoxFit.cover,
              width: worldSize.width,
              height: worldSize.height,
              errorBuilder: (_, __, ___) => Container(color: const Color(0xFF13132B)),
            ),
            
            // Gece Filtresi
            AnimatedOpacity(
              opacity: isNight ? 0.45 : 0.0,
              duration: const Duration(milliseconds: 800),
              child: Container(color: const Color(0xFF07071F).withOpacity(0.8)),
            ),
            
            // Evler ve Oyuncular
            _buildGameCanvas(),
          ],
        ),
      ),
    );
  }

  Widget _buildGameCanvas() {
    final cx = worldSize.width / 2;
    final cy = worldSize.height / 2 + 28;
    final inSquare = phase == GamePhase.dayDiscussion || phase == GamePhase.voting;

    return Stack(
      children: [
        for (int i = 0; i < players.length; i++)
          _buildPlayerSlot(
            player: players[i],
            index: i,
            total: players.length,
            cx: cx,
            cy: cy,
            inSquare: inSquare,
          ),
      ],
    );
  }

  Widget _buildPlayerSlot({
    required PlayerModel player,
    required int index,
    required int total,
    required double cx,
    required double cy,
    required bool inSquare,
  }) {
    final hx = player.posX ?? cx;
    final hy = player.posY ?? cy;
    final double houseWidth = player.isAlive ? 180.0 : 110.0;
    final double houseHeight = player.isAlive ? 150.0 : 90.0;

    final double tx;
    final double ty;

    if (inSquare && player.isAlive) {
      final spread = 70.0; // Geniş haritada meydan daha büyük durabilir
      final innerAngle = (2 * pi * index / total);
      tx = (cx - 30) + spread * cos(innerAngle) - 20;
      ty = cy + spread * sin(innerAngle) - 35;
    } else {
      tx = hx - 20;
      ty = hy + (houseHeight / 4) - (player.isAlive ? 5 : -5);
    }

    final String figureAsset = player.gender == Gender.female
        ? 'assets/images/k_kiz.png'
        : 'assets/images/k_erkek.png';

    return Stack(
      children: [
        Positioned(
          left: hx - (houseWidth / 2),
          top: hy - (houseHeight / 2),
          child: Image.asset(
            player.isAlive ? 'assets/images/ev_aktif.png' : 'assets/images/ev_yikik.png',
            width: houseWidth,
            height: houseHeight,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              player.isAlive ? Icons.home : Icons.gite_outlined,
              size: 50,
              color: player.isAlive ? player.avatarColor : Colors.grey,
            ),
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 1500),
          curve: Curves.easeInOutCubic,
          left: tx,
          top: ty,
          child: player.isAlive
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0A22).withOpacity(0.85),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: player.avatarColor.withOpacity(0.5)),
                      ),
                      child: Text(
                        player.name,
                        style: TextStyle(
                          color: player.avatarColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Image.asset(
                      figureAsset,
                      width: 32,
                      height: 36,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.person,
                        size: 24,
                        color: player.avatarColor,
                      ),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}