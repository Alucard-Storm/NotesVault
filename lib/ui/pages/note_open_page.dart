import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/checklist_item.dart';
import '../../models/note.dart';
import '../components/checklist_note_editor.dart';
import '../components/rich_text_editor.dart';

class NoteOpenPage extends StatefulWidget {
  const NoteOpenPage({super.key, required this.note});

  final Note note;

  @override
  State<NoteOpenPage> createState() => _NoteOpenPageState();
}

class _NoteOpenPageState extends State<NoteOpenPage> {
  Future<void> _promptTagEdit() async {
    final controller = TextEditingController(text: widget.note.tags.join(', '));
    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit tags'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'work, ideas, personal',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (value == null || !mounted) {
      return;
    }
    final tags = value.split(',').map((item) => item.trim()).toList();
    Navigator.of(context).pop(
      NoteOpenResult(
        action: NoteOpenAction.updateTags,
        tags: tags,
      ),
    );
  }

  Future<void> _setReadReminder() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      initialDate: now,
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null || !mounted) {
      return;
    }
    final reminder = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    await Clipboard.setData(
      ClipboardData(text: '[reminder] ${reminder.toIso8601String()}'),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reminder token copied. Edit note to save it in content.'),
      ),
    );
  }

  Future<void> _promptFolderEdit() async {
    final controller = TextEditingController(text: widget.note.folder ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit folder'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Personal, Work, Projects'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(''),
              child: const Text('Clear'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (value == null || !mounted) {
      return;
    }
    Navigator.of(context).pop(
      NoteOpenResult(
        action: NoteOpenAction.updateFolder,
        folder: value.trim().isEmpty ? null : value.trim(),
      ),
    );
  }

  void _showColorThemes() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Color styles'),
                subtitle: Text('Pick a style and it will be copied for quick tagging.'),
              ),
              Wrap(
                spacing: 10,
                children: [
                  _ThemeChip(label: 'Priority', color: const Color(0xFFFFF1B9)),
                  _ThemeChip(label: 'Ideas', color: const Color(0xFFEDE5FF)),
                  _ThemeChip(label: 'Daily', color: const Color(0xFFEAF5EC)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _shareAsClipboard() async {
    await Clipboard.setData(
      ClipboardData(text: '${widget.note.title}\n\n${_notePlainText(widget.note)}'),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Note copied to clipboard.')),
    );
  }

  Widget _buildNoteBody() {
    if (widget.note.noteType == NoteType.checklist) {
      return Column(
        children: [
          Expanded(
            child: ChecklistNoteViewer(items: _resolvedChecklistItems(widget.note)),
          ),
          const SizedBox(height: 8),
          _NoteInsightsCard(note: widget.note),
        ],
      );
    }

    if (widget.note.noteType == NoteType.richText) {
      return Column(
        children: [
          Expanded(child: RichTextViewer(content: widget.note.content)),
          const SizedBox(height: 8),
          _NoteInsightsCard(note: widget.note),
        ],
      );
    }

    final lines = _notePlainText(widget.note)
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();

    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(line),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _NoteInsightsCard(note: widget.note),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tagChips = widget.note.tags;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              widget.note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            ),
            onPressed: () {
              Navigator.of(context).pop(
                const NoteOpenResult(action: NoteOpenAction.togglePin),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: _setReadReminder,
          ),
          PopupMenuButton<NoteOpenAction>(
            onSelected: (value) {
              if (value == NoteOpenAction.updateTags) {
                _promptTagEdit();
                return;
              }
              if (value == NoteOpenAction.updateFolder) {
                _promptFolderEdit();
                return;
              }
              Navigator.of(context).pop(NoteOpenResult(action: value));
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: NoteOpenAction.edit, child: Text('Edit')),
              PopupMenuItem(
                value: NoteOpenAction.togglePin,
                child: Text(widget.note.isPinned ? 'Unpin' : 'Pin'),
              ),
              PopupMenuItem(
                value: NoteOpenAction.toggleArchive,
                child: Text(widget.note.isArchived ? 'Unarchive' : 'Archive'),
              ),
              const PopupMenuItem(
                value: NoteOpenAction.updateTags,
                child: Text('Edit tags'),
              ),
              const PopupMenuItem(
                value: NoteOpenAction.updateFolder,
                child: Text('Edit folder'),
              ),
              const PopupMenuItem(
                value: NoteOpenAction.delete,
                child: Text('Delete (from list)'),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.note.title,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (widget.note.folder != null)
                  Chip(label: Text('Folder: ${widget.note.folder}')),
                if (tagChips.isEmpty)
                  const Chip(label: Text('No tags'))
                else
                  for (final tag in tagChips) Chip(label: Text(tag)),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _buildNoteBody(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: _showColorThemes,
              icon: const Icon(Icons.palette_outlined),
            ),
            IconButton(
              onPressed: _promptTagEdit,
              icon: const Icon(Icons.label_outline),
            ),
            IconButton(
              onPressed: _shareAsClipboard,
              icon: const Icon(Icons.share_outlined),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(
                const NoteOpenResult(action: NoteOpenAction.edit),
              ),
              icon: const Icon(Icons.edit),
              label: const Text('Edit'),
            ),
          ],
        ),
      ),
    );
  }
}

enum NoteOpenAction {
  edit,
  togglePin,
  toggleArchive,
  updateTags,
  updateFolder,
  delete,
}

class NoteOpenResult {
  const NoteOpenResult({required this.action, this.tags, this.folder});

  final NoteOpenAction action;
  final List<String>? tags;
  final String? folder;
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: label.toLowerCase()));
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label tag copied to clipboard.')),
        );
      },
      child: Chip(
        avatar: CircleAvatar(backgroundColor: color),
        label: Text(label),
      ),
    );
  }
}

class _NoteInsightsCard extends StatelessWidget {
  const _NoteInsightsCard({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final plainText = _notePlainText(note);
    final lines = plainText.split('\n').where((line) => line.trim().isNotEmpty).toList();
    final words = plainText
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .length;
    final checklistItems = _resolvedChecklistItems(note);
    final checklistDone = checklistItems.where((item) => item.isChecked).length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Note Insights',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text('Type: ${_noteTypeLabel(note)}'),
          Text('Lines: ${lines.length}'),
          Text('Words: $words'),
          Text('Checklist: $checklistDone / ${checklistItems.length} done'),
          Text('Updated: ${note.updatedAt.toLocal()}'),
        ],
      ),
    );
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
