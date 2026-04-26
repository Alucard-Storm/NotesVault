import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/secure_note.dart';

class VaultRepository {
  static const String _vaultsKey = 'vaults';
  static const String _secureNotesPrefix = 'secure_notes_';

  Future<List<Map<String, dynamic>>> loadVaultRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_vaultsKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    return (jsonDecode(raw) as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  Future<void> saveVaultRecords(List<Map<String, dynamic>> records) async {
    final prefs = await SharedPreferences.getInstance();
    final serialized = jsonEncode(records);
    await prefs.setString(_vaultsKey, serialized);
  }

  Future<List<SecureNote>> loadSecureNotes(String vaultId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_secureNotesPrefix$vaultId');
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    return (jsonDecode(raw) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(SecureNote.fromJson)
        .toList();
  }

  Future<void> saveSecureNotes(String vaultId, List<SecureNote> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final serialized = jsonEncode(notes.map((note) => note.toJson()).toList());
    await prefs.setString('$_secureNotesPrefix$vaultId', serialized);
  }
}
