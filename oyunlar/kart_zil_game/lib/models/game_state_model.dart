import 'card_model.dart';
import 'player_model.dart';

class KzGameState {
  const KzGameState({
    required this.roomCode,
    required this.status,
    required this.phase,
    required this.hostPlayerId,
    required this.currentPlayerId,
    required this.turnDeadline,
    required this.serverTime,
    required this.deckCount,
    required this.roundNumber,
    required this.maxPlayers,
    required this.deckSize,
    required this.colorCount,
    required this.myScore,
    required this.players,
    required this.myCards,
    required this.bellPressed,
    required this.bellPlayerId,
    required this.gameMode,
    required this.teams,
    this.openCard,
    this.winnerId,
    this.winnerTeamId,
    this.result,
  });

  final String roomCode, status, phase, hostPlayerId, currentPlayerId;
  final int turnDeadline, serverTime, deckCount, roundNumber;
  final int maxPlayers, deckSize, colorCount, myScore;
  final KzCard? openCard;
  final List<KzPlayer> players;
  final List<KzCard> myCards;
  final bool bellPressed;
  final String? bellPlayerId, winnerId;
  final String gameMode;
  final String? winnerTeamId;
  final List<KzTeam> teams;
  final Map<String, dynamic>? result;

  factory KzGameState.fromJson(Map<String, dynamic> json) {
    KzCard? card;
    if (json['openCard'] is Map) {
      card = KzCard.fromJson(
        Map<String, dynamic>.from(json['openCard'] as Map),
      );
    }
    return KzGameState(
      roomCode: '${json['roomCode'] ?? ''}',
      status: '${json['status'] ?? 'lobby'}',
      phase: '${json['phase'] ?? 'lobby'}',
      hostPlayerId: '${json['hostPlayerId'] ?? ''}',
      currentPlayerId: '${json['currentPlayerId'] ?? ''}',
      turnDeadline: (json['turnDeadline'] as num?)?.toInt() ?? 0,
      serverTime: (json['serverTime'] as num?)?.toInt() ?? 0,
      deckCount: (json['deckCount'] as num?)?.toInt() ?? 0,
      roundNumber: (json['roundNumber'] as num?)?.toInt() ?? 0,
      maxPlayers: (json['maxPlayers'] as num?)?.toInt() ?? 10,
      deckSize: (json['deckSize'] as num?)?.toInt() ?? 40,
      colorCount: (json['colorCount'] as num?)?.toInt() ?? 4,
      myScore: (json['myScore'] as num?)?.toInt() ?? 0,
      openCard: card,
      players: (json['players'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => KzPlayer.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      myCards: (json['myCards'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => KzCard.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      bellPressed: (json['bell'] as Map?)?['pressed'] == true,
      bellPlayerId: (json['bell'] as Map?)?['playerId']?.toString(),
      gameMode: '${json['gameMode'] ?? 'solo'}',
      teams: (json['teams'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => KzTeam.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      winnerId: json['winnerId']?.toString(),
      winnerTeamId: json['winnerTeamId']?.toString(),
      result: json['result'] is Map
          ? Map<String, dynamic>.from(json['result'] as Map)
          : null,
    );
  }
}

class KzTeam {
  const KzTeam({required this.id, required this.name, required this.lives});

  final String id, name;
  final int lives;

  factory KzTeam.fromJson(Map<String, dynamic> json) => KzTeam(
    id: '${json['id'] ?? ''}',
    name: '${json['name'] ?? ''}',
    lives: (json['lives'] as num?)?.toInt() ?? 0,
  );
}
