import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/user_service.dart';
import '../services/api.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _me;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final m = await UserService.me();
      setState(() {
        _me = m;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // helper row removed — layout replaced by ListTile-based cards for a cleaner look

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Editar perfil',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Función de edición pendiente')),
              );
            },
          ),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Error: $_error',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: _load,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header card with avatar and summary
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary.withOpacity(0.12),
                              Colors.white,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: theme.colorScheme.primary,
                              child: Text(
                                ((_me?['first_name'] as String? ?? '')
                                            .isNotEmpty
                                        ? (_me?['first_name'] as String)[0]
                                        : '?')
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_me?['first_name'] ?? ''} ${_me?['last_name'] ?? ''}'
                                            .trim()
                                            .isEmpty
                                        ? 'Usuario'
                                        : '${_me?['first_name'] ?? ''} ${_me?['last_name'] ?? ''}',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      Chip(
                                        label: Text(
                                          (_me?['level'] as String?) ??
                                              'Nivel: -',
                                        ),
                                        avatar: const Icon(
                                          Icons.school,
                                          size: 18,
                                        ),
                                      ),
                                      Chip(
                                        label: Text(
                                          (_me?['native_language']
                                                  as String?) ??
                                              '-',
                                        ),
                                        avatar: const Icon(
                                          Icons.language,
                                          size: 18,
                                        ),
                                      ),
                                      Chip(
                                        label: Text(
                                          (_me?['target_language']
                                                  as String?) ??
                                              '-',
                                        ),
                                        avatar: const Icon(
                                          Icons.translate,
                                          size: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Details card
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 6,
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.person_outline),
                              title: const Text('Nombre'),
                              subtitle: Text(
                                '${_me?['first_name'] ?? ''} ${_me?['last_name'] ?? ''}'
                                        .trim()
                                        .isEmpty
                                    ? '-'
                                    : '${_me?['first_name'] ?? ''} ${_me?['last_name'] ?? ''}',
                              ),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.email_outlined),
                              title: const Text('Email'),
                              subtitle: Text(_me?['email'] as String? ?? '-'),
                              trailing: IconButton(
                                icon: const Icon(Icons.copy_outlined),
                                tooltip: 'Copiar email',
                                onPressed: () {
                                  final email = _me?['email'] as String?;
                                  if (email != null && email.isNotEmpty) {
                                    Clipboard.setData(
                                      ClipboardData(text: email),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Email copiado al portapapeles',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.flag_outlined),
                              title: const Text('Nacionalidad'),
                              subtitle: Text(
                                _me?['nationality'] as String? ?? '-',
                              ),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.public),
                              title: const Text('Servidor API'),
                              subtitle: Text(Api.baseUrl),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              setState(() {
                                _loading = true;
                                _error = null;
                              });
                              await _load();
                            },
                            child: const Text('Actualizar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              // Placeholder: si existe UserService.logout se puede llamar aquí
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Cerrar sesión (pendiente)'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.logout),
                            label: const Text('Cerrar sesión'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    Center(
                      child: Text(
                        '¡Gracias por usar la app! Sigue practicando todos los días.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
