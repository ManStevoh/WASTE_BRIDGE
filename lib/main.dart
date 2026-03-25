import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waste_bridge/core/theme/app_theme.dart';
import 'package:waste_bridge/firebase_options.dart';
import 'package:waste_bridge/providers/app_providers.dart';
import 'package:waste_bridge/routes/app_router.dart';
import 'package:waste_bridge/services/push_registration_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Missing google-services.json / GoogleService-Info.plist — push disabled.
  }
  runApp(const ProviderScope(child: WasteBridgeApp()));
}

class WasteBridgeApp extends ConsumerStatefulWidget {
  const WasteBridgeApp({super.key});

  @override
  ConsumerState<WasteBridgeApp> createState() => _WasteBridgeAppState();
}

class _WasteBridgeAppState extends ConsumerState<WasteBridgeApp> {
  @override
  Widget build(BuildContext context) {
    ref.listen(authNotifierProvider, (prev, next) {
      final prevUser = prev?.valueOrNull;
      final nextUser = next.valueOrNull;
      if (prevUser == null && nextUser != null) {
        ref.read(analyticsServiceProvider).logEvent(
          'session_start',
          platform: 'flutter',
        );
        PushRegistrationService.setupFirebaseMessaging(
          ref.read(apiClientProvider).dio,
        );
      }
    });

    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Waste Bridge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
