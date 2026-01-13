// lib/widgets/matching_exercise_widget.dart
import 'package:flutter/material.dart';
import 'dart:math';

class MatchingPair {
  final String source;
  final String target;

  MatchingPair({required this.source, required this.target});
}

class MatchingExerciseWidget extends StatefulWidget {
  final List<MatchingPair> pairs;
  final Function(Map<String, String> userMatches) onSubmit;
  final bool isSubmitted;
  final Map<String, bool>? validationResults; // null = not validated yet
  final int pairsPerPage; // Cantidad de pares por página

  const MatchingExerciseWidget({
    Key? key,
    required this.pairs,
    required this.onSubmit,
    this.isSubmitted = false,
    this.validationResults,
    this.pairsPerPage = 5, // Por defecto 5 pares por página
  }) : super(key: key);

  @override
  State<MatchingExerciseWidget> createState() => _MatchingExerciseWidgetState();
}

class _MatchingExerciseWidgetState extends State<MatchingExerciseWidget> {
  // Mapea fuente -> objetivo seleccionado
  final Map<String, String> _userMatches = {};
  int _currentPage = 0;

  int get _totalPages => (widget.pairs.length / widget.pairsPerPage).ceil();

  List<MatchingPair> get _currentPagePairs {
    final startIndex = _currentPage * widget.pairsPerPage;
    final endIndex = min(startIndex + widget.pairsPerPage, widget.pairs.length);
    return widget.pairs.sublist(startIndex, endIndex);
  }

  // Obtener solo los targets de la página actual y mezclarlos
  List<String> get _currentPageTargets {
    final targets = _currentPagePairs.map((p) => p.target).toList();
    targets.shuffle(Random());
    return targets;
  }

  bool get _currentPageComplete {
    return _currentPagePairs.every(
      (pair) => _userMatches.containsKey(pair.source),
    );
  }

  void _selectMatch(String source, String target) {
    if (widget.isSubmitted) return; // No permitir cambios después de enviar

    setState(() {
      // Si este target ya estaba asignado a otra fuente, quitarlo
      _userMatches.removeWhere((key, value) => value == target);

      // Asignar el nuevo match
      if (_userMatches[source] == target) {
        // Si se clickea el mismo, deseleccionar
        _userMatches.remove(source);
      } else {
        _userMatches[source] = target;
      }

      // Notificar al padre inmediatamente con los pares actuales
      widget.onSubmit(_userMatches);
    });
  }

  IconData? _getValidationIcon(String source) {
    if (widget.validationResults == null) return null;
    final isCorrect = widget.validationResults![source];
    if (isCorrect == null) return null;
    return isCorrect ? Icons.check_circle : Icons.cancel;
  }

  Color? _getValidationColor(String source) {
    if (widget.validationResults == null) return null;
    final isCorrect = widget.validationResults![source];
    if (isCorrect == null) return null;
    return isCorrect ? Colors.green : Colors.red;
  }

  bool get _allMatched => _userMatches.length == widget.pairs.length;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Indicador de progreso
        if (_totalPages > 1) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Página ${_currentPage + 1} de $_totalPages',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                '${_userMatches.length}/${widget.pairs.length} emparejados',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _userMatches.length / widget.pairs.length,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
          ),
          const SizedBox(height: 16),
        ],

        Text(
          'Empareja cada término con su traducción correcta:',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Área de emparejamiento - solo pares de la página actual
        ..._currentPagePairs.map((pair) {
          final selectedTarget = _userMatches[pair.source];
          final validationIcon = _getValidationIcon(pair.source);
          final validationColor = _getValidationColor(pair.source);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                // Término origen (izquierda)
                Expanded(
                  flex: 5,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200, width: 2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            pair.source,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (validationIcon != null)
                          Icon(
                            validationIcon,
                            color: validationColor,
                            size: 24,
                          ),
                      ],
                    ),
                  ),
                ),

                // Icono de conexión
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.arrow_forward,
                    color:
                        selectedTarget != null
                            ? Colors.blue.shade600
                            : Colors.grey.shade400,
                  ),
                ),

                // Selector de traducción (derecha)
                Expanded(
                  flex: 5,
                  child: PopupMenuButton<String>(
                    enabled: !widget.isSubmitted,
                    onSelected: (target) => _selectMatch(pair.source, target),
                    itemBuilder: (context) {
                      return _currentPageTargets.map((target) {
                        // Marcar si ya está usado
                        final isUsed =
                            _userMatches.values.contains(target) &&
                            _userMatches[pair.source] != target;

                        return PopupMenuItem<String>(
                          value: target,
                          enabled: !isUsed,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  target,
                                  style: TextStyle(
                                    color: isUsed ? Colors.grey : Colors.black,
                                    fontWeight:
                                        _userMatches[pair.source] == target
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (_userMatches[pair.source] == target)
                                Icon(Icons.check, color: Colors.blue, size: 20),
                            ],
                          ),
                        );
                      }).toList();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color:
                            selectedTarget != null
                                ? (validationColor != null
                                    ? validationColor.withOpacity(0.1)
                                    : Colors.green.shade50)
                                : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              selectedTarget != null
                                  ? (validationColor ?? Colors.green.shade300)
                                  : Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              selectedTarget ?? 'Selecciona...',
                              style: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.copyWith(
                                color:
                                    selectedTarget != null
                                        ? Colors.black87
                                        : Colors.grey.shade500,
                                fontWeight:
                                    selectedTarget != null
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            color:
                                selectedTarget != null
                                    ? Colors.blue.shade600
                                    : Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 16),

        // Botones de navegación entre páginas
        if (_totalPages > 1 && !widget.isSubmitted) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                onPressed:
                    _currentPage > 0
                        ? () => setState(() => _currentPage--)
                        : null,
                icon: const Icon(Icons.chevron_left),
                label: const Text('Anterior'),
              ),
              Text(
                'Página ${_currentPage + 1}/$_totalPages',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed:
                    _currentPage < _totalPages - 1 && _currentPageComplete
                        ? () => setState(() => _currentPage++)
                        : null,
                icon: const Icon(Icons.chevron_right),
                label: const Text('Siguiente'),
              ),
            ],
          ),
          if (_currentPage < _totalPages - 1 && !_currentPageComplete)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Completa todos los emparejamientos de esta página antes de continuar',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.orange[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],

        // Indicador de progreso global (solo si hay múltiples páginas)
        if (_totalPages <= 1 && !widget.isSubmitted) ...[
          LinearProgressIndicator(
            value:
                widget.pairs.isEmpty
                    ? 0
                    : _userMatches.length / widget.pairs.length,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(
              _allMatched ? Colors.green : Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Emparejados: ${_userMatches.length} de ${widget.pairs.length}',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
          ),
        ],

        // Mostrar resumen de validación si está disponible
        if (widget.isSubmitted && widget.validationResults != null) ...[
          const SizedBox(height: 12),
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Correctos: ${widget.validationResults!.values.where((v) => v).length} / ${widget.pairs.length}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
