import 'enums.dart';

class Category {
  const Category({
    this.id,
    required this.name,
    required this.type,
    required this.color,
    required this.icon,
    this.isDefault = false,
  });

  final int? id;
  final String name;
  final TxType type;

  /// ARGB renk değeri (ör. `0xFF2E7D32`).
  final int color;

  /// `categoryIcons` map'indeki anahtar (ör. `shopping_cart`).
  final String icon;
  final bool isDefault;

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'type': type.name,
    'color': color,
    'icon': icon,
    'is_default': isDefault ? 1 : 0,
  };

  factory Category.fromMap(Map<String, Object?> m) => Category(
    id: m['id'] as int?,
    name: m['name'] as String,
    type: TxType.values.byName(m['type'] as String),
    color: m['color'] as int,
    icon: m['icon'] as String,
    isDefault: (m['is_default'] as int? ?? 0) == 1,
  );

  Category copyWith({
    int? id,
    String? name,
    TxType? type,
    int? color,
    String? icon,
    bool? isDefault,
  }) => Category(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    color: color ?? this.color,
    icon: icon ?? this.icon,
    isDefault: isDefault ?? this.isDefault,
  );

  @override
  bool operator ==(Object other) =>
      other is Category &&
      other.id == id &&
      other.name == name &&
      other.type == type &&
      other.color == color &&
      other.icon == icon &&
      other.isDefault == isDefault;

  @override
  int get hashCode => Object.hash(id, name, type, color, icon, isDefault);

  @override
  String toString() => 'Category($id, $name, ${type.name})';
}
