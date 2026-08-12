import 'package:flutter/material.dart';

import '../widgets/chance_game_card.dart';

class ChanceGameMenuScreen extends StatelessWidget {
  const ChanceGameMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\u015eANS OYUNLARI',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Yaz\u0131-tura veya zar atma modunu se\u00e7erek ba\u015fla.',
                  ),
                  const SizedBox(height: 28),
                  const ChanceGameCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
