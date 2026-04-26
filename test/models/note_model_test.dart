import 'package:flutter_test/flutter_test.dart';
import 'package:notevault/models/note.dart';

void main() {
  group('Note Model', () {
    test('Note creates with correct values', () {
      final note = Note(
        id: 'test-id',
        title: 'Test Title',
        content: 'Test Content',
        tags: const ['tag1', 'tag2'],
        isPinned: true,
        isArchived: false,
        folder: 'Work',
        updatedAt: DateTime(2024, 1, 2),
      );

      expect(note.id, equals('test-id'));
      expect(note.title, equals('Test Title'));
      expect(note.content, equals('Test Content'));
      expect(note.tags, equals(['tag1', 'tag2']));
      expect(note.isPinned, isTrue);
      expect(note.isArchived, isFalse);
      expect(note.folder, equals('Work'));
    });

    test('copyWith creates modified copy', () {
      final original = Note(
        id: 'id',
        title: 'Original',
        content: 'Content',
        tags: const [],
        isPinned: false,
        isArchived: false,
        folder: null,
        updatedAt: DateTime(2024, 1, 1),
      );

      final modified = original.copyWith(
        title: 'Modified',
        isPinned: true,
      );

      expect(modified.title, equals('Modified'));
      expect(modified.isPinned, isTrue);
      expect(modified.id, equals(original.id)); // Unchanged
      expect(modified.content, equals(original.content)); // Unchanged
    });

    test('toJson and fromJson work correctly', () {
      final note = Note(
        id: 'test-id',
        title: 'Test',
        content: 'Content',
        tags: const ['tag1'],
        isPinned: true,
        isArchived: false,
        folder: 'Work',
        updatedAt: DateTime(2024, 1, 2),
      );

      final json = note.toJson();
      final restored = Note.fromJson(json);

      expect(restored.id, equals(note.id));
      expect(restored.title, equals(note.title));
      expect(restored.tags, equals(note.tags));
      expect(restored.isPinned, equals(note.isPinned));
    });
  });
}
