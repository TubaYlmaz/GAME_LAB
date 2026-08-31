import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vampir_koylu_game/main.dart';

void main() {
  testWidgets('entry screen and education center button render', (
    tester,
  ) async {
    await tester.pumpWidget(const VampireVillagerApp());
    await tester.pump();

    expect(find.textContaining('VAMPIRE VILLAGER'), findsOneWidget);
    expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
  });
}
