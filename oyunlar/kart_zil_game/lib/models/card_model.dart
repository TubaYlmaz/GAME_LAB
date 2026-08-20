class KzCard {
  const KzCard({required this.id, required this.color, required this.number});

  final String id;
  final String color;
  final int number;

  factory KzCard.fromJson(Map<String, dynamic> json) => KzCard(
    id: '${json['id'] ?? ''}',
    color: '${json['color'] ?? 'blue'}',
    number: (json['number'] as num?)?.toInt() ?? 0,
  );
}
