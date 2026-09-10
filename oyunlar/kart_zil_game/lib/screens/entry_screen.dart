import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/socket_service.dart';
import '../utils/site_navigation.dart';
import '../widgets/education_center_button.dart';

class KzEntryScreen extends StatefulWidget {
  const KzEntryScreen({super.key});
  @override
  State<KzEntryScreen> createState() => _KzEntryScreenState();
}

class _KzEntryScreenState extends State<KzEntryScreen>
    with TickerProviderStateMixin {
  final name = TextEditingController(), code = TextEditingController();
  int playerCount = 4;
  String gameMode = 'solo';
  String? mode;
  late final AnimationController intro;
  late final AnimationController floating;

  int get colorCount => playerCount <= 4
      ? 4
      : (playerCount <= 6 ? 5 : (playerCount <= 8 ? 7 : 9));
  int get deckSize => playerCount <= 4
      ? 40
      : (playerCount <= 6 ? 50 : (playerCount <= 8 ? 70 : 90));

  @override
  void initState() {
    super.initState();
    intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    floating = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
  }

  @override
  void dispose() {
    intro.dispose();
    floating.dispose();
    name.dispose();
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = KzSocketService.instance;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF5274EA), Color(0xFF594FC0), Color(0xFF292845)],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: _TableBackdrop(animation: floating)),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 12,
              left: 14,
              child: KzEducationCenterButton(onPressed: goToGamesPage),
            ),
            FadeTransition(
              opacity: CurvedAnimation(parent: intro, curve: Curves.easeOut),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _HeroCards(animation: intro, compact: mode != null),
                        const Text(
                          'KART & ZİL',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Elini güçlendir, doğru anda zile bas.',
                          style: TextStyle(fontSize: 15),
                        ),
                        SizedBox(height: mode == null ? 20 : 14),
                        Row(
                          children: [
                            Expanded(
                              child: _ModeButton(
                                selected: mode == 'create',
                                icon: Icons.add_circle_outline,
                                label: 'ODA KUR',
                                onTap: () => setState(() => mode = 'create'),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _ModeButton(
                                selected: mode == 'join',
                                icon: Icons.login,
                                label: 'ODAYA KATIL',
                                onTap: () => setState(() => mode = 'join'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 420),
                          switchInCurve: Curves.easeOutBack,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween(
                                    begin: const Offset(0, .12),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                          child: mode == null
                              ? const SizedBox(
                                  key: ValueKey('hint'),
                                  height: 16,
                                )
                              : _ActionPanel(
                                  key: ValueKey(mode),
                                  child: Column(
                                    children: [
                                      TextField(
                                        controller: name,
                                        maxLength: 24,
                                        decoration: const InputDecoration(
                                          labelText: 'Oyuncu adı',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      if (mode == 'create') ...[
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
                                          selected: {gameMode},
                                          onSelectionChanged: (selected) {
                                            setState(() {
                                              gameMode = selected.first;
                                              if (gameMode == 'team' &&
                                                  playerCount.isOdd) {
                                                playerCount = math.min(
                                                  10,
                                                  playerCount + 1,
                                                );
                                              }
                                            });
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        DropdownButtonFormField<int>(
                                          initialValue: playerCount,
                                          decoration: const InputDecoration(
                                            labelText: 'Oyuncu sayısı',
                                            border: OutlineInputBorder(),
                                          ),
                                          items: [
                                            for (
                                              var count = 2;
                                              count <= 10;
                                              count++
                                            )
                                              if (gameMode == 'solo' ||
                                                  count.isEven)
                                                DropdownMenuItem(
                                                  value: count,
                                                  child: Text('$count oyuncu'),
                                                ),
                                          ],
                                          onChanged: (value) => setState(
                                            () => playerCount = value ?? 4,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          '$colorCount renk • $deckSize kartlık deste',
                                        ),
                                        const SizedBox(height: 14),
                                        SizedBox(
                                          width: 220,
                                          child: FilledButton.icon(
                                            onPressed: service.connected
                                                ? () => service.create(
                                                    name.text.trim(),
                                                    playerCount,
                                                    gameMode: gameMode,
                                                  )
                                                : null,
                                            icon: const Icon(
                                              Icons.add_circle_outline,
                                            ),
                                            label: const Text('ODA KUR'),
                                          ),
                                        ),
                                      ] else ...[
                                        TextField(
                                          controller: code,
                                          keyboardType: TextInputType.number,
                                          maxLength: 6,
                                          decoration: const InputDecoration(
                                            labelText: '6 haneli oda kodu',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        SizedBox(
                                          width: 220,
                                          child: FilledButton.icon(
                                            onPressed: service.connected
                                                ? () => service.join(
                                                    code.text.trim(),
                                                    name.text.trim(),
                                                  )
                                                : null,
                                            icon: const Icon(Icons.login),
                                            label: const Text('ODAYA KATIL'),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                        ),
                        if (!service.connected)
                          const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Text('Sunucuya bağlanılıyor…'),
                          ),
                        if (service.error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              service.error!,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          ),
                      ],
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
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF40569A), Color(0xFF6652A0)],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white30, width: 1.5),
      boxShadow: const [
        BoxShadow(
          color: Color(0x44202743),
          blurRadius: 20,
          offset: Offset(0, 9),
        ),
      ],
    ),
    child: Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: const TextStyle(
            color: Color(0xFFE8E9F5),
            fontWeight: FontWeight.w600,
          ),
          floatingLabelStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
          counterStyle: const TextStyle(color: Color(0xFFD8DBEC)),
          hintStyle: const TextStyle(color: Color(0xFFD8DBEC)),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0x99FFFFFF), width: 1.3),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFF8FE2DF), width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Color(0xFFF5F4FA)),
        child: Column(children: [child]),
      ),
    ),
  );
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: selected ? 1.03 : 1,
    duration: const Duration(milliseconds: 220),
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: selected
              ? const [Color(0xFF397FF1), Color(0xFF7A52D4)]
              : const [Color(0xFF303A5C), Color(0xFF424467)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? const Color(0xFFD2CEFF) : Colors.white24,
          width: selected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black38, blurRadius: 10, spreadRadius: 0),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return const Color(0x225F7F8A);
            }
            if (states.contains(WidgetState.hovered)) {
              return const Color(0x1FFFFFFF);
            }
            return Colors.transparent;
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
            child: Column(
              children: [
                Icon(icon, size: 28),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _HeroCards extends StatelessWidget {
  const _HeroCards({required this.animation, required this.compact});

  final Animation<double> animation;
  final bool compact;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 320),
    curve: Curves.easeOutCubic,
    width: compact ? 245 : 350,
    height: compact ? 135 : 205,
    child: AnimatedScale(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      scale: compact ? .68 : 1,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final value = Curves.easeOutBack.transform(animation.value);
          return Stack(
            alignment: Alignment.center,
            children: [
              _card('3', const Color(0xFF3E63DD), -94 * value, -.38 * value),
              _card('7', const Color(0xFFE5484D), -48 * value, -.19 * value),
              _card('9', const Color(0xFFF5C542), 48 * value, .19 * value),
              _card('5', const Color(0xFF30A46C), 94 * value, .38 * value),
              Transform.scale(
                scale: .7 + (.3 * value),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFF171B2E),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Color(0x88FFB000), blurRadius: 24),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('🔔', style: TextStyle(fontSize: 72)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  Widget _card(String number, Color color, double x, double angle) =>
      Transform.translate(
        offset: Offset(x, 12),
        child: Transform.rotate(
          angle: angle,
          child: Container(
            width: 86,
            height: 124,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white70, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 12),
              ],
            ),
            child: Text(
              number,
              style: TextStyle(
                color: color == const Color(0xFFF5C542)
                    ? Colors.black
                    : Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      );
}

class _TableBackdrop extends StatelessWidget {
  const _TableBackdrop({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) => AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final wave = animation.value * math.pi * 2;
        return Stack(
          children: [
            _floatingCard(
              bounds,
              .08,
              .18,
              '2',
              const Color(0xFF3E63DD),
              -.28,
              math.sin(wave) * 10,
            ),
            _floatingCard(
              bounds,
              .83,
              .16,
              '8',
              const Color(0xFFE5484D),
              .24,
              math.cos(wave) * 12,
            ),
            _floatingCard(
              bounds,
              .04,
              .70,
              '6',
              const Color(0xFFF5C542),
              .18,
              math.cos(wave + 1) * 9,
            ),
            _floatingCard(
              bounds,
              .88,
              .68,
              '4',
              const Color(0xFF30A46C),
              -.25,
              math.sin(wave + 2) * 11,
            ),
            _floatingCard(
              bounds,
              .18,
              .82,
              '9',
              const Color(0xFF8E4EC6),
              .34,
              math.sin(wave + 3) * 8,
            ),
            _floatingCard(
              bounds,
              .73,
              .82,
              '7',
              const Color(0xFFF76B15),
              -.16,
              math.cos(wave + 4) * 10,
            ),
          ],
        );
      },
    ),
  );

  Widget _floatingCard(
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
      angle: angle + (movement / 180),
      child: Opacity(
        opacity: .13,
        child: Container(
          width: 92,
          height: 132,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white54, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18)],
          ),
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ),
    ),
  );
}
