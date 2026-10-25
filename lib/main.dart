import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:pokke/services/settings_service.dart';
import 'package:pokke/services/supabase_service.dart';
import 'package:pokke/theme/app_theme.dart';
import 'package:pokke/screens/welcome_screen.dart';
import 'package:pokke/adaptive/adaptive_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService.instance.load();
  try {
    await SupabaseService.init();
  } catch (e) {
    debugPrint('Supabase init: $e');
  }
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));
  runApp(const PokkeApp());
}

class PokkeApp extends StatelessWidget {
  const PokkeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return DynamicColorBuilder(
          builder: (lightDynamic, darkDynamic) {
            return MaterialApp(
              title: 'Pokke',
              debugShowCheckedModeBanner: false,
              themeMode: settings.themeMode,
              theme: AppTheme.light(dynamicScheme: lightDynamic),
              darkTheme: AppTheme.dark(
                dynamicScheme: darkDynamic,
                amoled: settings.amoled,
              ),
              home: SupabaseService.isLoggedIn
                  ? const AdaptiveShell()
                  : const WelcomeScreen(),
            );
          },
        );
      },
    );
  }
}
