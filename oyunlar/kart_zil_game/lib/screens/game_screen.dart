import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/game_state_model.dart';
import '../models/player_model.dart';
import '../services/socket_service.dart';
import '../utils/site_navigation.dart';
import '../widgets/bell_button.dart';
import '../widgets/countdown_timer.dart';
import '../widgets/game_logo.dart';
import '../widgets/playing_card.dart';

class KzGameScreen extends StatelessWidget {
  const KzGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = KzSocketService.instance;
    final state = service.state!;
    final me = state.players.where((p) => p.id == service.playerId).firstOrNull;
    final isMobile = MediaQuery.sizeOf(context).width < 650;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 66,
        centerTitle: true,
        leadingWidth: 58,
        flexibleSpace: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF34456F),
                    Color(0xFF534B7D),
                    Color(0xFF355F78),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 64,
              top: 17,
              child: _GameInfoBadges(state: state, compact: isMobile),
            ),
          ],
        ),
        leading: Padding(
          padding: const EdgeInsets.fromLTRB(7, 9, 3, 9),
          child: IconButton.filledTonal(
            tooltip: 'Oyunlara dön',
            style: IconButton.styleFrom(
              foregroundColor: const Color(0xFF9CE5E3),
              backgroundColor: const Color(0x334EC7C4),
              side: const BorderSide(color: Color(0x9965C6C4)),
            ),
            onPressed: () => _goToGames(service),
            icon: const Icon(Icons.grid_view_rounded),
          ),
        ),
        title: KzGameLogo(
          width: isMobile ? 90 : 112,
          height: isMobile ? 44 : 52,
        ),
        actions: [
          if (me?.isHost == true)
            IconButton.filledTonal(
              tooltip: 'Oyunu durdur',
              style: IconButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF9B73D1),
              ),
              onPressed: () => _confirmStop(context, service),
              icon: const Icon(Icons.stop_circle_outlined),
            ),
          const SizedBox(width: 6),
          IconButton.filled(
            tooltip: 'Oyundan çık',
            style: IconButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF9B73D1),
            ),
            onPressed: service.leave,
            icon: const Icon(Icons.logout),
          ),
          SizedBox(width: isMobile ? 6 : 12),
        ],
      ),
      body: _RoundTable(state: state, service: service, me: me),
    );
  }

  Future<void> _goToGames(KzSocketService service) async {
    await service.leave();
    goToGamesPage();
  }

  Future<void> _confirmStop(
    BuildContext context,
    KzSocketService service,
  ) async {
    final stop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Oyunu durdur?'),
        content: const Text('Tur bitecek ve herkes lobiye dönecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('VAZGEÇ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DURDUR'),
          ),
        ],
      ),
    );
    if (stop == true) service.stopGame();
  }
}

class _GameInfoBadges extends StatelessWidget {
  const _GameInfoBadges({required this.state, required this.compact});

  final KzGameState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _InfoBadge(
        icon: Icons.auto_awesome,
        text: 'T${state.roundNumber} • ${state.roomCode}',
        color: const Color(0xFF65C6C4),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _InfoBadge(
          icon: Icons.auto_awesome,
          text: 'TUR ${state.roundNumber}',
          color: const Color(0xFF65C6C4),
        ),
        const SizedBox(width: 6),
        _InfoBadge(
          icon: Icons.meeting_room_outlined,
          text: state.roomCode,
          color: const Color(0xFFE58BC1),
        ),
      ],
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .18),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: color.withValues(alpha: .8)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}

class _RoundTable extends StatelessWidget {
  const _RoundTable({
    required this.state,
    required this.service,
    required this.me,
  });

  final KzGameState state;
  final KzSocketService service;
  final KzPlayer? me;

  @override
  Widget build(BuildContext context) {
    final myTurn =
        state.currentPlayerId == service.playerId && me?.eliminated != true;
    final mustDiscard = myTurn && state.myCards.length == 5;
    final bellLocked = state.bellPlayerId == service.playerId;
    final canDraw = myTurn && !mustDiscard && !bellLocked;
    final canRing =
        myTurn &&
        state.phase == 'playing' &&
        me?.eliminated == false &&
        !state.bellPressed &&
        state.myCards.length == 4;
    final activeName = state.players
        .where((p) => p.id == state.currentPlayerId)
        .firstOrNull
        ?.name;
    final bellName = state.players
        .where((p) => p.id == state.bellPlayerId)
        .firstOrNull
        ?.name;
    final mySeatIndex = state.players.indexWhere(
      (player) => player.id == service.playerId,
    );
    final seatedPlayers = mySeatIndex < 0
        ? state.players
        : [
            ...state.players.sublist(mySeatIndex),
            ...state.players.sublist(0, mySeatIndex),
          ];

    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.1,
          colors: [Color(0xFF667EA2), Color(0xFF293451)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, bounds) {
          final width = bounds.maxWidth;
          final height = bounds.maxHeight;
          final isMobile = width < 600;
          final tableWidth = math.min(width * (isMobile ? .78 : .74), 760.0);
          final tableHeight = math.min(height * (isMobile ? .48 : .57), 500.0);
          final left = (width - tableWidth) / 2;
          final top = math.max(
            state.gameMode == 'team' ? 70.0 : 38.0,
            (height - tableHeight) / 2 - 68,
          );
          return Stack(
            clipBehavior: Clip.none,
            children: [
              const Positioned.fill(child: _GameFlyingCards()),
              if (state.bellPressed)
                const Positioned.fill(child: _SirenBackdrop()),
              Positioned(
                left: left,
                top: top,
                width: tableWidth,
                height: tableHeight,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(isMobile ? 48 : 90),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF8EB7C9), Color(0xFF667CAD)],
                    ),
                    border: Border.all(
                      color: const Color(0xFFD9D5F4),
                      width: isMobile ? 5 : 8,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 30,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
              if (state.bellPressed)
                Positioned(
                  top: 8,
                  left: isMobile ? 8 : 16,
                  right: isMobile ? 8 : math.max(16, width - 486),
                  child: _BellAlert(
                    text: '🔔 ZİL ÇALDI • ${bellName ?? '-'} • SON HAMLE',
                  ),
                ),
              Positioned(
                bottom: isMobile ? 8 : 18,
                right: isMobile ? 8 : 18,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF28163F), Color(0xFFE5484D)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white70, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Color(0x88E5484D), blurRadius: 20),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined, size: 24),
                      const SizedBox(width: 7),
                      KzCountdown(
                        deadline: state.turnDeadline,
                        serverTime: state.serverTime,
                      ),
                    ],
                  ),
                ),
              ),
              if (!state.bellPressed)
                Positioned(
                  top: 10,
                  left: 16,
                  right: 16,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      key: ValueKey('${state.currentPlayerId}-$mustDiscard'),
                      myTurn
                          ? (mustDiscard
                                ? 'Bir kart seçip masaya bırak'
                                : 'Sıra sende • Kart çek veya zile bas')
                          : 'Sıra: ${activeName ?? '-'}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              if (state.gameMode == 'team' && state.teams.isNotEmpty)
                Positioned(
                  top: top + (tableHeight / 2) - (isMobile ? 118 : 142),
                  left: 0,
                  right: 0,
                  child: _TeamLivesStrip(teams: state.teams, compact: isMobile),
                ),
              Positioned(
                left: left + (tableWidth / 2) - 100,
                top: top + (tableHeight / 2) - (isMobile ? 58 : 70),
                width: 200,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: canDraw ? service.drawDeck : null,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: isMobile ? 64 : 80,
                        height: isMobile ? 94 : 116,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF20294C),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white54, width: 2),
                          boxShadow: const [BoxShadow(blurRadius: 12)],
                        ),
                        child: Text(
                          'KAPALI\n${state.deckCount}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    if (state.openCard != null)
                      KzPlayingCard(
                        card: state.openCard!,
                        large: !isMobile,
                        onTap: canDraw ? service.takeOpenCard : null,
                      )
                    else
                      const SizedBox(width: 68, height: 98),
                  ],
                ),
              ),
              for (var index = 0; index < seatedPlayers.length; index++)
                _seat(
                  player: seatedPlayers[index],
                  isMe: seatedPlayers[index].id == service.playerId,
                  index: index,
                  total: seatedPlayers.length,
                  tableLeft: left,
                  tableTop: top,
                  tableWidth: tableWidth,
                  tableHeight: tableHeight,
                  isMobile: isMobile,
                  spectatorView: me?.eliminated == true,
                ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 2,
                child: me?.eliminated == true
                    ? const SizedBox.shrink()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (state.myCards.isNotEmpty)
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Chip(
                                key: ValueKey(state.myScore),
                                avatar: const Icon(Icons.auto_graph, size: 18),
                                label: Text(
                                  'EL PUANIN: ${state.myScore}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: state.myCards
                                  .map(
                                    (card) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                      ),
                                      child: KzPlayingCard(
                                        card: card,
                                        compact: isMobile,
                                        onTap: mustDiscard
                                            ? () => service.discard(card.id)
                                            : null,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          KzBellButton(
                            enabled: canRing,
                            onPressed: service.pressBell,
                          ),
                          if (service.error != null)
                            Text(
                              service.error!,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _seat({
    required KzPlayer player,
    required bool isMe,
    required int index,
    required int total,
    required double tableLeft,
    required double tableTop,
    required double tableWidth,
    required double tableHeight,
    required bool isMobile,
    required bool spectatorView,
  }) {
    final seatWidth = isMobile ? 88.0 : 150.0;
    final seatHeight = isMobile ? 46.0 : 66.0;
    final angle = (math.pi / 2) + ((2 * math.pi * index) / total);
    final centerX = tableLeft + tableWidth / 2;
    final centerY = tableTop + tableHeight / 2;
    final x = centerX + math.cos(angle) * (tableWidth * .48) - seatWidth / 2;
    final verticalRadius = tableHeight * (isMe ? .34 : .48);
    final y = centerY + math.sin(angle) * verticalRadius - seatHeight / 2;
    final active = player.id == state.currentPlayerId;
    final visibleLives = player.lives.clamp(0, 3);
    final hearts = '${'♥' * visibleLives}${'♡' * (3 - visibleLives)}';
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      left: x,
      top: y,
      width: seatWidth,
      height: seatHeight,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        padding: EdgeInsets.all(isMobile ? 3 : 6),
        decoration: BoxDecoration(
          color: player.eliminated
              ? const Color(0xFF555A70)
              : (active
                    ? const Color(0xFFFFD166)
                    : player.teamId == 'blue'
                    ? const Color(0xFF496FA8)
                    : player.teamId == 'purple'
                    ? const Color(0xFF765A9C)
                    : const Color(0xFF303A5C)),
          borderRadius: BorderRadius.circular(34),
          border: Border.all(
            color: player.eliminated
                ? const Color(0xFFE08A94)
                : active
                ? Colors.white
                : (isMe ? const Color(0xFF64D8CB) : Colors.white24),
            width: active || isMe ? 3 : 1,
          ),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0xAAFFB000),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ]
              : const [],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: isMobile ? 13 : 20,
                  backgroundColor: active
                      ? Colors.black87
                      : const Color(0xFF2B3357),
                  child: Text(
                    player.eliminated
                        ? '💀'
                        : (player.name.isEmpty
                              ? '?'
                              : player.name[0].toUpperCase()),
                  ),
                ),
                SizedBox(width: isMobile ? 3 : 6),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              player.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: active ? Colors.black : Colors.white,
                                fontSize: isMobile ? 10 : 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (_canSeeTeamScore(player)) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 4 : 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: active
                                    ? Colors.black12
                                    : Colors.white.withValues(alpha: .16),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(
                                '${player.score}',
                                style: TextStyle(
                                  color: active ? Colors.black : Colors.white,
                                  fontSize: isMobile ? 8 : 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                          if (state.gameMode == 'team') ...[
                            const SizedBox(width: 4),
                            Text(
                              player.teamId == 'blue' ? '🔵' : '🟣',
                              style: TextStyle(
                                color: active
                                    ? Colors.black87
                                    : Colors.redAccent,
                                fontSize: isMobile ? 8 : 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (player.eliminated)
                        Text(
                          'ELENDİ 💀',
                          maxLines: 1,
                          style: TextStyle(
                            color: active ? Colors.black54 : Colors.white60,
                            fontSize: isMobile ? 8 : 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      if (!player.eliminated && state.gameMode != 'team')
                        Text(
                          hearts,
                          maxLines: 1,
                          style: TextStyle(
                            color: active
                                ? const Color(0xFFD62839)
                                : const Color(0xFFFF5B68),
                            fontSize: isMobile ? 9 : 13,
                            height: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (player.eliminated)
              Positioned(
                top: isMobile ? -25 : -34,
                left: 0,
                right: 0,
                child: Text(
                  '💀',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: isMobile ? 25 : 34),
                ),
              ),
            if (spectatorView && !player.eliminated && player.cards.isNotEmpty)
              Positioned(
                top: seatHeight + 4,
                left: isMobile ? -12 : 2,
                child: _SeatHand(player: player),
              ),
          ],
        ),
      ),
    );
  }

  bool _canSeeTeamScore(KzPlayer player) =>
      state.gameMode == 'team' &&
      me?.teamId != null &&
      me?.teamId == player.teamId &&
      player.score != null &&
      !player.eliminated;
}

class _TeamLivesStrip extends StatelessWidget {
  const _TeamLivesStrip({required this.teams, required this.compact});

  final List<KzTeam> teams;
  final bool compact;

  @override
  Widget build(BuildContext context) => Center(
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 14,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xE62D3658),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white70, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < teams.length; index++) ...[
            if (index > 0)
              Container(
                width: 1,
                height: compact ? 28 : 34,
                margin: EdgeInsets.symmetric(horizontal: compact ? 9 : 14),
                color: Colors.white38,
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  teams[index].id == 'blue' ? '🔵 MAVİ' : '🟣 MOR',
                  style: TextStyle(
                    fontSize: compact ? 10 : 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '❤️ ${teams[index].lives} CAN',
                  style: TextStyle(
                    color: const Color(0xFFFFD2D8),
                    fontSize: compact ? 12 : 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

class _SeatHand extends StatelessWidget {
  const _SeatHand({required this.player});

  final KzPlayer player;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(4, 2, 3, 3),
    decoration: BoxDecoration(
      color: const Color(0xE6333D60),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white54),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${player.score ?? 0} PUAN',
          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 1),
        Row(
          children: player.cards
              .map(
                (card) => Padding(
                  padding: const EdgeInsets.only(right: 1),
                  child: KzPlayingCard(card: card, mini: true),
                ),
              )
              .toList(),
        ),
      ],
    ),
  );
}

class _BellAlert extends StatefulWidget {
  const _BellAlert({required this.text});

  final String text;

  @override
  State<_BellAlert> createState() => _BellAlertState();
}

class _SirenBackdrop extends StatefulWidget {
  const _SirenBackdrop();

  @override
  State<_SirenBackdrop> createState() => _SirenBackdropState();
}

class _SirenBackdropState extends State<_SirenBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController pulse;

  @override
  void initState() {
    super.initState();
    pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final strength = .28 + (pulse.value * .38);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              stops: const [0, .28, .68, 1],
              colors: [
                const Color(0xFFFF102A).withValues(alpha: strength),
                const Color(0xFFFF263D).withValues(alpha: strength * .72),
                const Color(0xFFE00024).withValues(alpha: strength * .24),
                Colors.transparent,
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _BellAlertState extends State<_BellAlert>
    with SingleTickerProviderStateMixin {
  late final AnimationController pulse;

  @override
  void initState() {
    super.initState();
    pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: pulse,
    builder: (context, child) => Opacity(
      opacity: .80 + (pulse.value * .20),
      child: Transform.scale(scale: .985 + (pulse.value * .025), child: child),
    ),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF43C6C8), Color(0xFF7C83DB), Color(0xFFE86AA6)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0xAA64D8CB), blurRadius: 24, spreadRadius: 2),
          BoxShadow(color: Color(0x88E86AA6), blurRadius: 34, spreadRadius: 1),
        ],
      ),
      child: Text(
        widget.text,
        textAlign: TextAlign.center,
        maxLines: 2,
        softWrap: true,
        overflow: TextOverflow.visible,
        style: TextStyle(
          color: Colors.white,
          fontSize: MediaQuery.sizeOf(context).width < 420 ? 14 : 16,
          fontWeight: FontWeight.w900,
          shadows: const [
            Shadow(color: Colors.black54, blurRadius: 5, offset: Offset(0, 1)),
          ],
        ),
      ),
    ),
  );
}

class _GameFlyingCards extends StatefulWidget {
  const _GameFlyingCards();

  @override
  State<_GameFlyingCards> createState() => _GameFlyingCardsState();
}

class _GameFlyingCardsState extends State<_GameFlyingCards>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion;

  @override
  void initState() {
    super.initState();
    motion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: LayoutBuilder(
      builder: (context, bounds) => AnimatedBuilder(
        animation: motion,
        builder: (context, child) {
          final wave = motion.value * math.pi * 2;
          return Stack(
            children: [
              _card(
                bounds,
                .04,
                .12,
                '2',
                const Color(0xFF3E63DD),
                -.22,
                math.sin(wave) * 12,
              ),
              _card(
                bounds,
                .88,
                .18,
                '8',
                const Color(0xFFE5484D),
                .28,
                math.cos(wave) * 10,
              ),
              _card(
                bounds,
                .08,
                .66,
                '6',
                const Color(0xFFF5C542),
                .18,
                math.sin(wave + 2) * 11,
              ),
              _card(
                bounds,
                .86,
                .68,
                '4',
                const Color(0xFF8E4EC6),
                -.25,
                math.cos(wave + 3) * 13,
              ),
            ],
          );
        },
      ),
    ),
  );

  Widget _card(
    BoxConstraints bounds,
    double x,
    double y,
    String number,
    Color color,
    double angle,
    double movement,
  ) => Positioned(
    left: bounds.maxWidth * x,
    top: (bounds.maxHeight * y) + movement,
    child: Transform.rotate(
      angle: angle + (movement / 220),
      child: Opacity(
        opacity: .14,
        child: Container(
          width: 72,
          height: 104,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white54, width: 2),
          ),
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 34,
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    ),
  );
}
