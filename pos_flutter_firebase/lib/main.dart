import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'core/offline/local_database.dart';
import 'core/offline/sync_queue.dart';
import 'core/offline/sync_service.dart';
import 'core/offline/sync_handlers.dart';
import 'core/theme/glass_theme.dart';
import 'core/di/service_locator.dart';
import 'core/router/app_router.dart';
import 'shared/providers/theme_provider.dart';
import 'shared/providers/app_session_notifier.dart';
import 'shared/providers/cart_provider.dart';

FirebaseOptions _firebaseOptionsFromEnv() {
  return FirebaseOptions(
    apiKey: dotenv.env['FIREBASE_API_KEY'] ?? '',
    appId: dotenv.env['FIREBASE_APP_ID'] ?? '',
    messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '',
    projectId: dotenv.env['FIREBASE_PROJECT_ID'] ?? '',
    authDomain: dotenv.env['FIREBASE_AUTH_DOMAIN'] ?? '',
    storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '',
    measurementId: dotenv.env['FIREBASE_MEASUREMENT_ID'] ?? '',
  );
}

SyncService? _syncService;
late ServiceLocator _serviceLocator;

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: '.env');

    try {
      await Firebase.initializeApp(
        options: _firebaseOptionsFromEnv(),
      );
    } catch (_) {
      // Firebase ya inicializado (google-services.json o sesión previa)
    }
    await LocalDatabase.initialize();
    await SyncQueue.initialize();
    _syncService = SyncService(handlers: createSyncHandlers());
    _syncService!.processQueue();
    _serviceLocator = ServiceLocator();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('FLUTTER ERROR: ${details.exception}\n${details.stack}');
    };

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeNotifier()),
          ChangeNotifierProvider(create: (_) => FontSizeNotifier()),
          ChangeNotifierProvider(
            create: (_) => AppSessionNotifier(
              appContextService: _serviceLocator.appContextRepository,
            )..loadSession(),
          ),
          ..._serviceLocator.providers,
        ],
        child: Builder(
          builder: (context) => MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => CartProvider(
                  sessionNotifier: context.read<AppSessionNotifier>(),
                ),
              ),
            ],
            child: const MyApp(),
          ),
        ),
      ),
    );
  }, (error, stack) {
    debugPrint('UNCAUGHT ZONE ERROR: $error\n$stack');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeNotifier, FontSizeNotifier>(
      builder: (context, themeNotifier, fontSizeNotifier, _) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(fontSizeNotifier.textScaleFactor)),
          child: MaterialApp.router(
            title: 'POS Flutter Firebase',
            theme: GlassTheme.light(),
            darkTheme: GlassTheme.dark(),
            themeMode: themeNotifier.mode,
            routerConfig: goRouter,
            builder: (context, child) {
              ErrorWidget.builder = (errorDetails) {
                return Scaffold(
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          const Text('Error inesperado',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(errorDetails.exceptionAsString(), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),
                );
              };
              return child!;
            },
          ),
        );
      },
    );
  }
}
