class Tag {
  final int? id;
  String name;
  int color;
  final int bookCount;

  Tag({
    this.id,
    required this.name,
    this.color = 0,
    this.bookCount = 0,
  });

  // Creates a copy of the tag with updated fields
  Tag copyWith({
    int? id,
    String? name,
    int? color,
    int? bookCount,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      bookCount: bookCount ?? this.bookCount,
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
      bookCount: map['bookCount'] != null ? map['bookCount'] as int : 0,
    );
  }

  @override
  String toString() =>
      'Tag(id: $id, name: $name, color: ${color.toRadixString(16)}, count: $bookCount)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Tag &&
              runtimeType == other.runtimeType &&
              id == other.id &&
              name == other.name &&
              color == other.color &&
              bookCount == other.bookCount;

  @override
  int get hashCode =>
      id.hashCode ^ name.hashCode ^ color.hashCode ^ bookCount.hashCode;
}
