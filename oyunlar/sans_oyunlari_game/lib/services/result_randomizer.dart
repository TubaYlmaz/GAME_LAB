import 'dart:math';

import '../models/throw_history.dart';

/// Produces cryptographically secure outcomes while avoiding long, visually
/// repetitive streaks. A third identical coin or dice sequence is re-rolled.
class ResultRandomizer {
  ResultRandomizer({Random? random}) : _random = random ?? Random.secure();

  final Random _random;
  CoinSide? _lastCoinSide;
  int _coinStreak = 0;
  final Map<int, _DiceSequence> _diceSequences = {};

  CoinSide nextCoinSide() {
    var nextSide = _random.nextBool() ? CoinSide.heads : CoinSide.tails;
    if (_coinStreak >= 2 && nextSide == _lastCoinSide) {
      nextSide = nextSide == CoinSide.heads ? CoinSide.tails : CoinSide.heads;
    }

    _coinStreak = nextSide == _lastCoinSide ? _coinStreak + 1 : 1;
    _lastCoinSide = nextSide;
    return nextSide;
  }

  List<int> rollDice({required int diceCount}) {
    if (diceCount < 1 || diceCount > 2) {
      throw RangeError.range(diceCount, 1, 2, 'diceCount');
    }

    final sequence = _diceSequences.putIfAbsent(diceCount, _DiceSequence.new);
    var values = _newDiceValues(diceCount);
    if (sequence.streak >= 2 && _sameValues(values, sequence.values)) {
      values = _newDifferentDiceValues(diceCount, sequence.values!);
    }

    sequence.streak = _sameValues(values, sequence.values)
        ? sequence.streak + 1
        : 1;
    sequence.values = List<int>.unmodifiable(values);
    return List<int>.unmodifiable(values);
  }

  List<int> _newDiceValues(int diceCount) =>
      List<int>.generate(diceCount, (_) => _random.nextInt(6) + 1);

  List<int> _newDifferentDiceValues(int diceCount, List<int> previousValues) {
    for (var attempt = 0; attempt < 12; attempt++) {
      final values = _newDiceValues(diceCount);
      if (!_sameValues(values, previousValues)) return values;
    }

    final values = List<int>.from(previousValues);
    values[0] = values[0] == 6 ? 1 : values[0] + 1;
    return values;
  }

  bool _sameValues(List<int> first, List<int>? second) {
    if (second == null || first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}

class _DiceSequence {
  List<int>? values;
  int streak = 0;
}
