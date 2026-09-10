import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kupa_valesi_game/screens/jh_guess_dialog.dart';

void main() {
  testWidgets('displays four symbol doors and opens the selected one', (
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

    for (final door in ['Güneş', 'Ay', 'Yıldız', 'Bulut']) {
      expect(find.text(door), findsOneWidget);
    }

    await tester.tap(find.text('Güneş'));
    await tester.pumpAndSettle();
    expect(find.text('Güneş SEÇİLDİ'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
