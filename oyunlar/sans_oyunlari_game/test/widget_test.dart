import 'package:flutter_test/flutter_test.dart';

import 'package:sans_oyunlari_game/chance_games_app.dart';

void main() {
  testWidgets('opens the game screen directly', (tester) async {
    await tester.pumpWidget(const ChanceGamesApp());

    expect(find.text('\u015eans Oyunlar\u0131'), findsOneWidget);
    expect(find.text('YAZI - TURA'), findsOneWidget);
    expect(find.text('PARAYI AT'), findsOneWidget);
  });
}
