import 'package:flutter/material.dart';
import 'screens/welcome.dart';
import 'screens/register.dart';
import 'screens/login.dart';
import 'screens/home.dart';
import 'screens/lecciones/adaptive_lesson_screen.dart';
import 'screens/shadowing/shadowing_exercise_screen.dart';
import 'screens/lecciones/spaced_repetition_screen.dart';
import 'screens/lecciones/lesson_history_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/live_translator_screen.dart';

import 'services/api.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Api.init();
  } catch (e) {
    print('Error initializing API: $e');
    // Continuar de todos modos con la configuración por defecto
  }

  runApp(const LangApp());
}

class LangApp extends StatelessWidget {
  const LangApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Idiomas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2D9CDB), // celeste agradable
        useMaterial3: true,
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontWeight: FontWeight.w700),
          titleMedium: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const WelcomeScreen(),
        '/register': (_) => const RegisterScreen(),
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
        '/adaptive-lesson': (_) => const AdaptiveLessonScreen(),
        '/shadowing': (_) => const ShadowingExerciseScreen(),
        '/spaced-repetition': (_) => const SpacedRepetitionScreen(),
        '/stats': (_) => const StatsScreen(),
        '/lesson-history': (_) => const LessonHistoryScreen(),
        '/live-translator': (_) => const LiveTranslatorScreen(),
      },
    );
  }
}
