/// Represents a single item in a checklist note
class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.text,
    required this.isChecked,
    required this.order,
  });

  final String id;
  final String text;
  final bool isChecked;
  final int order; // For maintaining order

  ChecklistItem copyWith({
    String? id,
    String? text,
    bool? isChecked,
    int? order,
  }) {
    return ChecklistItem(
      id: id ?? this.id,
      text: text ?? this.text,
      isChecked: isChecked ?? this.isChecked,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isChecked': isChecked,
      'order': order,
    };
  }

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'] as String,
      text: json['text'] as String,
      isChecked: json['isChecked'] as bool? ?? false,
      order: json['order'] as int? ?? 0,
    );
  }
}

/// Enum for different note types
enum NoteType {
  text('text'),
  checklist('checklist'),
  richText('richText');

  const NoteType(this.value);
  final String value;

  factory NoteType.fromValue(String value) {
    return NoteType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => NoteType.text,
    );
  }
}
