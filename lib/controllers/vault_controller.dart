import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/errors/app_exceptions.dart';
import '../core/errors/error_handler.dart';
import '../models/secure_note.dart';
import '../models/vault.dart';
import '../services/android_keystore_service.dart';
import '../services/local_auth_service.dart';
import '../services/vault_repository.dart';

class VaultController extends ChangeNotifier {
  static const String _metadataAlias = 'notevault.metadata';

  VaultController({
    required VaultRepository repository,
    required AndroidKeystoreService keystoreService,
    required LocalAuthService authService,
  })  : _repository = repository,
        _keystoreService = keystoreService,
        _authService = authService;

  final VaultRepository _repository;
  final AndroidKeystoreService _keystoreService;
  final LocalAuthService _authService;
  final Uuid _uuid = const Uuid();

  List<Vault> _vaults = const [];
  final Map<String, List<SecureNote>> _secureNotesByVault = {};
  final Map<String, DecryptedSecureNote> _decryptedNoteCache = {};
  bool _isLoading = false;
  String? _error;
  Timer? _autoLockTimer;
  Duration _autoLockDuration = const Duration(minutes: 1);

  List<Vault> get vaults => _vaults;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Duration get autoLockDuration => _autoLockDuration;

  void setAutoLockDuration(Duration duration) {
    if (duration.inSeconds <= 0) {
      return;
    }
    _autoLockDuration = duration;
    final hasUnlockedVault = _vaults.any((vault) => !vault.isLocked);
    if (hasUnlockedVault) {
      _startAutoLockTimer();
    }
    notifyListeners();
  }

  List<SecureNote> notesForVault(String vaultId) {
    return [...(_secureNotesByVault[vaultId] ?? const [])];
  }

  bool isNoteDecrypted(String noteId) => _decryptedNoteCache.containsKey(noteId);

  DecryptedSecureNote? cachedDecryptedNote(String noteId) {
    return _decryptedNoteCache[noteId];
  }

  Future<void> initialize() async {
    _setLoading(true);
    try {
      await _keystoreService.ensureVaultKey(_metadataAlias);
      final records = await _repository.loadVaultRecords();
      final migratedVaults = await _parseVaultRecords(records);

      if (migratedVaults.isEmpty) {
        final defaultVault = await createVault(name: 'My Vault');
        _vaults = [defaultVault];
      } else {
        _vaults = migratedVaults
            .map((vault) => vault.copyWith(isLocked: true))
            .toList();
        await _persistVaultsEncrypted();
      }

      for (final vault in _vaults) {
        await _keystoreService.ensureVaultKey(_aliasForVault(vault.id));
        _secureNotesByVault[vault.id] = await _repository.loadSecureNotes(vault.id);
      }
      _error = null;
    } catch (_) {
      _error = 'Unable to initialize vault.';
    } finally {
      _setLoading(false);
    }
  }

  Future<Vault> createVault({required String name}) async {
    // Validate input
    ErrorHandler.validateVaultName(name);

    final vault = Vault(
      id: _uuid.v4(),
      name: name,
      isLocked: true,
    );

    try {
      await _keystoreService.ensureVaultKey(_aliasForVault(vault.id));
      _vaults = [..._vaults, vault];
      _secureNotesByVault[vault.id] = const [];
      await _persistVaultsEncrypted();
      notifyListeners();
      return vault;
    } catch (e) {
      throw VaultOperationError('Failed to create vault: ${e.toString()}');
    }
  }

  Future<bool> unlockVault(String vaultId) async {
    final authenticated = await _authService.authenticate();
    if (!authenticated) {
      return false;
    }

    _vaults = _vaults
        .map(
          (vault) => vault.id == vaultId
              ? vault.copyWith(isLocked: false)
              : vault,
        )
        .toList();
    await _persistVaultsEncrypted();
    _startAutoLockTimer();
    notifyListeners();
    return true;
  }

  Future<void> lockVault(String vaultId) async {
    _vaults = _vaults
        .map(
          (vault) =>
              vault.id == vaultId ? vault.copyWith(isLocked: true) : vault,
        )
        .toList();
    _dropVaultDecryptedData(vaultId);
    await _persistVaultsEncrypted();
    notifyListeners();
  }

  Future<void> lockAllVaults() async {
    _autoLockTimer?.cancel();
    _vaults = _vaults.map((vault) => vault.copyWith(isLocked: true)).toList();
    _decryptedNoteCache.clear();
    await _persistVaultsEncrypted();
    notifyListeners();
  }

  Future<SecureNote> addSecureNote({
    required String vaultId,
    required String title,
    required String content,
  }) async {
    // Validate inputs
    ErrorHandler.validateTitleLength(title);
    ErrorHandler.validateNotEmpty(content, 'Content');

    try {
      final alias = _aliasForVault(vaultId);
      final nowIso = DateTime.now().toIso8601String();
      final payload = jsonEncode({
        'title': title,
        'content': content,
        'createdAt': nowIso,
        'updatedAt': nowIso,
      });
      final encryptedPayload =
          await _keystoreService.encrypt(alias: alias, plaintext: payload);

      final note = SecureNote(
        id: _uuid.v4(),
        vaultId: vaultId,
        encryptedData: encryptedPayload,
      );

      final existing = _secureNotesByVault[vaultId] ?? const [];
      _secureNotesByVault[vaultId] = [note, ...existing];
      await _repository.saveSecureNotes(vaultId, _secureNotesByVault[vaultId]!);
      _startAutoLockTimer();
      notifyListeners();
      return note;
    } catch (e) {
      if (e is AppException) rethrow;
      throw EncryptionError('Failed to save secure note: ${e.toString()}');
    }
  }

  Future<void> updateSecureNote({
    required String vaultId,
    required String noteId,
    required String title,
    required String content,
  }) async {
    final notes = _secureNotesByVault[vaultId] ?? const [];
    final index = notes.indexWhere((note) => note.id == noteId);
    if (index < 0) {
      return;
    }

    final existingNote = notes[index];
    final alias = _aliasForVault(vaultId);
    final nowIso = DateTime.now().toIso8601String();
    final existingPayload = await decryptNote(existingNote);
    final payload = jsonEncode({
      'title': title,
      'content': content,
      'createdAt': existingPayload.createdAt,
      'updatedAt': nowIso,
    });
    final encryptedPayload =
        await _keystoreService.encrypt(alias: alias, plaintext: payload);

    final updated = existingNote.copyWith(encryptedData: encryptedPayload);
    final updatedList = [...notes];
    updatedList.removeAt(index);
    updatedList.insert(0, updated);

    _secureNotesByVault[vaultId] = updatedList;
    _decryptedNoteCache[noteId] = DecryptedSecureNote(
      title: title,
      content: content,
      createdAt: existingPayload.createdAt,
      updatedAt: nowIso,
    );
    await _repository.saveSecureNotes(vaultId, updatedList);
    _startAutoLockTimer();
    notifyListeners();
  }

  Future<void> deleteSecureNote({
    required String vaultId,
    required String noteId,
  }) async {
    final existing = _secureNotesByVault[vaultId] ?? const [];
    _secureNotesByVault[vaultId] =
        existing.where((note) => note.id != noteId).toList();
    _decryptedNoteCache.remove(noteId);
    await _repository.saveSecureNotes(vaultId, _secureNotesByVault[vaultId]!);
    notifyListeners();
  }

  Future<DecryptedSecureNote> decryptNote(SecureNote note) async {
    final cached = _decryptedNoteCache[note.id];
    if (cached != null) {
      return cached;
    }

    final alias = _aliasForVault(note.vaultId);
    final decrypted = await _keystoreService.decrypt(
      alias: alias,
      encryptedBlob: note.encryptedData,
    );
    DecryptedSecureNote value;
    try {
      final decoded = jsonDecode(decrypted) as Map<String, dynamic>;
      final title = (decoded['title'] as String?)?.trim();
      final content = (decoded['content'] as String?) ?? '';
      value = DecryptedSecureNote(
        title: (title == null || title.isEmpty) ? 'Secure note' : title,
        content: content,
        createdAt: decoded['createdAt'] as String?,
        updatedAt: decoded['updatedAt'] as String?,
      );
    } catch (_) {
      // Backward compatibility for notes encrypted before metadata payload migration.
      value = DecryptedSecureNote(
        title: 'Secure note',
        content: decrypted,
      );
    }
    _decryptedNoteCache[note.id] = value;
    _startAutoLockTimer();
    return value;
  }

  String _aliasForVault(String vaultId) => 'notevault.vault.$vaultId';

  Future<List<Vault>> _parseVaultRecords(List<Map<String, dynamic>> records) async {
    final parsed = <Vault>[];
    for (final record in records) {
      final id = record['id'] as String?;
      if (id == null || id.isEmpty) {
        continue;
      }

      final encryptedName = record['encryptedName'] as String?;
      final plainName = record['name'] as String?;

      String name;
      if (encryptedName != null && encryptedName.isNotEmpty) {
        name = await _keystoreService.decrypt(
          alias: _metadataAlias,
          encryptedBlob: encryptedName,
        );
      } else {
        name = (plainName == null || plainName.isEmpty) ? 'Vault' : plainName;
      }

      parsed.add(
        Vault(
          id: id,
          name: name,
          isLocked: true,
        ),
      );
    }
    return parsed;
  }

  Future<void> _persistVaultsEncrypted() async {
    final records = <Map<String, dynamic>>[];
    for (final vault in _vaults) {
      final encryptedName = await _keystoreService.encrypt(
        alias: _metadataAlias,
        plaintext: vault.name,
      );
      records.add({
        'id': vault.id,
        'encryptedName': encryptedName,
      });
    }
    await _repository.saveVaultRecords(records);
  }

  void _dropVaultDecryptedData(String vaultId) {
    final ids = (_secureNotesByVault[vaultId] ?? const []).map((n) => n.id).toSet();
    _decryptedNoteCache.removeWhere((id, _) => ids.contains(id));
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _startAutoLockTimer() {
    _autoLockTimer?.cancel();
    _autoLockTimer = Timer(_autoLockDuration, () {
      lockAllVaults();
    });
  }

  @override
  void dispose() {
    _autoLockTimer?.cancel();
    super.dispose();
  }
}

class DecryptedSecureNote {
  const DecryptedSecureNote({
    required this.title,
    required this.content,
    this.createdAt,
    this.updatedAt,
  });

  final String title;
  final String content;
  final String? createdAt;
  final String? updatedAt;
}
