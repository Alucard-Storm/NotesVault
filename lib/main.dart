import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'controllers/notes_controller.dart';
import 'controllers/vault_controller.dart';
import 'core/di/service_locator.dart';
import 'models/checklist_item.dart';
import 'models/note.dart';
import 'models/secure_note.dart';
import 'models/vault.dart';
import 'services/android_keystore_service.dart';
import 'services/local_auth_service.dart';
import 'services/notes_repository.dart';
import 'services/vault_repository.dart';
import 'ui/components/checklist_note_editor.dart';
import 'ui/components/rich_text_editor.dart';
import 'ui/pages/document_scanner_page.dart';
import 'ui/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupDependencies();
  runApp(const NoteVaultApp());
}

class NoteVaultApp extends StatefulWidget {
  const NoteVaultApp({super.key});

  @override
  State<NoteVaultApp> createState() => _NoteVaultAppState();
}

class _NoteVaultAppState extends State<NoteVaultApp>
    with WidgetsBindingObserver {
  static const MethodChannel _securityChannel =
      MethodChannel('notevault/security');
  static const String _themeModeKey = 'theme_mode';
  static const String _autoLockSecondsKey = 'vault_auto_lock_seconds';

  late final NotesController _notesController;
  late final VaultController _vaultController;
  bool _isDarkMode = false;
  int _autoLockSeconds = 60;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notesController = NotesController(repository: NotesRepository());
    _vaultController = VaultController(
      repository: VaultRepository(),
      keystoreService: AndroidKeystoreService(),
      authService: LocalAuthService(),
    );
    _notesController.initialize();
    _vaultController.initialize();
    _configureAndroidSecurity();
    _loadAppPreferences();
  }

  Future<void> _loadAppPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_themeModeKey);
    final seconds = prefs.getInt(_autoLockSecondsKey) ?? 60;
    _vaultController.setAutoLockDuration(Duration(seconds: seconds));
    if (!mounted) {
      return;
    }
    setState(() {
      _isDarkMode = mode == 'dark';
      _autoLockSeconds = seconds;
    });
  }

  Future<void> _setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, value ? 'dark' : 'light');
    if (!mounted) {
      return;
    }
    setState(() {
      _isDarkMode = value;
    });
  }

  Future<void> _setAutoLockSeconds(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoLockSecondsKey, seconds);
    _vaultController.setAutoLockDuration(Duration(seconds: seconds));
    if (!mounted) {
      return;
    }
    setState(() {
      _autoLockSeconds = seconds;
    });
  }

  Future<void> _configureAndroidSecurity() async {
    if (!Platform.isAndroid) {
      return;
    }
    await _securityChannel.invokeMethod<void>('setSecureFlag');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _vaultController.lockAllVaults();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notesController.dispose();
    _vaultController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NoteVault',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: NoteVaultShell(
        notesController: _notesController,
        vaultController: _vaultController,
        isDarkMode: _isDarkMode,
        onThemeChanged: _setDarkMode,
        autoLockSeconds: _autoLockSeconds,
        onAutoLockChanged: _setAutoLockSeconds,
      ),
    );
  }
}

class NoteVaultShell extends StatefulWidget {
  const NoteVaultShell({
    super.key,
    required this.notesController,
    required this.vaultController,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.autoLockSeconds,
    required this.onAutoLockChanged,
  });

  final NotesController notesController;
  final VaultController vaultController;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final int autoLockSeconds;
  final ValueChanged<int> onAutoLockChanged;

  @override
  State<NoteVaultShell> createState() => _NoteVaultShellState();
}

class _NoteVaultShellState extends State<NoteVaultShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      NotesPage(controller: widget.notesController),
      SearchPage(
        notesController: widget.notesController,
        vaultController: widget.vaultController,
      ),
      VaultPage(controller: widget.vaultController),
      SettingsPage(
        controller: widget.vaultController,
        isDarkMode: widget.isDarkMode,
        onThemeChanged: widget.onThemeChanged,
        autoLockSeconds: widget.autoLockSeconds,
        onAutoLockChanged: widget.onAutoLockChanged,
      ),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.sticky_note_2_outlined), label: 'Notes'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.lock_outline), label: 'Vault'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}

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
                    if (pinned.isNotEmpty)
                      const _SectionLabel(label: 'PINNED'),
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
    final draft = await Navigator.of(context).push<_NoteDraft>(
      MaterialPageRoute<_NoteDraft>(
        builder: (_) => _NoteComposerPage(note: note),
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
    final result = await Navigator.of(context).push<_NoteOpenResult>(
      MaterialPageRoute<_NoteOpenResult>(
        builder: (_) => _NoteOpenPage(note: current),
      ),
    );

    if (!context.mounted) {
      return;
    }

    if (result == null) {
      return;
    }

    switch (result.action) {
      case _NoteOpenAction.edit:
        final latest = widget.controller.findById(note.id) ?? note;
        await _openComposer(context, note: latest);
        return;
      case _NoteOpenAction.delete:
        await widget.controller.deleteNote(note.id);
        return;
      case _NoteOpenAction.togglePin:
        await widget.controller.togglePinned(note.id);
        return;
      case _NoteOpenAction.toggleArchive:
        await widget.controller.toggleArchived(note.id);
        return;
      case _NoteOpenAction.updateTags:
        await widget.controller.setTags(note.id, result.tags ?? const []);
        return;
      case _NoteOpenAction.updateFolder:
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
    final noteResults = widget.notesController.allNotes.where((note) {
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
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _SearchResult {
  const _SearchResult({
    required this.title,
    required this.snippet,
    required this.sourceLabel,
  });

  final String title;
  final String snippet;
  final String sourceLabel;
}

class VaultPage extends StatelessWidget {
  const VaultPage({super.key, required this.controller});

  final VaultController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('My Vaults'),
            actions: [
              IconButton(
                tooltip: 'Create vault',
                icon: const Icon(Icons.add_rounded),
                onPressed: () => _showCreateVaultDialog(context),
              ),
            ],
          ),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEDE4FF), Color(0xFFF5F1FF)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_person_outlined, color: Color(0xFF6640E8)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Biometric unlock, encrypted notes, and auto-lock protection.',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: controller.vaults.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final vault = controller.vaults[index];
                    final notesCount = controller.notesForVault(vault.id).length;
                    return _VaultCard(
                      vault: vault,
                      notesCount: notesCount,
                      onUnlock: () async {
                        final ok = await controller.unlockVault(vault.id);
                        if (!context.mounted) {
                          return;
                        }
                        if (!ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Authentication cancelled or failed.'),
                            ),
                          );
                          return;
                        }
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => VaultDetailPage(
                              controller: controller,
                              vaultId: vault.id,
                            ),
                          ),
                        );
                      },
                      onOpen: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => VaultDetailPage(
                              controller: controller,
                              vaultId: vault.id,
                            ),
                          ),
                        );
                      },
                      onLock: () => controller.lockVault(vault.id),
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showCreateVaultDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('New Vault'),
          ),
        );
      },
    );
  }

  Future<void> _showCreateVaultDialog(BuildContext context) async {
    final textController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create Vault'),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Vault name',
              hintText: 'Personal Vault',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = textController.text.trim();
                if (name.isEmpty) {
                  return;
                }
                await controller.createVault(name: name);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }
}

class VaultDetailPage extends StatefulWidget {
  const VaultDetailPage({
    super.key,
    required this.controller,
    required this.vaultId,
  });

  final VaultController controller;
  final String vaultId;

  @override
  State<VaultDetailPage> createState() => _VaultDetailPageState();
}

class _VaultDetailPageState extends State<VaultDetailPage> {
  final Set<String> _visibleNoteIds = <String>{};
  final Map<String, DecryptedSecureNote> _decryptedById = {};

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final vault = widget.controller.vaults.firstWhereOrNull(
          (item) => item.id == widget.vaultId,
        );

        if (vault == null) {
          return const Scaffold(
            body: Center(child: Text('Vault not found.')),
          );
        }

        if (vault.isLocked) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pop();
            }
          });
        }

        final notes = widget.controller.notesForVault(widget.vaultId);

        return Scaffold(
          appBar: AppBar(
            title: Text(vault.name),
            actions: [
              IconButton(
                onPressed: () async {
                  await widget.controller.lockVault(widget.vaultId);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                icon: const Icon(Icons.lock),
                tooltip: 'Lock vault',
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showSecureNoteComposer(),
            icon: const Icon(Icons.add),
            label: const Text('Add Secure Note'),
          ),
          body: notes.isEmpty
              ? const Center(
                  child: Text('No secure notes yet. Add your first encrypted note.'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: notes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    final decrypted = _decryptedById[note.id] ??
                        widget.controller.cachedDecryptedNote(note.id);
                    final isVisible = _visibleNoteIds.contains(note.id);

                    return Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x12000000),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.enhanced_encryption_outlined,
                                size: 18,
                                color: Color(0xFF6942E0),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  decrypted?.title ?? 'Encrypted note',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Edit note',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () async {
                                  final data = decrypted ??
                                      await widget.controller.decryptNote(note);
                                  if (!mounted) {
                                    return;
                                  }
                                  setState(() => _decryptedById[note.id] = data);
                                  await _showSecureNoteComposer(
                                    note: note,
                                    initial: data,
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isVisible && decrypted != null
                                ? decrypted.content
                                : 'Encrypted. Tap the eye icon to reveal securely.',
                            style: TextStyle(
                              color: isVisible
                                  ? const Color(0xFF1D1C24)
                                  : const Color(0xFF6D6A79),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                tooltip: isVisible ? 'Hide note' : 'Reveal note',
                                icon: Icon(
                                  isVisible
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                                onPressed: () async {
                                  if (isVisible) {
                                    setState(() => _visibleNoteIds.remove(note.id));
                                    return;
                                  }

                                  final data = await widget.controller.decryptNote(note);
                                  if (mounted) {
                                    setState(() {
                                      _decryptedById[note.id] = data;
                                      _visibleNoteIds.add(note.id);
                                    });
                                  }
                                },
                              ),
                              IconButton(
                                tooltip: 'Delete note',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  await widget.controller.deleteSecureNote(
                                    vaultId: widget.vaultId,
                                    noteId: note.id,
                                  );
                                  if (mounted) {
                                    setState(() {
                                      _visibleNoteIds.remove(note.id);
                                      _decryptedById.remove(note.id);
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Future<void> _showSecureNoteComposer({
    SecureNote? note,
    DecryptedSecureNote? initial,
  }) async {
    final titleController = TextEditingController(text: initial?.title ?? '');
    final contentController = TextEditingController(text: initial?.content ?? '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                note == null ? 'Create Secure Note' : 'Edit Secure Note',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: titleController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Note title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Secure note content',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final content = contentController.text.trim();
                    if (title.isEmpty || content.isEmpty) {
                      return;
                    }

                    if (note == null) {
                      await widget.controller.addSecureNote(
                        vaultId: widget.vaultId,
                        title: title,
                        content: content,
                      );
                    } else {
                      await widget.controller.updateSecureNote(
                        vaultId: widget.vaultId,
                        noteId: note.id,
                        title: title,
                        content: content,
                      );
                    }

                    if (!sheetContext.mounted) {
                      return;
                    }
                    Navigator.of(sheetContext).pop();
                  },
                  child: Text(note == null ? 'Encrypt & Save' : 'Update & Re-encrypt'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.autoLockSeconds,
    required this.onAutoLockChanged,
  });

  final VaultController controller;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final int autoLockSeconds;
  final ValueChanged<int> onAutoLockChanged;

  String _autoLockLabel(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    }
    final mins = seconds ~/ 60;
    return mins == 1 ? '1 minute' : '$mins minutes';
  }

  Future<void> _showAutoLockPicker(BuildContext context) async {
    const options = [30, 60, 300, 600, 1800];
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Vault Auto-Lock Timer'),
              subtitle: Text('Automatically lock unlocked vaults after inactivity.'),
            ),
            for (final option in options)
              ListTile(
                title: Text(_autoLockLabel(option)),
                trailing: option == autoLockSeconds
                    ? Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : const Icon(Icons.circle_outlined),
                onTap: () => Navigator.of(context).pop(option),
              ),
            const SizedBox(height: 10),
          ],
        );
      },
    );
    if (selected != null) {
      onAutoLockChanged(selected);
    }
  }

  void _showAboutSection(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About NoteVault',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'NoteVault is a privacy-focused note app that keeps daily notes fast and secure vault notes encrypted with Android Keystore protection.',
                ),
                const SizedBox(height: 16),
                const Text('Core Features', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const _AboutBullet(text: 'Normal notes with pin, archive, and tag management.'),
                const _AboutBullet(text: 'Checklist notes for task-style note taking.'),
                const _AboutBullet(text: 'Scan-note editor mode for OCR text workflows.'),
                const _AboutBullet(text: 'Unified search over notes and unlocked vault entries.'),
                const _AboutBullet(text: 'Multi-vault support with biometric unlock.'),
                const _AboutBullet(text: 'Dark mode and configurable auto-lock timer.'),
                const SizedBox(height: 16),
                const Text('Security Model', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const _AboutBullet(text: 'Secure notes are encrypted at rest using Android Keystore-backed keys.'),
                const _AboutBullet(text: 'Vault names and secure-note payloads are encrypted before storage.'),
                const _AboutBullet(text: 'App backgrounding and inactivity timer can lock all vaults automatically.'),
                const _AboutBullet(text: 'Screen secure flag is enabled on Android to reduce content leakage.'),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.security_outlined),
              title: const Text('Security'),
              subtitle: Text(
                'Auto-lock: ${_autoLockLabel(autoLockSeconds)} · Vault lock controls',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _SecuritySettingsPage(
                      autoLockSeconds: autoLockSeconds,
                      onPickAutoLock: _showAutoLockPicker,
                      onLockAllVaults: controller.lockAllVaults,
                      autoLockLabel: _autoLockLabel,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Appearance'),
              subtitle: Text(isDarkMode ? 'Dark mode enabled' : 'Light mode enabled'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _AppearanceSettingsPage(
                      isDarkMode: isDarkMode,
                      onThemeChanged: onThemeChanged,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About NoteVault'),
              subtitle: const Text('Learn app features and privacy safeguards.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _AboutSettingsPage(onShowAbout: _showAboutSection),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SecuritySettingsPage extends StatelessWidget {
  const _SecuritySettingsPage({
    required this.autoLockSeconds,
    required this.onPickAutoLock,
    required this.onLockAllVaults,
    required this.autoLockLabel,
  });

  final int autoLockSeconds;
  final Future<void> Function(BuildContext context) onPickAutoLock;
  final VoidCallback onLockAllVaults;
  final String Function(int seconds) autoLockLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Security Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Vault auto-lock timer'),
              subtitle: Text(
                'Locks vaults after ${autoLockLabel(autoLockSeconds)} of inactivity.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onPickAutoLock(context),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Lock all vaults now'),
              subtitle: const Text('Immediately clear all unlocked vault states.'),
              onTap: onLockAllVaults,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppearanceSettingsPage extends StatelessWidget {
  const _AppearanceSettingsPage({
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Appearance Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile.adaptive(
              value: isDarkMode,
              onChanged: onThemeChanged,
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text('Dark mode'),
              subtitle: const Text('Use a darker appearance across the app.'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.color_lens_outlined),
              title: const Text('Color labels'),
              subtitle: const Text('Preview note color meanings and tag intent.'),
              onTap: () {
                showDialog<void>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('Color Labels'),
                      content: const Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LabelLegend(color: Color(0xFFFFF1B9), label: 'Pinned priority'),
                          SizedBox(height: 8),
                          _LabelLegend(color: Color(0xFFEAF5EC), label: 'Everyday notes'),
                          SizedBox(height: 8),
                          _LabelLegend(color: Color(0xFFEDE5FF), label: 'Ideas and drafts'),
                          SizedBox(height: 8),
                          _LabelLegend(color: Color(0xFFE6E8EF), label: 'Archived notes'),
                        ],
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
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutSettingsPage extends StatelessWidget {
  const _AboutSettingsPage({required this.onShowAbout});

  final void Function(BuildContext context) onShowAbout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About NoteVault'),
              subtitle: const Text('App features, privacy, and encryption details.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onShowAbout(context),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.apps_outage_outlined),
              title: Text('Version'),
              subtitle: Text('1.0.0+1'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteComposerPage extends StatefulWidget {
  const _NoteComposerPage({required this.note});

  final Note? note;

  @override
  State<_NoteComposerPage> createState() => _NoteComposerPageState();
}

class _NoteComposerPageState extends State<_NoteComposerPage> {
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
                for (var i = 0; i < modeTabs.length; i++)
                  ButtonSegment<int>(value: i, label: Text(modeTabs[i])),
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
      _NoteDraft(
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

class _NoteOpenPage extends StatefulWidget {
  const _NoteOpenPage({required this.note});

  final Note note;

  @override
  State<_NoteOpenPage> createState() => _NoteOpenPageState();
}

class _NoteOpenPageState extends State<_NoteOpenPage> {
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
      _NoteOpenResult(
        action: _NoteOpenAction.updateTags,
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
      _NoteOpenResult(
        action: _NoteOpenAction.updateFolder,
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
                const _NoteOpenResult(action: _NoteOpenAction.togglePin),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: _setReadReminder,
          ),
          PopupMenuButton<_NoteOpenAction>(
            onSelected: (value) {
              if (value == _NoteOpenAction.updateTags) {
                _promptTagEdit();
                return;
              }
              if (value == _NoteOpenAction.updateFolder) {
                _promptFolderEdit();
                return;
              }
              Navigator.of(context).pop(_NoteOpenResult(action: value));
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: _NoteOpenAction.edit, child: Text('Edit')),
              PopupMenuItem(
                value: _NoteOpenAction.togglePin,
                child: Text(widget.note.isPinned ? 'Unpin' : 'Pin'),
              ),
              PopupMenuItem(
                value: _NoteOpenAction.toggleArchive,
                child: Text(widget.note.isArchived ? 'Unarchive' : 'Archive'),
              ),
              const PopupMenuItem(
                value: _NoteOpenAction.updateTags,
                child: Text('Edit tags'),
              ),
              const PopupMenuItem(
                value: _NoteOpenAction.updateFolder,
                child: Text('Edit folder'),
              ),
              const PopupMenuItem(
                value: _NoteOpenAction.delete,
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
                const _NoteOpenResult(action: _NoteOpenAction.edit),
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

class _NoteDraft {
  const _NoteDraft({
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

enum _NotesListMenuAction {
  newNote,
  notesOverview,
  filterByTag,
  filterByFolder,
  showArchivedCount,
}

enum _ComposerMenuAction { editTags, editFolder, clearContent }

enum _NoteOpenAction {
  edit,
  togglePin,
  toggleArchive,
  updateTags,
  updateFolder,
  delete,
}

class _NoteOpenResult {
  const _NoteOpenResult({required this.action, this.tags, this.folder});

  final _NoteOpenAction action;
  final List<String>? tags;
  final String? folder;
}

class _LabelLegend extends StatelessWidget {
  const _LabelLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}

class _AboutBullet extends StatelessWidget {
  const _AboutBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
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

class _VaultCard extends StatelessWidget {
  const _VaultCard({
    required this.vault,
    required this.notesCount,
    required this.onUnlock,
    required this.onOpen,
    required this.onLock,
  });

  final Vault vault;
  final int notesCount;
  final VoidCallback onUnlock;
  final VoidCallback onOpen;
  final VoidCallback onLock;

  @override
  Widget build(BuildContext context) {
    final locked = vault.isLocked;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: locked
                    ? const Color(0xFFE9E2FF)
                    : const Color(0xFFE1F6E8),
                child: Icon(
                  locked ? Icons.lock_outline : Icons.lock_open_outlined,
                  color: locked ? const Color(0xFF6A42E0) : const Color(0xFF2A8542),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  vault.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            locked
                ? 'Your vault is locked. Authenticate to continue.'
                : '$notesCount secure notes ready.',
            style: const TextStyle(color: Color(0xFF655F76)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (locked)
                FilledButton.icon(
                  onPressed: onUnlock,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Unlock'),
                )
              else ...[
                FilledButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('Open'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onLock,
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Lock'),
                ),
              ],
            ],
          ),
        ],
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
                      isArchived
                          ? Icons.unarchive_outlined
                          : Icons.archive_outlined,
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

extension _IterableX<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final item in this) {
      if (test(item)) {
        return item;
      }
    }
    return null;
  }
}
