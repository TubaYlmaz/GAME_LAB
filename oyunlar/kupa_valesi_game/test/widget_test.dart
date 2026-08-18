import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kupa_valesi_game/screens/jh_guess_dialog.dart';

void main() {
  testWidgets('displays all four card suit choices', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: JhGuessDialog(
          roomCode: 'TEST',
          playerName: 'Oyuncu',
          cellEndsAt: DateTime.now().millisecondsSinceEpoch + 60000,
          initiallyLocked: false,
          serverTimeOffsetMs: 0,
        ),
      ),
    );

    for (final symbol in ['\u2665', '\u2660', '\u2666', '\u2663']) {
      expect(find.text(symbol), findsOneWidget);
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
