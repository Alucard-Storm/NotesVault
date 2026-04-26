import 'package:mockito/mockito.dart';
import 'package:notevault/services/notes_repository.dart';
import 'package:notevault/services/vault_repository.dart';
import 'package:notevault/services/android_keystore_service.dart';
import 'package:notevault/services/local_auth_service.dart';

// Generate mocks using: flutter pub run build_runner build
class MockNotesRepository extends Mock implements NotesRepository {}

class MockVaultRepository extends Mock implements VaultRepository {}

class MockAndroidKeystoreService extends Mock implements AndroidKeystoreService {}

class MockLocalAuthService extends Mock implements LocalAuthService {}
