import 'package:flutter/material.dart';

import '../services/socket_service.dart';
import '../utils/site_navigation.dart';
import '../widgets/game_logo.dart';
import '../widgets/player_status.dart';

class KzLobbyScreen extends StatelessWidget {
  const KzLobbyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final service = KzSocketService.instance, state = service.state!;
    final me = state.players.where((p) => p.id == service.playerId).firstOrNull;
    final canStart =
        me?.isHost == true &&
        state.players.length == state.maxPlayers &&
        state.players.every((p) => p.ready && p.connected);
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 66,
        centerTitle: true,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF34456F), Color(0xFF534B7D), Color(0xFF355F78)],
            ),
          ),
        ),
        leadingWidth: isMobile ? 145 : 230,
        leading: Padding(
          padding: const EdgeInsets.fromLTRB(7, 9, 4, 9),
          child: Row(
            children: [
              IconButton.filledTonal(
                tooltip: 'Oyunlara dön',
                style: IconButton.styleFrom(
                  foregroundColor: const Color(0xFF9CE5E3),
                  backgroundColor: const Color(0x334EC7C4),
                  side: const BorderSide(color: Color(0x9965C6C4)),
                ),
                onPressed: () async {
                  await service.leave();
                  goToGamesPage();
                },
                icon: const Icon(Icons.grid_view_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isMobile ? 'KART & ZİL' : 'KART & ZİL LOBİSİ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        title: KzGameLogo(
          width: isMobile ? 88 : 112,
          height: isMobile ? 44 : 52,
        ),
        actions: [
          IconButton.filled(
            tooltip: 'Oyundan çık',
            style: IconButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF9B73D1),
            ),
            onPressed: service.leave,
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.2,
            colors: [Color(0xFF6573A8), Color(0xFF27304E)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF7188C5), Color(0xFF9B7FBE)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white38, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x663E63DD),
                        blurRadius: 28,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text('🔔', style: TextStyle(fontSize: 64)),
                      const Text(
                        'ODA KODU',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                        ),
                      ),
                      SelectableText(
                        state.roomCode,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 48,
                          letterSpacing: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text('Kodu arkadaşlarınla paylaş'),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: state.players.length / state.maxPlayers,
                          minHeight: 9,
                          backgroundColor: Colors.black26,
                          color: const Color(0xFFFFB000),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${state.players.length}/${state.maxPlayers} oyuncu • ${state.gameMode == 'team' ? 'Takım oyunu' : 'Bireysel'} • ${state.colorCount} renk • ${state.deckSize} kart',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (me?.isHost == true) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'solo',
                                icon: Icon(Icons.person),
                                label: Text('BİREYSEL'),
                              ),
                              ButtonSegment(
                                value: 'team',
                                icon: Icon(Icons.groups_2),
                                label: Text('TAKIM'),
                              ),
                            ],
                            selected: {state.gameMode},
                            onSelectionChanged: (selected) {
                              final mode = selected.first;
                              final count =
                                  mode == 'team' && state.maxPlayers.isOdd
                                  ? (state.maxPlayers + 1).clamp(2, 10)
                                  : state.maxPlayers;
                              service.updateRoomSettings(count, mode);
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.groups_2_outlined),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Yeni oyun oyuncu sayısı',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DropdownButton<int>(
                                value: state.maxPlayers,
                                items: [
                                  for (
                                    var count = state.players.length < 2
                                        ? 2
                                        : state.players.length;
                                    count <= 10;
                                    count++
                                  )
                                    if (state.gameMode == 'solo' ||
                                        count.isEven)
                                      DropdownMenuItem(
                                        value: count,
                                        child: Text('$count kişi'),
                                      ),
                                ],
                                onChanged: (value) {
                                  if (value != null &&
                                      value != state.maxPlayers) {
                                    service.updateRoomSettings(
                                      value,
                                      state.gameMode,
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                ...state.players.map(
                  (p) => KzPlayerStatus(player: p, isTurn: false),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => service.setReady(!(me?.ready ?? false)),
                  icon: Icon(me?.ready == true ? Icons.close : Icons.check),
                  label: Text(me?.ready == true ? 'HAZIR DEĞİLİM' : 'HAZIRIM'),
                ),
                if (me?.isHost == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: FilledButton.icon(
                      onPressed: canStart ? service.startGame : null,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('OYUNU BAŞLAT'),
                    ),
                  ),
                if (service.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      service.error!,
                      style: const TextStyle(color: Colors.redAccent),
                      textAlign: TextAlign.center,
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
