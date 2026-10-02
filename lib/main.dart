import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:talker_flutter/talker_flutter.dart';

import 'app.dart';
import 'core/di/locator.dart';
import 'core/logging/app_logger.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await setupLocator();
  Bloc.observer = AppBlocObserver(sl<Talker>());

  // Start verifying the stored session; SplashScreen waits for the outcome.
  sl<AuthCubit>().checkSession();

  runApp(const App());
}
