import 'package:flutter/material.dart';

import '../../controllers/vault_controller.dart';
import '../../models/secure_note.dart';
import '../../models/vault.dart';

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
