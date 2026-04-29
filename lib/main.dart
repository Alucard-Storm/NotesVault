import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'controllers/notes_controller.dart';
import 'controllers/vault_controller.dart';
import 'core/di/service_locator.dart';
import 'services/android_keystore_service.dart';
import 'services/local_auth_service.dart';
import 'services/notes_repository.dart';
import 'services/vault_repository.dart';
import 'ui/pages/notes_page.dart';
import 'ui/pages/search_page.dart';
import 'ui/pages/settings_page.dart';
import 'ui/pages/study_dashboard_page.dart';
import 'ui/pages/vault_page.dart';
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
      StudyDashboardPage(controller: widget.notesController),
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
          NavigationDestination(icon: Icon(Icons.auto_graph_outlined), label: 'Study'),
          NavigationDestination(icon: Icon(Icons.lock_outline), label: 'Vault'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}

