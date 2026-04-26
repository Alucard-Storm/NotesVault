class Note {
  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
    required this.isPinned,
    required this.isArchived,
    required this.tags,
    required this.folder,
  });

  final String id;
  final String title;
  final String content;
  final DateTime updatedAt;
  final bool isPinned;
  final bool isArchived;
  final List<String> tags;
  final String? folder;

  Note copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? updatedAt,
    bool? isPinned,
    bool? isArchived,
    List<String>? tags,
    String? folder,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      tags: tags ?? this.tags,
      folder: folder ?? this.folder,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'updatedAt': updatedAt.toIso8601String(),
      'isPinned': isPinned,
      'isArchived': isArchived,
      'tags': tags,
      'folder': folder,
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    final tags = rawTags is List<dynamic>
        ? rawTags.map((item) => item.toString()).toList()
        : const <String>[];

    return Note(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isPinned: json['isPinned'] as bool? ?? false,
      isArchived: json['isArchived'] as bool? ?? false,
      tags: tags,
      folder: (json['folder'] as String?)?.trim().isEmpty == true
          ? null
          : (json['folder'] as String?),
    );
  }
}
