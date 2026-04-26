import 'dart:convert';

import 'package:flutter/material.dart';

import '../../controllers/notes_controller.dart';
import '../../models/checklist_item.dart';
import '../../models/note.dart';
import 'note_composer_page.dart';
import 'note_open_page.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key, required this.controller});

  final NotesController controller;

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _selectedTag;
  String? _selectedFolder;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        if (widget.controller.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final allTags = widget.controller.allNotes
            .expand((note) => note.tags)
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        final allFolders = widget.controller.allNotes
            .map((note) => note.folder?.trim())
            .whereType<String>()
            .where((folder) => folder.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

        final activeSource = widget.controller.activeNotes.where((note) {
          final matchesTag = _selectedTag == null || note.tags.contains(_selectedTag);
          final matchesFolder = _selectedFolder == null || note.folder == _selectedFolder;
          return matchesTag && matchesFolder;
        }).toList();
        final archivedSource = widget.controller.archivedNotes.where((note) {
          final matchesTag = _selectedTag == null || note.tags.contains(_selectedTag);
          final matchesFolder = _selectedFolder == null || note.folder == _selectedFolder;
          return matchesTag && matchesFolder;
        }).toList();

        final pinned = activeSource.where((n) => n.isPinned).toList();
        final others = activeSource.where((n) => !n.isPinned).toList();
        final notes = activeSource;
        final archived = archivedSource;
        final hasAnyNotes = notes.isNotEmpty || archived.isNotEmpty;
        final filterLabel = _selectedTag != null
            ? 'Tag: $_selectedTag'
            : _selectedFolder != null
                ? 'Folder: $_selectedFolder'
                : null;

        return Scaffold(
          key: _scaffoldKey,
          drawer: _NotesSidebar(
            selectedTag: _selectedTag,
            selectedFolder: _selectedFolder,
            allTags: allTags,
            allFolders: allFolders,
            onClearFilter: () {
              setState(() {
                _selectedTag = null;
                _selectedFolder = null;
              });
              Navigator.of(context).pop();
            },
            onSelectTag: (tag) {
              setState(() {
                _selectedTag = tag;
                _selectedFolder = null;
              });
              Navigator.of(context).pop();
            },
            onSelectFolder: (folder) {
              setState(() {
                _selectedFolder = folder;
                _selectedTag = null;
              });
              Navigator.of(context).pop();
            },
          ),
          appBar: AppBar(
            title: const Text('All Notes'),
            leading: IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => _showQuickSearch(context),
              ),
              PopupMenuButton<_NotesListMenuAction>(
                onSelected: (value) {
                  if (value == _NotesListMenuAction.newNote) {
                    _openComposer(context);
                    return;
                  }
                  if (value == _NotesListMenuAction.showArchivedCount) {
                    final archivedCount = widget.controller.archivedNotes.length;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$archivedCount archived notes in your account.'),
                      ),
                    );
                    return;
                  }
                  if (value == _NotesListMenuAction.notesOverview) {
                    _showNotesOverview(context);
                    return;
                  }
                  if (value == _NotesListMenuAction.filterByTag) {
                    _pickFilterTag(context, allTags);
                    return;
                  }
                  _pickFilterFolder(context, allFolders);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _NotesListMenuAction.newNote,
                    child: Text('New note'),
                  ),
                  PopupMenuItem(
                    value: _NotesListMenuAction.notesOverview,
                    child: Text('Notes overview'),
                  ),
                  PopupMenuItem(
                    value: _NotesListMenuAction.filterByTag,
                    child: Text('Open tag filter'),
                  ),
                  PopupMenuItem(
                    value: _NotesListMenuAction.filterByFolder,
                    child: Text('Open folder filter'),
                  ),
                  PopupMenuItem(
                    value: _NotesListMenuAction.showArchivedCount,
                    child: Text('Archived notes count'),
                  ),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFFE7BD2A),
            onPressed: () => _openComposer(context),
            child: const Icon(Icons.add),
          ),
          body: !hasAnyNotes
              ? _EmptyState(onCreate: () => _openComposer(context))
              : ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    if (filterLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Chip(
                              avatar: const Icon(Icons.filter_alt_outlined, size: 16),
                              label: Text(filterLabel),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedTag = null;
                                  _selectedFolder = null;
                                });
                              },
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                      ),
                    if (pinned.isNotEmpty) const _SectionLabel(label: 'PINNED'),
                    ...pinned.asMap().entries.map((entry) {
                      final color = entry.key.isEven
                          ? const Color(0xFFFFF1B9)
                          : const Color(0xFFEDE5FF);
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _NormalNoteCard(
                          note: entry.value,
                          accentColor: color,
                          isPinned: true,
                          onTap: () => _openNote(context, entry.value),
                          onDelete: () => widget.controller.deleteNote(entry.value.id),
                          onToggleArchived: () =>
                              widget.controller.toggleArchived(entry.value.id),
                        ),
                      );
                    }),
                    if (others.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const _SectionLabel(label: 'NOTES'),
                    ],
                    ...others.asMap().entries.map((entry) {
                      final color = entry.key.isEven
                          ? const Color(0xFFF9FAFB)
                          : const Color(0xFFEAF5EC);
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _NormalNoteCard(
                          note: entry.value,
                          accentColor: color,
                          onTap: () => _openNote(context, entry.value),
                          onDelete: () => widget.controller.deleteNote(entry.value.id),
                          onToggleArchived: () =>
                              widget.controller.toggleArchived(entry.value.id),
                        ),
                      );
                    }),
                    if (archived.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const _SectionLabel(label: 'ARCHIVED'),
                    ],
                    ...archived.asMap().entries.map((entry) {
                      final color = entry.key.isEven
                          ? const Color(0xFFF0F1F5)
                          : const Color(0xFFE6E8EF);
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _NormalNoteCard(
                          note: entry.value,
                          accentColor: color,
                          isArchived: true,
                          onTap: () => _openNote(context, entry.value),
                          onDelete: () => widget.controller.deleteNote(entry.value.id),
                          onToggleArchived: () =>
                              widget.controller.toggleArchived(entry.value.id),
                        ),
                      );
                    }),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _openComposer(BuildContext context, {Note? note}) async {
    final draft = await Navigator.of(context).push<NoteDraft>(
      MaterialPageRoute<NoteDraft>(
        builder: (_) => NoteComposerPage(note: note),
      ),
    );
    if (draft == null) {
      return;
    }

    final savedId = await widget.controller.upsertNote(
      noteId: note?.id,
      title: draft.title,
      content: draft.content,
      noteType: draft.noteType,
      contentFormat: draft.contentFormat,
      checklistItems: draft.checklistItems,
    );

    if (!context.mounted) {
      return;
    }

    final latest = widget.controller.findById(savedId);
    final shouldPin = draft.isPinned;
    final currentlyPinned = latest?.isPinned ?? false;
    if (shouldPin != currentlyPinned) {
      await widget.controller.togglePinned(savedId);
    }
    await widget.controller.setTags(savedId, draft.tags);
    await widget.controller.setFolder(savedId, draft.folder);
  }

  void _showNotesOverview(BuildContext rootContext) {
    final active = widget.controller.activeNotes.length;
    final pinned = widget.controller.activeNotes.where((n) => n.isPinned).length;
    final archived = widget.controller.archivedNotes.length;
    showModalBottomSheet<void>(
      context: rootContext,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Notes Overview',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text('Active notes: $active'),
              Text('Pinned notes: $pinned'),
              Text('Archived notes: $archived'),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _openComposer(rootContext);
                },
                icon: const Icon(Icons.add),
                label: const Text('Create Note'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showQuickSearch(BuildContext rootContext) async {
    final queryController = TextEditingController();
    await showDialog<void>(
      context: rootContext,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final q = queryController.text.trim().toLowerCase();
            final results = widget.controller.allNotes.where((note) {
              final searchableContent = _notePlainText(note).toLowerCase();
              if (q.isEmpty) {
                return true;
              }
              return note.title.toLowerCase().contains(q) ||
                  searchableContent.contains(q) ||
                  note.tags.any((tag) => tag.toLowerCase().contains(q));
            }).toList();
            return AlertDialog(
              title: const Text('Quick Search'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: queryController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Type title, content, or tag',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 260,
                      child: results.isEmpty
                          ? const Center(child: Text('No matching notes'))
                          : ListView.separated(
                              itemCount: results.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final note = results[index];
                                return ListTile(
                                  title: Text(note.title),
                                  subtitle: Text(
                                    _notePreviewText(note),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    _openNote(rootContext, note);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
    queryController.dispose();
  }

  Future<void> _openNote(BuildContext context, Note note) async {
    final current = widget.controller.findById(note.id) ?? note;
    final result = await Navigator.of(context).push<NoteOpenResult>(
      MaterialPageRoute<NoteOpenResult>(
        builder: (_) => NoteOpenPage(note: current),
      ),
    );

    if (!context.mounted) {
      return;
    }

    if (result == null) {
      return;
    }

    switch (result.action) {
      case NoteOpenAction.edit:
        final latest = widget.controller.findById(note.id) ?? note;
        await _openComposer(context, note: latest);
        return;
      case NoteOpenAction.delete:
        await widget.controller.deleteNote(note.id);
        return;
      case NoteOpenAction.togglePin:
        await widget.controller.togglePinned(note.id);
        return;
      case NoteOpenAction.toggleArchive:
        await widget.controller.toggleArchived(note.id);
        return;
      case NoteOpenAction.updateTags:
        await widget.controller.setTags(note.id, result.tags ?? const []);
        return;
      case NoteOpenAction.updateFolder:
        await widget.controller.setFolder(note.id, result.folder);
        return;
    }
  }

  Future<void> _pickFilterTag(BuildContext context, List<String> tags) async {
    if (tags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tags available yet.')),
      );
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Filter by tag')),
            for (final tag in tags)
              ListTile(
                title: Text(tag),
                onTap: () => Navigator.of(context).pop(tag),
              ),
          ],
        );
      },
    );
    if (selected == null) {
      return;
    }
    setState(() {
      _selectedTag = selected;
      _selectedFolder = null;
    });
  }

  Future<void> _pickFilterFolder(BuildContext context, List<String> folders) async {
    if (folders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No folders available yet.')),
      );
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Filter by folder')),
            for (final folder in folders)
              ListTile(
                title: Text(folder),
                onTap: () => Navigator.of(context).pop(folder),
              ),
          ],
        );
      },
    );
    if (selected == null) {
      return;
    }
    setState(() {
      _selectedFolder = selected;
      _selectedTag = null;
    });
  }
}

enum _NotesListMenuAction {
  newNote,
  notesOverview,
  filterByTag,
  filterByFolder,
  showArchivedCount,
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.note_add_outlined, size: 48, color: Color(0xFF8F8AA2)),
            const SizedBox(height: 12),
            const Text(
              'No notes yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Create text notes, checklist notes, and scan notes.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create Note'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotesSidebar extends StatelessWidget {
  const _NotesSidebar({
    required this.selectedTag,
    required this.selectedFolder,
    required this.allTags,
    required this.allFolders,
    required this.onClearFilter,
    required this.onSelectTag,
    required this.onSelectFolder,
  });

  final String? selectedTag;
  final String? selectedFolder;
  final List<String> allTags;
  final List<String> allFolders;
  final VoidCallback onClearFilter;
  final ValueChanged<String> onSelectTag;
  final ValueChanged<String> onSelectFolder;

  @override
  Widget build(BuildContext context) {
    final hasFilter = selectedTag != null || selectedFolder != null;

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          children: [
            const ListTile(
              leading: Icon(Icons.sticky_note_2_outlined),
              title: Text('Notes Library'),
              subtitle: Text('Tags + folders'),
            ),
            if (hasFilter)
              ListTile(
                leading: const Icon(Icons.filter_alt_off_outlined),
                title: const Text('Clear active filter'),
                onTap: onClearFilter,
              ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text('Folders', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            if (allFolders.isEmpty)
              const ListTile(
                dense: true,
                title: Text('No folders yet'),
              )
            else
              for (final folder in allFolders)
                ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(folder),
                  trailing: selectedFolder == folder
                      ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () => onSelectFolder(folder),
                ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text('Tags', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            if (allTags.isEmpty)
              const ListTile(
                dense: true,
                title: Text('No tags yet'),
              )
            else
              for (final tag in allTags)
                ListTile(
                  leading: const Icon(Icons.sell_outlined),
                  title: Text(tag),
                  trailing: selectedTag == tag
                      ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () => onSelectTag(tag),
                ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        letterSpacing: 1,
        fontWeight: FontWeight.w700,
        color: Color(0xFF7A748A),
      ),
    );
  }
}

class _NormalNoteCard extends StatelessWidget {
  const _NormalNoteCard({
    required this.note,
    required this.onTap,
    required this.onDelete,
    required this.accentColor,
    required this.onToggleArchived,
    this.isPinned = false,
    this.isArchived = false,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggleArchived;
  final Color accentColor;
  final bool isPinned;
  final bool isArchived;

  @override
  Widget build(BuildContext context) {
    final preview = _notePreviewText(note);
    return Container(
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7E7EA)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (isPinned)
                    const Icon(
                      Icons.push_pin,
                      size: 14,
                      color: Color(0xFFE3A517),
                    ),
                  IconButton(
                    tooltip: isArchived ? 'Restore note' : 'Archive note',
                    icon: Icon(
                      isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                    ),
                    onPressed: onToggleArchived,
                  ),
                  IconButton(
                    tooltip: 'Delete note',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(_noteTypeLabel(note)),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (_isScanNote(note))
                    const Chip(
                      label: Text('Scan'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                preview,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF4D4A58)),
              ),
              const SizedBox(height: 8),
              Text(
                _relativeTime(note.updatedAt),
                style: const TextStyle(fontSize: 12, color: Color(0xFF7D778D)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _relativeTime(DateTime value) {
    final delta = DateTime.now().difference(value);
    if (delta.inMinutes < 1) {
      return 'just now';
    }
    if (delta.inMinutes < 60) {
      return '${delta.inMinutes}m ago';
    }
    if (delta.inHours < 24) {
      return '${delta.inHours}h ago';
    }
    return '${delta.inDays}d ago';
  }
}

List<ChecklistItem> _resolvedChecklistItems(Note note) {
  if (note.checklistItems.isNotEmpty) {
    return note.checklistItems;
  }

  final items = <ChecklistItem>[];
  for (final line in note.content.split('\n')) {
    if (line.startsWith('- [x] ')) {
      items.add(
        ChecklistItem(
          id: '${items.length}',
          text: line.substring(6),
          isChecked: true,
          order: items.length,
        ),
      );
    } else if (line.startsWith('- [ ] ')) {
      items.add(
        ChecklistItem(
          id: '${items.length}',
          text: line.substring(6),
          isChecked: false,
          order: items.length,
        ),
      );
    }
  }
  return items;
}

String _notePlainText(Note note) {
  if (note.noteType == NoteType.checklist) {
    return _resolvedChecklistItems(note)
        .map((item) => item.text)
        .where((text) => text.trim().isNotEmpty)
        .join('\n');
  }

  if (note.noteType == NoteType.richText) {
    try {
      final decoded = jsonDecode(note.content);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map((operation) => operation['insert'])
            .whereType<String>()
            .join();
      }
    } catch (_) {
      return note.content;
    }
  }

  if (_isScanNote(note)) {
    return note.content.replaceFirst('[scan]\n', '');
  }

  return note.content;
}

String _notePreviewText(Note note) {
  return _notePlainText(note).replaceAll('\n', ' ').trim();
}

String _noteTypeLabel(Note note) {
  switch (note.noteType) {
    case NoteType.text:
      return 'Text';
    case NoteType.checklist:
      return 'Checklist';
    case NoteType.richText:
      return 'Rich text';
  }
}

bool _isScanNote(Note note) => note.content.startsWith('[scan]\n');
