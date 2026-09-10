import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/socket_service.dart';
import '../utils/site_navigation.dart';
import '../widgets/education_center_button.dart';
import '../widgets/game_logo.dart';
import '../widgets/player_status.dart';
import '../widgets/top_bar_controls.dart';

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
          decoration: BoxDecoration(gradient: kzTopBarGradient),
        ),
        leadingWidth: 58,
        leading: Padding(
          padding: const EdgeInsets.fromLTRB(7, 9, 4, 9),
          child: KzEducationCenterButton(
            onPressed: () async {
              await service.leave();
              goToGamesPage();
            },
          ),
        ),
        title: KzGameLogo(
          width: isMobile ? 88 : 112,
          height: isMobile ? 44 : 52,
        ),
        actions: [
          KzTopIconButton(
            tooltip: 'Oyundan çık',
            onPressed: service.leave,
            icon: Icons.logout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.2,
            colors: [Color(0xFF5274EA), Color(0xFF292845)],
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
                      colors: [Color(0xFF397FF1), Color(0xFF7A52D4)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFD2CEFF),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x55202743),
                        blurRadius: 20,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'KART & ZİL ODASI',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Oyuncularını bekle, kartlarını hazırla!',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Material(
                            color: const Color(0x55202743),
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () =>
                                  _copyRoomCode(context, state.roomCode),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 11,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'ODA KODU',
                                          style: TextStyle(
                                            color: Color(0xFFD7D9C9),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                        SelectableText(
                                          state.roomCode,
                                          style: const TextStyle(
                                            fontSize: 30,
                                            letterSpacing: 6,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    const Icon(
                                      Icons.copy_rounded,
                                      color: Color(0xFFD7D9C9),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: state.players.length / state.maxPlayers,
                          minHeight: 9,
                          backgroundColor: Colors.black26,
                          color: const Color(0xFF91AAA5),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _LobbyDetail(
                            icon: Icons.groups_rounded,
                            text:
                                '${state.players.length}/${state.maxPlayers} OYUNCU',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: EdgeInsets.all(isMobile ? 14 : 18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF40569A), Color(0xFF6652A0)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white30, width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x44202743),
                        blurRadius: 22,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (me?.isHost == true) ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.tune_rounded,
                              color: Color(0xFFFFD36A),
                            ),
                            const SizedBox(width: 9),
                            const Text(
                              'OYUN AYARLARI',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: .7,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0x30202743),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white24),
                          ),
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
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DropdownButton<int>(
                                    dropdownColor: const Color(0xFF465277),
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
                        const SizedBox(height: 18),
                      ],
                      Row(
                        children: [
                          const Icon(
                            Icons.groups_rounded,
                            color: Color(0xFF82D8C6),
                          ),
                          const SizedBox(width: 9),
                          const Expanded(
                            child: Text(
                              'OYUNCULAR',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: .7,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x44202743),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${state.players.length} kişi',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...state.players.map(
                        (p) => KzPlayerStatus(
                          player: p,
                          isTurn: false,
                          lobbyStyle: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: canStart
                              ? const Color(0x3349C8A3)
                              : const Color(0x33FFCA4B),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: canStart
                                ? const Color(0x7782D8C6)
                                : const Color(0x66FFD36A),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              canStart
                                  ? Icons.check_circle_rounded
                                  : Icons.hourglass_bottom_rounded,
                              color: canStart
                                  ? const Color(0xFF82D8C6)
                                  : const Color(0xFFFFD36A),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                canStart
                                    ? 'Herkes hazır. Oyun başlatılabilir.'
                                    : state.players.length < state.maxPlayers
                                    ? '${state.maxPlayers - state.players.length} oyuncu daha bekleniyor.'
                                    : 'Oyuncuların hazır olması bekleniyor.',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: const Color(0xFF82D8C6),
                          foregroundColor: const Color(0xFF202743),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () =>
                            service.setReady(!(me?.ready ?? false)),
                        icon: Icon(
                          me?.ready == true ? Icons.close : Icons.check,
                        ),
                        label: Text(
                          me?.ready == true ? 'HAZIR DEĞİLİM' : 'HAZIRIM',
                        ),
                      ),
                      if (me?.isHost == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              backgroundColor: const Color(0xFFFFCA4B),
                              foregroundColor: const Color(0xFF202743),
                              disabledBackgroundColor: const Color(0x335D6483),
                              disabledForegroundColor: Colors.white38,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: canStart ? service.startGame : null,
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('OYUNU BAŞLAT'),
                          ),
                        ),
                    ],
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

  Future<void> _copyRoomCode(BuildContext context, String roomCode) async {
    await Clipboard.setData(ClipboardData(text: roomCode));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Oda kodu kopyalandı.')));
  }
}

class _LobbyDetail extends StatelessWidget {
  const _LobbyDetail({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0x44202743),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFFFFE39A)),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}
