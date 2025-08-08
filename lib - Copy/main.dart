import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:first_app/authentication/login_screen.dart';
import 'package:first_app/main_screens/home_screen.dart';
import 'package:first_app/screens/splash_screen.dart';
import 'package:first_app/theme/theme_notifier.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final savedThemeMode = await AdaptiveTheme.getThemeMode();
  // Wrap the app with a provider to make the ThemeNotifier available.
  runApp(
    ChangeNotifierProvider<ThemeNotifier>(
      create: (_) => ThemeNotifier(),
      child: MyApp(savedThemeMode: savedThemeMode),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.savedThemeMode});
  final AdaptiveThemeMode? savedThemeMode;

  @override
  Widget build(BuildContext context) {
    // Use a Consumer to rebuild the theme when the color changes.
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        // Define static colors that don't change with the theme accent.
        const backgroundLight = Color(0xFFF5F5F7);
        const cardLight = Colors.white;
        const textPrimaryLight = Color(0xFF1D1D1F);

        const backgroundDark = Color(0xFF121212);
        const cardDark = Color(0xFF1E1E1E);
        const textPrimaryDark = Color(0xFFFFFFFF);

        return AdaptiveTheme(
          light: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: backgroundLight,
            // Use the dynamic primary color from our notifier.
            colorScheme: ColorScheme.light(
              primary: themeNotifier.primaryColor,
              secondary: themeNotifier.primaryColor,
              background: backgroundLight,
              surface: cardLight,
              onSurface: textPrimaryLight,
            ),
            textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme).apply(
              bodyColor: textPrimaryLight,
              displayColor: textPrimaryLight,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: backgroundLight,
              elevation: 0,
              iconTheme: IconThemeData(color: textPrimaryLight),
            ),
          ),
          dark: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: backgroundDark,
            // Use the dynamic primary color for the dark theme as well.
            colorScheme: ColorScheme.dark(
              primary: themeNotifier.primaryColor,
              secondary: themeNotifier.primaryColor,
              background: backgroundDark,
              surface: cardDark,
              onSurface: textPrimaryDark,
            ),
            textTheme: GoogleFonts.interTextTheme(Theme.of(context).primaryTextTheme).apply(
              bodyColor: textPrimaryDark,
              displayColor: textPrimaryDark,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: backgroundDark,
              elevation: 0,
              iconTheme: IconThemeData(color: textPrimaryDark),
            ),
          ),
          initial: savedThemeMode ?? AdaptiveThemeMode.light,
          builder: (theme, darkTheme) => MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Shonglap',
            theme: theme,
            darkTheme: darkTheme,
            home: const SplashScreen(),
          ),
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
