import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../controllers/notes_controller.dart';
import '../../controllers/vault_controller.dart';
import '../../services/android_keystore_service.dart';
import '../../services/local_auth_service.dart';
import '../../services/notes_repository.dart';
import '../../services/vault_repository.dart';

final getIt = GetIt.instance;

/// Initialize dependency injection container
Future<void> setupDependencies() async {
  // Repositories
  getIt.registerSingleton<NotesRepository>(NotesRepository());
  getIt.registerSingleton<VaultRepository>(VaultRepository());

  // Platform services
  getIt.registerSingleton<AndroidKeystoreService>(AndroidKeystoreService());
  getIt.registerSingleton<LocalAuthService>(LocalAuthService());

  // Controllers
  getIt.registerSingleton<NotesController>(
    NotesController(repository: getIt<NotesRepository>()),
  );
  getIt.registerSingleton<VaultController>(
    VaultController(
      repository: getIt<VaultRepository>(),
      keystoreService: getIt<AndroidKeystoreService>(),
      authService: getIt<LocalAuthService>(),
    ),
  );

  // Shared preferences
  final prefs = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(prefs);
}
