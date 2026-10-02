import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../features/auth/auth_di.dart';
import '../../features/sample/sample_di.dart';
import '../logging/app_logger.dart';
import '../network/dio_builder.dart';
import '../push/noop_push_service.dart';
import '../push/push_service.dart';
import '../session/session_events.dart';
import '../session/session_storage.dart';

/// Service locator. `sl<T>()` anywhere; registration happens only here and in
/// each feature's `<feature>_di.dart`.
///
/// - `registerLazySingleton`: infrastructure + repositories (stateless, created
///   on first use).
/// - `registerFactory`: usecases + page cubits (fresh instance per request).
final GetIt sl = GetIt.instance;

Future<void> setupLocator() async {
  // --- Infrastructure --------------------------------------------------------
  sl.registerLazySingleton<Talker>(buildTalker);
  sl.registerLazySingleton<SessionStorage>(SecureSessionStorage.new);
  sl.registerLazySingleton<SessionEvents>(SessionEvents.new);
  sl.registerLazySingleton<Dio>(
    () => buildDio(storage: sl(), events: sl(), talker: sl()),
  );

  // Push: swap for `registerFirebase(sl)` from lib/integrations/firebase.
  sl.registerLazySingleton<PushService>(NoopPushService.new);

  // --- Features --------------------------------------------------------------
  registerAuth(sl);
  registerSample(sl);
  // ...add each feature's register<Feature>(sl) here.
}
