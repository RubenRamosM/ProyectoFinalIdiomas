import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(0, -1),
            end: Alignment(0, 1),
            colors: [Color(0xFFE6F4FF), Color(0xFFFFFFFF)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              children: [
                const SizedBox(height: 8),

                // Oso polar animado (usa asset local o cambia a Lottie.network si prefieres)
                Expanded(
                  flex: 5,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Lottie.asset(
                        'assets/oso_polar.json',
                        repeat: true,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                // Texto
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '¡Bienvenido a DUOLINGO',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineLarge?.copyWith(
                          color: const Color(0xFF16354D),
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Aprendé idiomas con microlecciones y práctica guiada. ¡Empezá hoy!',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF3B556A),
                          height: 1.35,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Botones
                Column(
                  children: [
                    SizedBox(
                      width: size.width,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed:
                            () => Navigator.pushNamed(context, '/register'),
                        child: const Text('Empieza ahora'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: size.width,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: const BorderSide(color: Color(0xFF2D9CDB)),
                        ),
                        onPressed: () => Navigator.pushNamed(context, '/login'),
                        child: const Text('Ya tengo una cuenta'),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
