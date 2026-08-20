import 'card_model.dart';

class KzPlayer {
  const KzPlayer({
    required this.id,
    required this.name,
    required this.lives,
    required this.ready,
    required this.eliminated,
    required this.connected,
    required this.isHost,
    required this.cardCount,
    required this.cards,
    this.teamId,
    this.score,
  });

  final String id;
  final String name;
  final int lives;
  final bool ready;
  final bool eliminated;
  final bool connected;
  final bool isHost;
  final int cardCount;
  final List<KzCard> cards;
  final String? teamId;
  final int? score;

  factory KzPlayer.fromJson(Map<String, dynamic> json) => KzPlayer(
    id: '${json['id'] ?? ''}',
    name: '${json['name'] ?? ''}',
    lives: (json['lives'] as num?)?.toInt() ?? 0,
    ready: json['ready'] == true,
    eliminated: json['eliminated'] == true,
    connected: json['connected'] == true,
    isHost: json['isHost'] == true,
    cardCount: (json['cardCount'] as num?)?.toInt() ?? 0,
    cards: (json['cards'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => KzCard.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
    teamId: json['teamId']?.toString(),
    score: (json['score'] as num?)?.toInt(),
  );
}
