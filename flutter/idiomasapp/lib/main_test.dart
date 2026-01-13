import 'package:flutter/material.dart';

void main() {
  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test App',
      home: Scaffold(
        appBar: AppBar(title: const Text('Test - App Funcionando')),
        body: const Center(
          child: Text(
            '✅ La app está funcionando correctamente!\n\n'
            'Si ves este mensaje, Flutter está bien.\n\n'
            'El problema está en el código de la app principal.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}
