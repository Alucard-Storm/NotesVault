import 'package:flutter/material.dart';

import '../../controllers/vault_controller.dart';

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
