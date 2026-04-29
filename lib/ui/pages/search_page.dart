import 'dart:convert';

import 'package:flutter/material.dart';

import '../../controllers/notes_controller.dart';
import '../../controllers/vault_controller.dart';
import '../../models/checklist_item.dart';
import '../../models/note.dart';
import '../../services/ai_study_service.dart';
import '../../services/semantic_search_service.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    required this.notesController,
    required this.vaultController,
  });

  final NotesController notesController;
  final VaultController vaultController;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final SemanticSearchService _semanticSearch = const SemanticSearchService();
  final AiStudyService _aiStudyService = const AiStudyService();
  final TextEditingController _queryController = TextEditingController();
  List<_SearchResult> _vaultResults = const [];
  bool _loadingVaultResults = false;

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_refreshVaultResults);
    widget.notesController.addListener(_onDataChanged);
    widget.vaultController.addListener(_onDataChanged);
    _refreshVaultResults();
  }

  void _onDataChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
    _refreshVaultResults();
  }

  @override
  void dispose() {
    _queryController
      ..removeListener(_refreshVaultResults)
      ..dispose();
    widget.notesController.removeListener(_onDataChanged);
    widget.vaultController.removeListener(_onDataChanged);
    super.dispose();
  }

  Future<void> _refreshVaultResults() async {
    final query = _queryController.text.trim().toLowerCase();
    if (!mounted) {
      return;
    }
    setState(() => _loadingVaultResults = true);

    final results = <_SearchResult>[];
    for (final vault in widget.vaultController.vaults) {
      if (vault.isLocked) {
        continue;
      }
      final secureNotes = widget.vaultController.notesForVault(vault.id);
      for (final secureNote in secureNotes) {
        final decrypted = await widget.vaultController.decryptNote(secureNote);
        final matches = query.isEmpty ||
            decrypted.title.toLowerCase().contains(query) ||
            decrypted.content.toLowerCase().contains(query);
        if (!matches) {
          continue;
        }
        results.add(
          _SearchResult(
            title: decrypted.title,
            snippet: decrypted.content,
            sourceLabel: 'Vault: ${vault.name}',
          ),
        );
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _vaultResults = results;
      _loadingVaultResults = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _queryController.text.trim().toLowerCase();
    final semanticMatches = _semanticSearch.rankNotes(
      query: query,
      notes: widget.notesController.allNotes,
      plainText: _notePlainText,
    );

    final noteResults = (query.isEmpty ? widget.notesController.allNotes : semanticMatches.map((m) => m.note)).where((note) {
      final searchableContent = _notePlainText(note).toLowerCase();
      if (query.isEmpty) {
        return true;
      }
      return note.title.toLowerCase().contains(query) ||
          searchableContent.contains(query) ||
          note.tags.any((tag) => tag.toLowerCase().contains(query));
    }).map((note) {
      final tagsLabel = note.tags.isEmpty ? 'No tags' : note.tags.join(', ');
      return _SearchResult(
        title: note.title,
        snippet: _notePreviewText(note),
        sourceLabel: 'Notes · $tagsLabel',
        onGenerateStudyAid: () => _showStudyAid(context, note),
      );
    }).toList();

    final allResults = [...noteResults, ..._vaultResults];

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              controller: _queryController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search notes and unlocked vault notes',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _queryController.clear();
                          setState(() {});
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          Expanded(
            child: _loadingVaultResults
                ? const Center(child: CircularProgressIndicator())
                : allResults.isEmpty
                    ? const Center(child: Text('No matches found.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: allResults.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final result = allResults[index];
                          return Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE6FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2DDF0)),
                            ),
                            child: ListTile(
                              title: Text(
                                result.title,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                '${result.sourceLabel}\n${result.snippet}',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: result.onGenerateStudyAid == null ? null : IconButton(icon: const Icon(Icons.auto_awesome_outlined), onPressed: result.onGenerateStudyAid),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _showStudyAid(BuildContext context, Note note) async {
    final summary = _aiStudyService.summarize(_notePlainText(note));
    final questions = _aiStudyService.generateExamQuestions(_notePlainText(note));
    final flashcards = _aiStudyService.flashcards(_notePlainText(note));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Study Assist: ${note.title}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text('Summary: $summary'),
              const SizedBox(height: 12),
              const Text(
                'Exam questions',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...questions.map((q) => Text('• $q')),
              const SizedBox(height: 12),
              const Text(
                'Flashcards',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...flashcards.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(f),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class _SearchResult {
  const _SearchResult({
    required this.title,
    required this.snippet,
    required this.sourceLabel,
    this.onGenerateStudyAid,
  });

  final String title;
  final String snippet;
  final String sourceLabel;
  final VoidCallback? onGenerateStudyAid;
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

bool _isScanNote(Note note) => note.content.startsWith('[scan]\n');
