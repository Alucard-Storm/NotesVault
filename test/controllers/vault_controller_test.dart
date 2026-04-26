import 'package:flutter_test/flutter_test.dart';
import 'package:notevault/controllers/vault_controller.dart';

import '../mocks/mock_services.dart';

void main() {
  group('VaultController', () {
    late VaultController controller;
    late MockVaultRepository mockVaultRepository;
    late MockAndroidKeystoreService mockKeystore;
    late MockLocalAuthService mockAuthService;

    setUp(() {
      mockVaultRepository = MockVaultRepository();
      mockKeystore = MockAndroidKeystoreService();
      mockAuthService = MockLocalAuthService();
      
      controller = VaultController(
        repository: mockVaultRepository,
        keystoreService: mockKeystore,
        authService: mockAuthService,
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('initializes with default auto-lock duration of 1 minute', () {
      expect(controller.autoLockDuration, equals(const Duration(minutes: 1)));
    });

    test('setAutoLockDuration updates duration', () {
      final newDuration = Duration(seconds: 30);
      controller.setAutoLockDuration(newDuration);
      expect(controller.autoLockDuration, equals(newDuration));
    });

    test('setAutoLockDuration does not set invalid duration', () {
      const originalDuration = Duration(minutes: 1);
      controller.setAutoLockDuration(originalDuration);
      
      // Try to set invalid (0 or negative)
      controller.setAutoLockDuration(const Duration(seconds: 0));
      expect(controller.autoLockDuration, equals(originalDuration));
    });

    test('error property is null initially', () {
      expect(controller.error, isNull);
    });

    test('vaults list is empty initially', () {
      expect(controller.vaults, isEmpty);
    });

    test('isLoading is false initially', () {
      expect(controller.isLoading, isFalse);
    });
  });
}
