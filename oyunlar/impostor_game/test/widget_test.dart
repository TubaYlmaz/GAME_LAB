import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impostor_game/main.dart';

void main() {
  testWidgets('entry screen and games button render', (
    tester,
  ) async {
    await tester.pumpWidget(const ImpostorGameApp());
    await tester.pump();

    expect(find.text('IMPOSTOR'), findsOneWidget);
    expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
  });
}
