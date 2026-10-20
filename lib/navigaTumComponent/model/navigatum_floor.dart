class NavigaTumFloor {
  final int id;
  final String shortName;

  const NavigaTumFloor({required this.id, required this.shortName});

  factory NavigaTumFloor.fromJson(Map<String, dynamic> json) => NavigaTumFloor(
    id: (json['id'] as num).toInt(),
    shortName: json['short_name'] as String,
  );

  Map<String, dynamic> toJson() => {'id': id, 'short_name': shortName};
}
