enum ChanceGameMode { coin, dice }

enum CoinSide {
  heads('YAZI'),
  tails('TURA');

  const CoinSide(this.label);

  final String label;
}

class ThrowHistory {
  ThrowHistory({
    required this.id,
    required this.mode,
    required this.createdAt,
    this.coinSide,
    this.diceValues = const [],
  }) : assert(
         (mode == ChanceGameMode.coin && coinSide != null) ||
             (mode == ChanceGameMode.dice && diceValues.isNotEmpty),
         'Her kay\u0131t, moduna uygun bir sonu\u00e7 i\u00e7ermelidir.',
       );

  final String id;
  final ChanceGameMode mode;
  final DateTime createdAt;
  final CoinSide? coinSide;
  final List<int> diceValues;

  String get resultLabel {
    if (mode == ChanceGameMode.coin) return coinSide!.label;
    return diceValues.join(' + ');
  }

  int? get diceTotal =>
      mode == ChanceGameMode.dice ? diceValues.reduce((a, b) => a + b) : null;

  Map<String, dynamic> toActionPayload() => {
    'game': 'chance_games',
    'action': mode == ChanceGameMode.coin ? 'coin_flip' : 'dice_roll',
    'actionId': id,
    'createdAt': createdAt.toIso8601String(),
    'result': mode == ChanceGameMode.coin
        ? {'coinSide': coinSide!.name}
        : {'diceValues': diceValues, 'total': diceTotal},
  };
}
