import 'package:flutter_test/flutter_test.dart';
import 'package:kart_zil_game/main.dart';

void main() {
  testWidgets('entry screen renders', (tester) async {
    await tester.pumpWidget(const KartZilApp());
    await tester.pump();
    expect(find.text('KART & ZİL'), findsOneWidget);
  });
}
