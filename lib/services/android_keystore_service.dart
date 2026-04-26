import 'dart:io';

import 'package:flutter/services.dart';

class AndroidKeystoreService {
  AndroidKeystoreService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('notevault/security');

  final MethodChannel _channel;

  Future<void> ensureVaultKey(String alias) async {
    _assertAndroid();
    await _channel.invokeMethod<void>('ensureVaultKey', {'alias': alias});
  }

  Future<String> encrypt({required String alias, required String plaintext}) async {
    _assertAndroid();
    final encrypted = await _channel.invokeMethod<String>('encrypt', {
      'alias': alias,
      'plaintext': plaintext,
    });
    if (encrypted == null || encrypted.isEmpty) {
      throw StateError('Encryption failed');
    }
    return encrypted;
  }

  Future<String> decrypt({required String alias, required String encryptedBlob}) async {
    _assertAndroid();
    final decrypted = await _channel.invokeMethod<String>('decrypt', {
      'alias': alias,
      'encryptedBlob': encryptedBlob,
    });
    if (decrypted == null) {
      throw StateError('Decryption failed');
    }
    return decrypted;
  }

  void _assertAndroid() {
    if (!Platform.isAndroid) {
      throw UnsupportedError('This build currently supports secure vault on Android.');
    }
  }
}
