class Tag {
  final int? id;
  String name;
  int color;

  Tag({
    this.id,
    required this.name,
    this.color = 0,
  });

  // Creates a copy of the tag with updated fields
  Tag copyWith({
    int? id,
    String? name,
    int? color,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
    };
  }

  factory Tag.fromMap(Map<String, dynamic> map) {
    return Tag(
      id: map['id'],
      name: map['name'],
      color: map['color'] ?? 0,
    );
  }

  @override
  String toString() => 'Tag(id: $id, name: $name, color: ${color.toRadixString(16)})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Tag &&
              runtimeType == other.runtimeType &&
              id == other.id &&
              name == other.name &&
              color == other.color;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ color.hashCode;
}