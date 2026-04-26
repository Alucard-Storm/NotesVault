import 'package:flutter/material.dart';

import '../../models/checklist_item.dart';
import '../../models/note.dart';
import '../components/checklist_note_editor.dart';
import '../components/rich_text_editor.dart';
import 'document_scanner_page.dart';

class NoteComposerPage extends StatefulWidget {
  const NoteComposerPage({super.key, required this.note});

  final Note? note;

  @override
  State<NoteComposerPage> createState() => _NoteComposerPageState();
}

class _NoteComposerPageState extends State<NoteComposerPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _scanController;
  late String _richTextContent;
  int _modeIndex = 0;
  final List<ChecklistItem> _checklist = [];
  List<String> _tags = const [];
  String? _folder;
  bool _isPinned = false;
  DateTime? _reminderAt;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    final initialContent = widget.note?.content ?? '';
    _contentController = TextEditingController(text: initialContent);
    _scanController = TextEditingController();
    _richTextContent = widget.note?.noteType == NoteType.richText ? initialContent : '';
    _tags = widget.note?.tags ?? const [];
    _folder = widget.note?.folder;
    _isPinned = widget.note?.isPinned ?? false;

    if (widget.note?.noteType == NoteType.richText) {
      _modeIndex = 2;
    } else if (initialContent.startsWith('[scan]\n')) {
      _modeIndex = 3;
      _scanController.text = initialContent.replaceFirst('[scan]\n', '');
    } else if (widget.note?.noteType == NoteType.checklist) {
      _modeIndex = 1;
      if (widget.note != null && widget.note!.checklistItems.isNotEmpty) {
        _checklist.addAll(widget.note!.checklistItems);
      } else {
        _checklist.addAll(_parseLegacyChecklist(initialContent));
      }
    } else if (initialContent.contains('- [ ]') || initialContent.contains('- [x]')) {
      _modeIndex = 1;
      _checklist.addAll(_parseLegacyChecklist(initialContent));
    }
  }

  List<ChecklistItem> _parseLegacyChecklist(String content) {
    final items = <ChecklistItem>[];
    for (final line in content.split('\n')) {
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

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modeTabs = ['Text', 'Checklist', 'Rich text', 'Scan'];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(_isPinned ? Icons.push_pin : Icons.push_pin_outlined),
            tooltip: _isPinned ? 'Unpin note' : 'Pin note',
            onPressed: () => setState(() => _isPinned = !_isPinned),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Set reminder',
            onPressed: _pickReminder,
          ),
          PopupMenuButton<_ComposerMenuAction>(
            onSelected: (action) {
              if (action == _ComposerMenuAction.clearContent) {
                setState(() {
                  _contentController.clear();
                  _scanController.clear();
                  _richTextContent = '';
                  _checklist.clear();
                });
                return;
              }
              if (action == _ComposerMenuAction.editTags) {
                _editTags();
                return;
              }
              _editFolder();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _ComposerMenuAction.editTags,
                child: Text('Edit tags'),
              ),
              PopupMenuItem(
                value: _ComposerMenuAction.editFolder,
                child: Text('Edit folder'),
              ),
              PopupMenuItem(
                value: _ComposerMenuAction.clearContent,
                child: Text('Clear content'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SegmentedButton<int>(
              segments: [
                for (var index = 0; index < modeTabs.length; index++)
                  ButtonSegment<int>(value: index, label: Text(modeTabs[index])),
              ],
              selected: {_modeIndex},
              onSelectionChanged: (set) => setState(() => _modeIndex = set.first),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: _modeIndex == 0
                  ? _buildTextEditor()
                  : _modeIndex == 1
                      ? _buildChecklistEditor()
                      : _modeIndex == 2
                          ? _buildRichTextEditor()
                          : _buildScanEditor(),
            ),
          ),
        ],
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
              onPressed: () => setState(() => _modeIndex = 1),
              icon: const Icon(Icons.check_box_outlined),
              tooltip: 'Checklist mode',
            ),
            IconButton(
              onPressed: () => setState(() => _modeIndex = 2),
              icon: const Icon(Icons.format_shapes_outlined),
              tooltip: 'Rich text mode',
            ),
            IconButton(
              onPressed: _scanDocument,
              icon: const Icon(Icons.document_scanner_outlined),
              tooltip: 'Scan document',
            ),
            IconButton(
              onPressed: _insertVoiceMemo,
              icon: const Icon(Icons.mic_none),
              tooltip: 'Insert voice memo line',
            ),
            IconButton(
              onPressed: _insertSketchMarker,
              icon: const Icon(Icons.draw_outlined),
              tooltip: 'Insert sketch marker',
            ),
            const Spacer(),
            FilledButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }

  Widget _buildTextEditor() {
    return Column(
      children: [
        TextField(
          controller: _titleController,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Title',
          ),
        ),
        Expanded(
          child: TextField(
            controller: _contentController,
            maxLines: null,
            expands: true,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Start writing...',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistEditor() {
    return Column(
      children: [
        TextField(
          controller: _titleController,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Checklist title',
          ),
        ),
        Expanded(
          child: ChecklistNoteEditor(
            items: _checklist,
            onChanged: (items) {
              _checklist
                ..clear()
                ..addAll(items);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRichTextEditor() {
    return Column(
      children: [
        TextField(
          controller: _titleController,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Rich text title',
          ),
        ),
        Expanded(
          child: RichTextEditor(
            initialContent: _richTextContent,
            onChanged: (content) {
              _richTextContent = content;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildScanEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: _scanDocument,
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Scan document'),
            ),
            const SizedBox(width: 10),
            TextButton(
              onPressed: _pasteScannedText,
              child: const Text('Paste text'),
            ),
            TextButton(
              onPressed: () => _scanController.clear(),
              child: const Text('Clear'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _scanController,
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Paste or type scanned text here...',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickReminder() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      initialDate: now,
    );
    if (pickedDate == null || !mounted) {
      return;
    }
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (pickedTime == null || !mounted) {
      return;
    }
    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    setState(() => _reminderAt = combined);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reminder set for ${combined.toLocal()}')),
    );
  }

  Future<void> _editTags() async {
    final controller = TextEditingController(text: _tags.join(', '));
    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit tags'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'work, personal, ideas'),
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
    setState(() {
      _tags = value
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList();
    });
  }

  Future<void> _editFolder() async {
    final controller = TextEditingController(text: _folder ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit folder'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Personal, Work, Projects',
            ),
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
    setState(() {
      final normalized = value.trim();
      _folder = normalized.isEmpty ? null : normalized;
    });
  }

  void _insertVoiceMemo() {
    final now = DateTime.now();
    setState(() {
      _modeIndex = 0;
      _contentController.text =
          '${_contentController.text}\n[voice] memo ${now.toLocal()}'.trim();
    });
  }

  void _insertSketchMarker() {
    setState(() {
      _modeIndex = 0;
      _contentController.text = '${_contentController.text}\n[sketch]'.trim();
    });
  }

  Future<void> _pasteScannedText() async {
    final controller = TextEditingController(text: _scanController.text);
    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Scanned text'),
          content: TextField(
            controller: controller,
            minLines: 4,
            maxLines: 10,
            decoration: const InputDecoration(hintText: 'Paste OCR output here'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Use text'),
            ),
          ],
        );
      },
    );
    if (value == null) {
      return;
    }
    setState(() => _scanController.text = value.trim());
  }

  Future<void> _scanDocument() async {
    final result = await Navigator.of(context).push<DocumentScanResult>(
      MaterialPageRoute<DocumentScanResult>(
        builder: (_) => const DocumentScannerPage(),
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      _modeIndex = 3;
      _scanController.text = result.extractedText.trim();
    });
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }

    String content;
    NoteType noteType;
    String contentFormat = 'plain';
    List<ChecklistItem> checklistItems = const [];

    if (_modeIndex == 1) {
      noteType = NoteType.checklist;
      checklistItems = _checklist
          .where((item) => item.text.trim().isNotEmpty)
          .toList(growable: false);
      content = checklistItems
          .map((item) => item.isChecked ? '- [x] ${item.text}' : '- [ ] ${item.text}')
          .join('\n');
    } else if (_modeIndex == 2) {
      noteType = NoteType.richText;
      contentFormat = 'rich';
      content = _richTextContent.trim();
    } else if (_modeIndex == 3) {
      noteType = NoteType.text;
      final scanText = _scanController.text.trim();
      content = '[scan]\n$scanText';
    } else {
      noteType = NoteType.text;
      content = _contentController.text.trim();
    }

    if (_reminderAt != null && noteType != NoteType.richText) {
      content = '$content\n\n[reminder] ${_reminderAt!.toIso8601String()}';
    }

    if (content.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      NoteDraft(
        title: title,
        content: content,
        noteType: noteType,
        contentFormat: contentFormat,
        checklistItems: checklistItems,
        isPinned: _isPinned,
        tags: _tags,
        folder: _folder,
      ),
    );
  }
}

class NoteDraft {
  const NoteDraft({
    required this.title,
    required this.content,
    required this.noteType,
    required this.contentFormat,
    required this.checklistItems,
    required this.isPinned,
    required this.tags,
    required this.folder,
  });

  final String title;
  final String content;
  final NoteType noteType;
  final String contentFormat;
  final List<ChecklistItem> checklistItems;
  final bool isPinned;
  final List<String> tags;
  final String? folder;
}

enum _ComposerMenuAction { editTags, editFolder, clearContent }
