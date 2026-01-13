import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _showPass = false;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? "Requerido" : null;

  bool _isEmail(String v) => RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim());

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _email.text.trim();

    // Tu backend pide "username". Para no tocar backend,
    // convertimos "correo" -> username (parte antes del @).
    final username = email.contains("@") ? email.split("@").first : email;

    setState(() => _loading = true);
    try {
      await AuthService.login(username: username, password: _pass.text);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Sesión iniciada")));
      Navigator.pushReplacementNamed(
        context,
        '/home',
      ); // o Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error al iniciar sesión: $e")));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Altura del oso: más pequeño y adaptable
    final bearHeight = size.height * 0.25; // 25% de alto
    final clampedHeight = bearHeight.clamp(140.0, 220.0); // entre 140 y 220 px

    return Scaffold(
      appBar: AppBar(
        title: const Text('Iniciar sesión'),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              children: [
                // ---------- Animación del oso (más chica) ----------
                SizedBox(
                  height: clampedHeight,
                  child: Lottie.asset(
                    'assets/oso_polar.json',
                    repeat: true,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 8),

                // ---------- Form ----------
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _email,
                        decoration: const InputDecoration(
                          labelText: "Correo",
                          hintText: "tucorreo@ejemplo.com",
                          prefixIcon: Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (_req(v) != null) return "Requerido";
                          return _isEmail(v!) ? null : "Correo inválido";
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _pass,
                        decoration: InputDecoration(
                          labelText: "Contraseña",
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            onPressed:
                                () => setState(() => _showPass = !_showPass),
                            icon: Icon(
                              _showPass
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                        obscureText: !_showPass,
                        validator: (v) {
                          if (_req(v) != null) return "Requerido";
                          if (v!.length < 8) return "Mínimo 8 caracteres";
                          return null;
                        },
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: size.width,
                        child: FilledButton(
                          onPressed: _loading ? null : _submit,
                          child:
                              _loading
                                  ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Text("Entrar"),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("¿No tienes cuenta? "),
                    TextButton(
                      onPressed:
                          _loading
                              ? null
                              : () => Navigator.pushNamed(context, '/register'),
                      child: const Text("Crear cuenta"),
                    ),
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
