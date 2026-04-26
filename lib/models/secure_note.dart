class SecureNote {
  const SecureNote({
    required this.id,
    required this.vaultId,
    required this.encryptedData,
  });

  final String id;
  final String vaultId;
  final String encryptedData;

  SecureNote copyWith({
    String? id,
    String? vaultId,
    String? encryptedData,
  }) {
    return SecureNote(
      id: id ?? this.id,
      vaultId: vaultId ?? this.vaultId,
      encryptedData: encryptedData ?? this.encryptedData,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vaultId': vaultId,
      'encryptedData': encryptedData,
    };
  }

  factory SecureNote.fromJson(Map<String, dynamic> json) {
    return SecureNote(
      id: json['id'] as String,
      vaultId: json['vaultId'] as String,
      encryptedData: json['encryptedData'] as String,
    );
  }
}
