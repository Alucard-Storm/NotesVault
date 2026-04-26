import 'package:flutter_test/flutter_test.dart';
import 'package:notevault/controllers/notes_controller.dart';
import 'package:notevault/models/note.dart';

import '../mocks/mock_services.dart';

void main() {
  group('NotesController', () {
    late NotesController controller;
    late MockNotesRepository mockRepository;

    setUp(() {
      mockRepository = MockNotesRepository();
      controller = NotesController(repository: mockRepository);
    });

    tearDown(() {
      controller.dispose();
    });

    test('initializes with empty notes list', () {
      expect(controller.allNotes, isEmpty);
      expect(controller.activeNotes, isEmpty);
      expect(controller.archivedNotes, isEmpty);
    });

    test('activeNotes returns non-archived notes sorted by pin and date', () {
      // Create test notes
      final note1 = Note(
        id: '1',
        title: 'Test 1',
        content: 'Content 1',
        tags: const [],
        isPinned: false,
        isArchived: false,
        folder: null,
        updatedAt: DateTime(2024, 1, 1),
      );
      
      final note2 = Note(
        id: '2',
        title: 'Test 2',
        content: 'Content 2',
        tags: const [],
        isPinned: true,
        isArchived: false,
        folder: null,
        updatedAt: DateTime(2024, 1, 2),
      );

      // Manually add to controller's internal state for testing
      controller.addNoteToInternalState(note1);
      controller.addNoteToInternalState(note2);

      final active = controller.activeNotes;
      expect(active, isNotEmpty);
      // Pinned note should come first
      expect(active.first.isPinned, isTrue);
    });

    test('archivedNotes returns only archived notes', () {
      // Test archived filtering logic
      final note1 = Note(
        id: '1',
        title: 'Archived',
        content: 'Content',
        tags: const [],
        isPinned: false,
        isArchived: true,
        folder: null,
        updatedAt: DateTime(2024, 1, 1),
      );

      controller.addNoteToInternalState(note1);
      
      final archived = controller.archivedNotes;
      expect(archived, hasLength(1));
      expect(archived.first.isArchived, isTrue);
    });

    test('findById returns correct note', () {
      final note = Note(
        id: 'unique-id',
        title: 'Find Me',
        content: 'Content',
        tags: const [],
        isPinned: false,
        isArchived: false,
        folder: null,
        updatedAt: DateTime.now(),
      );

      controller.addNoteToInternalState(note);
      
      final found = controller.findById('unique-id');
      expect(found, isNotNull);
      expect(found?.title, equals('Find Me'));
    });

    test('findById returns null for non-existent note', () {
      final found = controller.findById('non-existent');
      expect(found, isNull);
    });
  });
}
