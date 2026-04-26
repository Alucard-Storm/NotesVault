import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/errors/app_exceptions.dart';
import '../core/errors/error_handler.dart';
import '../models/checklist_item.dart';
import '../models/note.dart';
import '../services/notes_repository.dart';

class NotesController extends ChangeNotifier {
  NotesController({required NotesRepository repository})
      : _repository = repository;

  final NotesRepository _repository;
  final Uuid _uuid = const Uuid();

  List<Note> _notes = const [];
  bool _isLoading = false;

  List<Note> get activeNotes {
    final visible = _notes.where((n) => !n.isArchived).toList();
    final sorted = [...visible]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    sorted.sort((a, b) {
      if (a.isPinned == b.isPinned) {
        return 0;
      }
      return a.isPinned ? -1 : 1;
    });
    return sorted;
  }

  List<Note> get allNotes {
    final sorted = [..._notes]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted;
  }

  List<Note> get archivedNotes {
    final archived = _notes.where((n) => n.isArchived).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return archived;
  }

  Note? findById(String noteId) {
    for (final note in _notes) {
      if (note.id == noteId) {
        return note;
      }
    }
    return null;
  }

  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    _notes = await _repository.loadNotes();

    _isLoading = false;
    notifyListeners();
  }

  Future<String> upsertNote({
    String? noteId,
    required String title,
    required String content,
    NoteType noteType = NoteType.text,
    String contentFormat = 'plain',
    List<ChecklistItem> checklistItems = const [],
  }) async {
    // Validate inputs
    ErrorHandler.validateTitleLength(title);

    try {
      final now = DateTime.now();
      late final String resolvedId;

      if (noteId == null) {
        resolvedId = _uuid.v4();
        _notes = [
          Note(
            id: resolvedId,
            title: title,
            content: content,
            updatedAt: now,
            isPinned: false,
            isArchived: false,
            tags: const [],
            folder: null,
            noteType: noteType,
            contentFormat: contentFormat,
            checklistItems: checklistItems,
          ),
          ..._notes,
        ];
      } else {
        resolvedId = noteId;
        _notes = _notes
            .map(
              (n) => n.id == noteId
                  ? n.copyWith(
                      title: title,
                      content: content,
                      updatedAt: now,
                      noteType: noteType,
                      contentFormat: contentFormat,
                      checklistItems: checklistItems,
                    )
                  : n,
            )
            .toList();
      }

      await _repository.saveNotes(_notes);
      notifyListeners();
      return resolvedId;
    } catch (e) {
      if (e is AppException) rethrow;
      throw NoteOperationError('Failed to save note: ${e.toString()}');
    }
  }

  Future<void> deleteNote(String noteId) async {
    _notes = _notes.where((n) => n.id != noteId).toList();
    await _repository.saveNotes(_notes);
    notifyListeners();
  }

  Future<void> togglePinned(String noteId) async {
    _notes = _notes
        .map(
          (n) => n.id == noteId
              ? n.copyWith(isPinned: !n.isPinned, updatedAt: DateTime.now())
              : n,
        )
        .toList();
    await _repository.saveNotes(_notes);
    notifyListeners();
  }

  Future<void> toggleArchived(String noteId) async {
    _notes = _notes
        .map(
          (n) => n.id == noteId
              ? n.copyWith(isArchived: !n.isArchived, updatedAt: DateTime.now())
              : n,
        )
        .toList();
    await _repository.saveNotes(_notes);
    notifyListeners();
  }

  Future<void> setTags(String noteId, List<String> tags) async {
    final cleaned = tags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();
    _notes = _notes
        .map(
          (n) => n.id == noteId
              ? n.copyWith(tags: cleaned, updatedAt: DateTime.now())
              : n,
        )
        .toList();
    await _repository.saveNotes(_notes);
    notifyListeners();
  }

  Future<void> setFolder(String noteId, String? folder) async {
    final normalized = folder?.trim();
    final nextFolder = (normalized == null || normalized.isEmpty)
        ? null
        : normalized;
    _notes = _notes
        .map(
          (n) => n.id == noteId
              ? n.copyWith(
                  folder: nextFolder,
                  updatedAt: DateTime.now(),
                )
              : n,
        )
        .toList();
    await _repository.saveNotes(_notes);
    notifyListeners();
  }

  /// Test helper: Add a note to internal state without persistence
  void addNoteToInternalState(Note note) {
    _notes = [..._notes, note];
    notifyListeners();
  }

  /// Test helper: Clear all notes
  void clearAllNotes() {
    _notes = const [];
    notifyListeners();
  }
}
