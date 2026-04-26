class Vault {
  const Vault({
    required this.id,
    required this.name,
    required this.isLocked,
  });

  final String id;
  final String name;
  final bool isLocked;

  Vault copyWith({
    String? id,
    String? name,
    bool? isLocked,
  }) {
    return Vault(
      id: id ?? this.id,
      name: name ?? this.name,
      isLocked: isLocked ?? this.isLocked,
    );
  }
}
