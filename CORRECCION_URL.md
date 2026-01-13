# Corrección - Error "No se pudo cargar la lección"

## Problema Identificado

El error "No se pudo cargar la lección" se debía a una URL mal formada en las peticiones HTTP.

### Logs del Servidor

```
Not Found: /api//lessons/adaptive-lesson/
[10/Oct/2025 04:38:10] "GET /api//lessons/adaptive-lesson/ HTTP/1.1" 404
```

Nótese el **doble slash** (`//`) en la URL: `/api//lessons/` en lugar de `/api/lessons/`

## Causa Raíz

El problema estaba en `lib/config.dart`:

**ANTES** (incorrecto):
```dart
const String kApiBase = 'http://192.168.0.102:8000/api/'; // ← termina con /
```

Cuando el código concatenaba:
```dart
Uri.parse('${Api.baseUrl}/lessons/adaptive-lesson/')
```

Resultaba en:
```
http://192.168.0.102:8000/api//lessons/adaptive-lesson/
                              ^^
                         doble slash
```

## Solución Aplicada

**DESPUÉS** (correcto):
```dart
const String kApiBase = 'http://192.168.0.102:8000/api'; // ← sin / final
```

Ahora cuando concatena:
```dart
Uri.parse('${Api.baseUrl}/lessons/adaptive-lesson/')
```

Resulta en:
```
http://192.168.0.102:8000/api/lessons/adaptive-lesson/
                              ^
                         un solo slash
```

## Archivos Modificados

- `flutter/idiomasapp/lib/config.dart` - Se quitó el `/` final de `kApiBase`

## Verificación

Todos los usos de `Api.baseUrl` en el código ya tienen el `/` al inicio de la ruta:

✅ `/lessons/adaptive-lesson/`
✅ `/lessons/lesson-progress/`
✅ `/lessons/spaced-repetition/`
✅ `/lessons/pronunciation-feedback/`
✅ `/lessons/shadowing-exercise/`
✅ `/users/stats/`
✅ `/users/progress/`

## Prueba

Para probar que la corrección funciona:

1. **Reinicia la app** Flutter (hot restart completo)
2. Inicia sesión con un usuario (ej: `juan` / `Test1234`)
3. Haz clic en **"Comenzar lección de hoy"**
4. Deberías ver la lección "Saludos básicos" con 5 ejercicios

## Nota Importante

Si modificas la URL en `config.dart` en el futuro, asegúrate de:
- **NO** terminar con `/` si las rutas en el código empiezan con `/`
- **SÍ** terminar con `/` si las rutas en el código NO empiezan con `/`

En este proyecto, todas las rutas empiezan con `/`, por lo tanto `kApiBase` NO debe terminar con `/`.
