import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sans_oyunlari_game/models/throw_history.dart';
import 'package:sans_oyunlari_game/services/result_randomizer.dart';

void main() {
  test('coin flips never contain a third identical consecutive result', () {
    final randomizer = ResultRandomizer(random: Random(41));
    CoinSide? previous;
    var streak = 0;

    for (var index = 0; index < 200; index++) {
      final next = randomizer.nextCoinSide();
      streak = next == previous ? streak + 1 : 1;
      previous = next;
      expect(streak, lessThanOrEqualTo(2));
    }
  });

  test(
    'single-die rolls never contain a third identical consecutive result',
    () {
      final randomizer = ResultRandomizer(random: Random(73));
      List<int>? previous;
      var streak = 0;

      for (var index = 0; index < 200; index++) {
        final next = randomizer.rollDice(diceCount: 1);
        streak = _sameValues(next, previous) ? streak + 1 : 1;
        previous = next;
        expect(streak, lessThanOrEqualTo(2));
      }
    },
  );
}

bool _sameValues(List<int> first, List<int>? second) {
  if (second == null || first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}
