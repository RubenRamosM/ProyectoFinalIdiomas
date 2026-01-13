import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/api.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // --- Wizard state ---
  final int totalSteps = 3;
  int step = 0;

  // --- Paso 1: idioma objetivo ---
  final List<Map<String, String>> languages = const [
    {"code": "en", "name": "Inglés"},
    {"code": "pt", "name": "Portugués"},
    {"code": "fr", "name": "Francés"},
    {"code": "it", "name": "Italiano"},
    {"code": "de", "name": "Alemán"},
  ];
  String? targetLang; // p.ej. "en"
  final String defaultNativeLang = "es";

  // --- Paso 2: nivel (5 frases) ---
  final List<Map<String, String>> levelOptions = const [
    {"code": "A1", "label": "Estoy empezando a aprender {LANG}"},
    {"code": "A2", "label": "Conozco algunas palabras"},
    {"code": "B1", "label": "Puedo mantener conversaciones simples"},
    {"code": "B2", "label": "Puedo conversar sobre varios temas"},
    {
      "code": "C1",
      "label": "Puedo debatir en detalle sobre la mayoría de los temas",
    },
  ];
  String? level; // A1..C1

  // --- Paso 3: datos personales ---
  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _age = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  bool showPass = false;
  bool loading = false;

  // --- Nacionalidades disponibles ---
  final List<String> nationalities = const [
    "Boliviana",
    "Argentina",
    "Chilena",
    "Peruana",
    "Colombiana",
    "Mexicana",
    "Brasileña",
    "Paraguaya",
    "Uruguaya",
    "Venezolana",
    "Española",
    "Estadounidense",
    "Canadiense",
    "Italiana",
    "Alemana",
    "Francesa",
  ];
  String? nationality;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _age.dispose();
    _email.dispose();
    _pass.dispose();
    _pass2.dispose();
    super.dispose();
  }

  // Helper: nombre del idioma seleccionado
  String _langName(String? code) {
    if (code == null) return "el idioma";
    final m = languages.firstWhere(
      (e) => e["code"] == code,
      orElse: () => const {"name": "el idioma"},
    );
    return m["name"]!;
  }

  double get progress => (step + 1) / totalSteps;

  void next() {
    if (step == 0 && targetLang == null) {
      _snack("Elegí un idioma.");
      return;
    }
    if (step == 1 && level == null) {
      _snack("Seleccioná tu nivel.");
      return;
    }
    if (step < totalSteps - 1) setState(() => step++);
  }

  void back() {
    if (step > 0) setState(() => step--);
  }

  /// Mapea nacionalidad → idioma nativo
  String _mapNationalityToNativeLang(String? nationality) {
    if (nationality == null) return 'es';
    final n = nationality.toLowerCase().trim();
    if (n.contains('brasil') || n.contains('brasile') || n.contains('brazil'))
      return 'pt';
    if (n.contains('francia') || n.contains('francesa')) return 'fr';
    if (n.contains('alemania') || n.contains('alemana')) return 'de';
    if (n.contains('italia') || n.contains('italiana')) return 'it';
    if (n.contains('estados unidos') ||
        n.contains('usa') ||
        n.contains('estadounidense'))
      return 'en';
    if (n.contains('canadiense')) return 'en';
    return 'es';
  }

  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pass.text != _pass2.text) {
      _snack("Las contraseñas no coinciden.");
      return;
    }
    if (nationality == null || nationality!.isEmpty) {
      _snack("Seleccioná tu nacionalidad.");
      return;
    }

    // Generar username simple
    final username =
        _email.text.contains("@")
            ? _email.text.split("@").first
            : "${_first.text.trim().toLowerCase()}.${_last.text.trim().toLowerCase()}";

    final userNative = _mapNationalityToNativeLang(nationality);

    setState(() => loading = true);
    try {
      await AuthService.register(
        username: username,
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        email: _email.text.trim(),
        password: _pass.text,
        nativeLanguage: userNative, // ✅ idioma nativo dinámico
        targetLanguage: targetLang ?? "en", // ✅ idioma a aprender
        age: int.tryParse(_age.text.trim()),
        level: level,
        nationality: nationality,
      );

      // Guardar en almacenamiento local
      await Api.storage.write(
        key: 'target_language',
        value: targetLang ?? 'en',
      );
      await AuthService.login(username: username, password: _pass.text);
      await Api.storage.write(
        key: 'target_language',
        value: targetLang ?? 'en',
      );
      await Api.storage.write(key: 'show_placement', value: '1');

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } catch (e) {
      _snack("Error al registrar: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (step) {
      0 => "¿Qué idioma querés aprender?",
      1 => "¿Cuál es tu nivel actual?",
      _ => "Contanos sobre vos",
    };

    return Scaffold(
      appBar: AppBar(title: const Text("Crear cuenta"), centerTitle: true),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 8),
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: switch (step) {
                  0 => _StepLanguage(
                    languages: languages,
                    selected: targetLang,
                    onSelect: (c) => setState(() => targetLang = c),
                  ),
                  1 => _StepLevel(
                    levelOptions: levelOptions,
                    selectedCode: level,
                    langName: _langName(targetLang),
                    onSelect: (code) => setState(() => level = code),
                  ),
                  _ => _StepUserForm(
                    formKey: _formKey,
                    first: _first,
                    last: _last,
                    age: _age,
                    email: _email,
                    pass: _pass,
                    pass2: _pass2,
                    showPass: showPass,
                    onTogglePass: () => setState(() => showPass = !showPass),
                    nationalities: nationalities,
                    selectedNationality: nationality,
                    onSelectNationality:
                        (val) => setState(() => nationality = val),
                  ),
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: step == 0 ? null : back,
                      child: const Text("Atrás"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed:
                          loading
                              ? null
                              : (step < totalSteps - 1 ? next : submit),
                      child:
                          loading
                              ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : Text(
                                step < totalSteps - 1
                                    ? "Siguiente"
                                    : "Crear cuenta",
                              ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------- PASOS ---------------------

class _StepLanguage extends StatelessWidget {
  final List<Map<String, String>> languages;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _StepLanguage({
    required this.languages,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children:
          languages.map((lang) {
            final isSel = selected == lang["code"];
            return ChoiceChip(
              label: Text(lang["name"]!),
              selected: isSel,
              onSelected: (_) => onSelect(lang["code"]!),
            );
          }).toList(),
    );
  }
}

class _StepLevel extends StatelessWidget {
  final List<Map<String, String>> levelOptions;
  final String? selectedCode;
  final String langName;
  final ValueChanged<String> onSelect;

  const _StepLevel({
    required this.levelOptions,
    required this.selectedCode,
    required this.langName,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: levelOptions.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final opt = levelOptions[i];
        final code = opt["code"]!;
        final label = (opt["label"]!).replaceAll(
          "{LANG}",
          langName.toLowerCase(),
        );
        return RadioListTile<String>(
          value: code,
          groupValue: selectedCode,
          onChanged: (v) => onSelect(v!),
          title: Text(label),
          subtitle: Text("Nivel aproximado: $code"),
        );
      },
    );
  }
}

class _StepUserForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController first;
  final TextEditingController last;
  final TextEditingController age;
  final TextEditingController email;
  final TextEditingController pass;
  final TextEditingController pass2;
  final bool showPass;
  final VoidCallback onTogglePass;

  final List<String> nationalities;
  final String? selectedNationality;
  final ValueChanged<String?> onSelectNationality;

  const _StepUserForm({
    required this.formKey,
    required this.first,
    required this.last,
    required this.age,
    required this.email,
    required this.pass,
    required this.pass2,
    required this.showPass,
    required this.onTogglePass,
    required this.nationalities,
    required this.selectedNationality,
    required this.onSelectNationality,
  });

  String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? "Requerido" : null;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: ListView(
        children: [
          TextFormField(
            controller: first,
            decoration: const InputDecoration(labelText: "Nombre"),
            validator: _req,
            textInputAction: TextInputAction.next,
          ),
          TextFormField(
            controller: last,
            decoration: const InputDecoration(labelText: "Apellido"),
            validator: _req,
            textInputAction: TextInputAction.next,
          ),
          TextFormField(
            controller: age,
            decoration: const InputDecoration(labelText: "Edad"),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              if (_req(v) != null) return "Requerido";
              final n = int.tryParse(v!.trim());
              if (n == null || n < 5 || n > 120) return "Edad inválida";
              return null;
            },
            textInputAction: TextInputAction.next,
          ),
          DropdownButtonFormField<String>(
            value: selectedNationality,
            items:
                nationalities
                    .map(
                      (n) => DropdownMenuItem<String>(value: n, child: Text(n)),
                    )
                    .toList(),
            onChanged: onSelectNationality,
            decoration: const InputDecoration(labelText: "Nacionalidad"),
            validator: (v) => v == null || v.isEmpty ? "Requerido" : null,
          ),
          TextFormField(
            controller: email,
            decoration: const InputDecoration(labelText: "Correo"),
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (_req(v) != null) return "Requerido";
              final ok = RegExp(r"^[^@]+@[^@]+\.[^@]+$").hasMatch(v!.trim());
              return ok ? null : "Correo inválido";
            },
            textInputAction: TextInputAction.next,
          ),
          TextFormField(
            controller: pass,
            decoration: InputDecoration(
              labelText: "Contraseña (mín. 8)",
              suffixIcon: IconButton(
                onPressed: onTogglePass,
                icon: Icon(showPass ? Icons.visibility_off : Icons.visibility),
              ),
            ),
            obscureText: !showPass,
            validator: (v) {
              if (_req(v) != null) return "Requerido";
              return v!.length >= 8 ? null : "Mínimo 8 caracteres";
            },
            textInputAction: TextInputAction.next,
          ),
          TextFormField(
            controller: pass2,
            decoration: const InputDecoration(labelText: "Repetir contraseña"),
            obscureText: !showPass,
            validator: _req,
          ),
          const SizedBox(height: 8),
          Text(
            "Tu edad y nacionalidad se guardarán junto con el registro.",
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
