# Resumen - Sistema de Lecciones

## Estado del Sistema

✅ Backend Django funcionando correctamente
✅ API de lecciones adaptativas implementada
✅ 5 lecciones creadas con ejercicios
✅ Sistema de progreso de usuario implementado
✅ Frontend Flutter conectado a la API

---

## Lecciones Disponibles

### Nivel A1 (Principiante)

#### 1. Saludos básicos (Vocabulario)
- **Ejercicios**: 5
- **Contenido**: Saludos comunes en inglés
- **Ejemplos de ejercicios**:
  - How do you say "Hola" in English?
  - What is the correct response to "How are you?"
  - Choose the correct greeting for the morning

#### 2. Preguntas comunes (Conversación)
- **Ejercicios**: 4
- **Contenido**: Preguntas básicas en inglés
- **Ejemplos de ejercicios**:
  - How do you ask someone's name in English?
  - Complete: "_____ are you from?"
  - How do you say "¿Cuántos años tienes?" in English?

### Nivel A2 (Elemental)

#### 3. Comida y restaurantes (Vocabulario)
- **Ejercicios**: 4
- **Contenido**: Vocabulario relacionado con comida y restaurantes
- **Ejemplos de ejercicios**:
  - What does "menu" mean in Spanish?
  - How do you ask for the bill in a restaurant?
  - What is "breakfast" in Spanish?

#### 4. Descripciones de personas (Vocabulario)
- **Ejercicios**: 3
- **Contenido**: Adjetivos para describir personas
- **Ejemplos de ejercicios**:
  - How do you say "alto" (tall) in English?
  - What does "friendly" mean?
  - Choose the correct word for "joven" in English

#### 5. Rutina diaria (Gramática)
- **Ejercicios**: 3
- **Contenido**: Verbos y expresiones de rutina diaria
- **Ejemplos de ejercicios**:
  - How do you say "I wake up" in Spanish?
  - What is the correct form: "I _____ my teeth every morning"
  - How do you say "almorzar" in English?

---

## Funcionamiento del Sistema

### 1. Lección Adaptativa

El sistema selecciona automáticamente la lección apropiada basándose en:
- **Nivel del usuario**: Las lecciones se filtran por el nivel asignado al usuario (A1, A2, B1, etc.)
- **Progreso del usuario**: Se excluyen las lecciones que el usuario ya completó
- **Prioridad**: Las lecciones tienen un campo de prioridad para ordenarlas

**Endpoint**: `GET /api/lessons/adaptive-lesson/`

**Respuesta exitosa**:
```json
{
  "id": 1,
  "title": "Saludos básicos",
  "content": "Aprende los saludos más comunes en inglés...",
  "level": "A1",
  "lesson_type": "vocabulary",
  "target_language": "en",
  "exercises": [
    {
      "id": 1,
      "question": "How do you say \"Hola\" in English?",
      "exercise_type": "multiple_choice",
      "target_language": "en",
      "native_language": "es",
      "options": [
        {"id": 1, "text": "Hello", "is_correct": true},
        {"id": 2, "text": "Goodbye", "is_correct": false},
        {"id": 3, "text": "Thanks", "is_correct": false},
        {"id": 4, "text": "Please", "is_correct": false}
      ]
    }
  ]
}
```

### 2. Guardar Progreso

Cuando el usuario completa una lección, se envía el progreso al backend:

**Endpoint**: `POST /api/lessons/lesson-progress/`

**Request**:
```json
{
  "lesson_id": 1,
  "completed": true,
  "score": 85.5
}
```

**Respuesta**:
```json
{
  "message": "Progreso actualizado exitosamente",
  "progress": {
    "lesson_id": 1,
    "completed": true,
    "score": 85.5
  }
}
```

### 3. Flujo en la App Flutter

1. Usuario hace clic en "Comenzar lección de hoy"
2. La app llama a `/api/lessons/adaptive-lesson/`
3. El backend devuelve una lección apropiada para el nivel del usuario
4. La app muestra la lección y sus ejercicios
5. Usuario responde los ejercicios uno por uno
6. Al finalizar, la app calcula el puntaje y lo envía a `/api/lessons/lesson-progress/`
7. El backend guarda el progreso del usuario

---

## Comandos Útiles

### Poblar ejercicios
```bash
cd "C:\Disco D\SW1\Sw1ProyectoFinal\backend"
python manage.py populate_exercises
```

### Ver lecciones en la base de datos
```bash
python manage.py shell -c "from leccion.models import Lesson; [print(f'{l.id}: {l.level} - {l.title} - Ejercicios: {l.exercises.count()}') for l in Lesson.objects.all()]"
```

### Ver progreso de un usuario
```bash
python manage.py shell -c "from leccion.models import UserLessonProgress; from users.models import User; u = User.objects.get(username='juan'); [print(f'{p.lesson.title}: {p.score}% - Completado: {p.completed}') for p in UserLessonProgress.objects.filter(user=u)]"
```

---

## Tipos de Ejercicios Soportados

El sistema soporta varios tipos de ejercicios:

1. **multiple_choice**: Opción múltiple (actualmente implementado)
2. **translation**: Traducción (pendiente)
3. **pronunciation**: Pronunciación (pendiente)
4. **shadowing**: Shadowing (pendiente)
5. **fill_blank**: Completar espacios (pendiente)

---

## Estructura de la Base de Datos

### Modelos Principales

- **Lesson**: Lecciones del curso
  - title, content, level, lesson_type, priority

- **Exercise**: Ejercicios de cada lección
  - lesson (FK), question, exercise_type

- **ExerciseOption**: Opciones de respuesta para cada ejercicio
  - exercise (FK), text, is_correct

- **UserLessonProgress**: Progreso del usuario
  - user (FK), lesson (FK), completed, score, completed_at

---

## Próximos Pasos Recomendados

1. **Crear más lecciones** para niveles B1, B2, y C1
2. **Implementar otros tipos de ejercicios** (traducción, pronunciación, etc.)
3. **Agregar sistema de recompensas** (puntos, medallas, logros)
4. **Implementar repetición espaciada** para vocabulario
5. **Agregar estadísticas detalladas** de progreso
6. **Crear pruebas de nivel** más completas

---

## Notas de Desarrollo

- Las lecciones se filtran automáticamente por el nivel del usuario
- El sistema evita mostrar lecciones ya completadas
- El puntaje se calcula como: (respuestas correctas / total de ejercicios) * 100
- Todos los ejercicios actuales son de tipo "multiple_choice"
- El sistema soporta múltiples idiomas (actualmente configurado para EN-ES)
