// main.dart
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl; // for date/number locale

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

import 'config.dart';
import 'helpers/AppTheme.dart';
import 'helpers/routes.dart';
import 'locale/MyLocalizations.dart';
import 'pages/notifications/view_model_manger/notifications_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite FFI on desktop
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  }

  // Orientation lock (safe to keep on mobile; ignored on desktop/web)
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final appLanguage = AppLanguage();
  await appLanguage.fetchLocale();

  runApp(MyApp(appLanguage: appLanguage));
}

class MyApp extends StatelessWidget {
  final AppLanguage appLanguage;
  const MyApp({super.key, required this.appLanguage});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NotificationsCubit()..getNotification(),
      child: ChangeNotifierProvider<AppLanguage>(
        create: (_) => appLanguage,
        child: Consumer<AppLanguage>(
          builder: (context, model, _) {
            // Keep Intl in sync with the app locale (affects DateFormat, NumberFormat, etc.)
            final locale = model.appLocal;
            if (locale != null) {
              intl.Intl.defaultLocale =
                  locale.toLanguageTag(); // e.g., "ar", "en"
            }

            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.getThemeFromThemeMode(1),
              // If you’re using Material 3:
              // theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),

              // ROUTING
              routes: Routes.generateRoute(),
              initialRoute: '/splash',
              // If you added the POS page file I gave you, make sure
              // Routes.generateRoute() contains: '/pos-single': (_) => const PosSinglePage(),

              // LOCALE
              locale: locale, // controlled by AppLanguage
              supportedLocales: Config()
                  .supportedLocales, // e.g., [Locale('ar'), Locale('en')]
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],

              // Make sure we fall back gracefully and pick RTL for Arabic automatically
              localeResolutionCallback: (deviceLocale, supported) {
                if (locale != null) return locale; // respect saved user choice
                if (deviceLocale == null) return supported.first;
                for (final l in supported) {
                  if (l.languageCode == deviceLocale.languageCode) return l;
                }
                return supported.first;
              },

              // Keep bottom bars/panels above the keyboard across the app
              builder: (context, child) {
                final insets = MediaQuery.of(context).viewInsets;
                return Padding(
                  padding: EdgeInsets.only(bottom: insets.bottom),
                  child: child ?? const SizedBox.shrink(),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
