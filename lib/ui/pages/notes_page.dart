import 'dart:convert';

import 'package:flutter/material.dart';

import '../../controllers/notes_controller.dart';
import '../../models/checklist_item.dart';
import '../../models/note.dart';
import 'note_composer_page.dart';
import 'note_open_page.dart';

const _kAccentColors = [
  Color(0xFFF5C252),
  Color(0xFF9B8FEF),
  Color(0xFF52C988),
  Color(0xFF4A9EE5),
  Color(0xFFE8767F),
  Color(0xFF4CC9B0),
];

class NotesPage extends StatefulWidget {
  const NotesPage({super.key, required this.controller});

  final NotesController controller;

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _typeFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesNote(Note note) {
    if (_typeFilter != null) {
      if (_typeFilter == 'checklist' && note.noteType != NoteType.checklist) {
        return false;
      }
      if (_typeFilter == 'scan' && !_isScanNote(note)) {
        return false;
      }
      if (_typeFilter == 'text' && (note.noteType != NoteType.text || _isScanNote(note))) {
        return false;
      }
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      if (!note.title.toLowerCase().contains(q) &&
          !_notePlainText(note).toLowerCase().contains(q) &&
          !note.tags.any((t) => t.toLowerCase().contains(q))) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        if (widget.controller.isLoading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final activeSource = widget.controller.activeNotes.where(_matchesNote).toList();
        final archivedSource = widget.controller.archivedNotes.where(_matchesNote).toList();
        final pinned = activeSource.where((n) => n.isPinned).toList();
        final others = activeSource.where((n) => !n.isPinned).toList();
        final hasAnyNotes = widget.controller.activeNotes.isNotEmpty ||
            widget.controller.archivedNotes.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'NoteVault',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
            ),
            actions: [
              PopupMenuButton<_NotesMenuAction>(
                onSelected: (value) {
                  if (value == _NotesMenuAction.overview) {
                    _showNotesOverview(context);
                    return;
                  }
                  final count = widget.controller.archivedNotes.length;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$count archived notes.')),
                  );
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _NotesMenuAction.overview,
                    child: Text('Notes overview'),
                  ),
                  PopupMenuItem(
                    value: _NotesMenuAction.archivedCount,
                    child: Text('Archived count'),
                  ),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openComposer(context),
            child: const Icon(Icons.add),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (q) => setState(() => _searchQuery = q.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search notes...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE0DFF3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE0DFF3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(
                  children: [
                    _TypeFilterChip(
                      label: 'All',
                      icon: Icons.notes_outlined,
                      selected: _typeFilter == null,
                      onTap: () => setState(() => _typeFilter = null),
                    ),
                    const SizedBox(width: 8),
                    _TypeFilterChip(
                      label: 'Text',
                      icon: Icons.text_fields_outlined,
                      selected: _typeFilter == 'text',
                      onTap: () => setState(() => _typeFilter = 'text'),
                    ),
                    const SizedBox(width: 8),
                    _TypeFilterChip(
                      label: 'Checklist',
                      icon: Icons.check_box_outlined,
                      selected: _typeFilter == 'checklist',
                      onTap: () => setState(() => _typeFilter = 'checklist'),
                    ),
                    const SizedBox(width: 8),
                    _TypeFilterChip(
                      label: 'Scan',
                      icon: Icons.document_scanner_outlined,
                      selected: _typeFilter == 'scan',
                      onTap: () => setState(() => _typeFilter = 'scan'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: !hasAnyNotes
                    ? _EmptyState(onCreate: () => _openComposer(context))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                        children: [
                          if (pinned.isNotEmpty) ...[
                            const _SectionLabel(label: 'PINNED'),
                            const SizedBox(height: 8),
                            ...pinned.asMap().entries.map(
                                  (entry) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _NoteCard(
                                      note: entry.value,
                                      accentColor:
                                          _kAccentColors[entry.key % _kAccentColors.length],
                                      isPinned: true,
                                      onTap: () => _openNote(context, entry.value),
                                      onDelete: () =>
                                          widget.controller.deleteNote(entry.value.id),
                                      onToggleArchived: () =>
                                          widget.controller.toggleArchived(entry.value.id),
                                    ),
                                  ),
                                ),
                          ],
                          if (others.isNotEmpty) ...[
                            if (pinned.isNotEmpty) const SizedBox(height: 4),
                            const _SectionLabel(label: 'NOTES'),
                            const SizedBox(height: 8),
                            ...others.asMap().entries.map(
                                  (entry) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _NoteCard(
                                      note: entry.value,
                                      accentColor:
                                          _kAccentColors[entry.key % _kAccentColors.length],
                                      onTap: () => _openNote(context, entry.value),
                                      onDelete: () =>
                                          widget.controller.deleteNote(entry.value.id),
                                      onToggleArchived: () =>
                                          widget.controller.toggleArchived(entry.value.id),
                                    ),
                                  ),
                                ),
                          ],
                          if (archivedSource.isNotEmpty) ...[
                            if (pinned.isNotEmpty || others.isNotEmpty)
                              const SizedBox(height: 4),
                            const _SectionLabel(label: 'ARCHIVED'),
                            const SizedBox(height: 8),
                            ...archivedSource.asMap().entries.map(
                                  (entry) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _NoteCard(
                                      note: entry.value,
                                      accentColor: const Color(0xFFCCCAD5),
                                      isArchived: true,
                                      onTap: () => _openNote(context, entry.value),
                                      onDelete: () =>
                                          widget.controller.deleteNote(entry.value.id),
                                      onToggleArchived: () =>
                                          widget.controller.toggleArchived(entry.value.id),
                                    ),
                                  ),
                                ),
                          ],
                        ],
                      ),
              ),
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
    if (draft == null) return;

    final savedId = await widget.controller.upsertNote(
      noteId: note?.id,
      title: draft.title,
      content: draft.content,
      noteType: draft.noteType,
      contentFormat: draft.contentFormat,
      checklistItems: draft.checklistItems,
    );

    if (!context.mounted) return;

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

  Future<void> _openNote(BuildContext context, Note note) async {
    final current = widget.controller.findById(note.id) ?? note;
    final result = await Navigator.of(context).push<NoteOpenResult>(
      MaterialPageRoute<NoteOpenResult>(
        builder: (_) => NoteOpenPage(note: current),
      ),
    );

    if (!context.mounted) return;
    if (result == null) return;

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
}

enum _NotesMenuAction { overview, archivedCount }

// ── Stateless widgets ────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.note_add_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary.withValues(alpha:0.35),
            ),
            const SizedBox(height: 14),
            const Text(
              'No notes yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Capture thoughts, checklists, and scanned documents.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF7A778A)),
            ),
            const SizedBox(height: 20),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.38),
      ),
    );
  }
}

class _TypeFilterChip extends StatelessWidget {
  const _TypeFilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? primary.withValues(alpha:0.1) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? primary : const Color(0xFFDDDCEA)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: selected ? primary : const Color(0xFF7A778A)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: selected ? primary : const Color(0xFF7A778A),
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.accentColor,
    required this.onTap,
    required this.onDelete,
    required this.onToggleArchived,
    this.isPinned = false,
    this.isArchived = false,
  });

  final Note note;
  final Color accentColor;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggleArchived;
  final bool isPinned;
  final bool isArchived;

  String _relativeTime(DateTime value) {
    final delta = DateTime.now().difference(value);
    if (delta.inMinutes < 1) return 'just now';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
    if (delta.inHours < 24) return '${delta.inHours}h ago';
    return '${delta.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final preview = _notePreviewText(note);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFECEBF3)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: accentColor),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 4, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  note.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 15),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isPinned)
                                const Padding(
                                  padding: EdgeInsets.only(right: 2),
                                  child: Icon(Icons.push_pin,
                                      size: 13, color: Color(0xFFE3A517)),
                                ),
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: IconButton(
                                  tooltip: isArchived ? 'Restore' : 'Archive',
                                  icon: Icon(
                                    isArchived
                                        ? Icons.unarchive_outlined
                                        : Icons.archive_outlined,
                                    size: 16,
                                  ),
                                  padding: EdgeInsets.zero,
                                  onPressed: onToggleArchived,
                                ),
                              ),
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: IconButton(
                                  tooltip: 'Delete',
                                  icon: const Icon(Icons.delete_outline, size: 16),
                                  padding: EdgeInsets.zero,
                                  onPressed: onDelete,
                                ),
                              ),
                            ],
                          ),
                          if (preview.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              preview,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Color(0xFF6D6A79), fontSize: 13, height: 1.4),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _NoteBadge(note: note),
                              const Spacer(),
                              Text(
                                _relativeTime(note.updatedAt),
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF9B97A8)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteBadge extends StatelessWidget {
  const _NoteBadge({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final String label;
    if (note.noteType == NoteType.checklist) {
      icon = Icons.check_box_outlined;
      label = 'Checklist';
    } else if (_isScanNote(note)) {
      icon = Icons.document_scanner_outlined;
      label = 'Scan';
    } else if (note.noteType == NoteType.richText) {
      icon = Icons.format_shapes_outlined;
      label = 'Rich';
    } else {
      icon = Icons.text_fields_outlined;
      label = 'Text';
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: const Color(0xFF9B97A8)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF9B97A8))),
      ],
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

List<ChecklistItem> _resolvedChecklistItems(Note note) {
  if (note.checklistItems.isNotEmpty) return note.checklistItems;
  final items = <ChecklistItem>[];
  for (final line in note.content.split('\n')) {
    if (line.startsWith('- [x] ')) {
      items.add(ChecklistItem(
          id: '${items.length}',
          text: line.substring(6),
          isChecked: true,
          order: items.length));
    } else if (line.startsWith('- [ ] ')) {
      items.add(ChecklistItem(
          id: '${items.length}',
          text: line.substring(6),
          isChecked: false,
          order: items.length));
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
            .map((op) => op['insert'])
            .whereType<String>()
            .join();
      }
    } catch (_) {
      return note.content;
    }
  }
  if (_isScanNote(note)) return note.content.replaceFirst('[scan]\n', '');
  return note.content;
}

String _notePreviewText(Note note) => _notePlainText(note).replaceAll('\n', ' ').trim();

bool _isScanNote(Note note) => note.content.startsWith('[scan]\n');
