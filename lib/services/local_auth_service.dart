import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class LocalAuthService {
  LocalAuthService({LocalAuthentication? localAuthentication})
      : _auth = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _auth;

  Future<bool> authenticate() async {
    try {
      final canAuthenticate =
          await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!canAuthenticate) {
        return false;
      }

      return _auth.authenticate(
        localizedReason: 'Unlock your vault to view secure notes',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }
}
