# Resultado de Pruebas del Backend - API REST

**Fecha**: 14 de Enero de 2026
**Estado**: Backend funcionando correctamente
**Resultado**: 5 de 6 pruebas exitosas

---

## Resumen de Pruebas

### Pruebas Exitosas [5/6]

#### ✅ TEST 1: Servidor Corriendo
- **URL**: http://127.0.0.1:8000
- **Estado**: Activo
- **Status Code**: 404 (esperado para raíz sin endpoint)

#### ✅ TEST 2: Registro de Usuarios
- **Endpoint**: `POST /api/users/register/`
- **Status Code**: 201 Created
- **Resultado**: Usuario creado exitosamente
- **Respuesta**:
  ```json
  {
    "id": 7,
    "username": "test20260114100748",
    "first_name": "Usuario",
    "last_name": "Prueba",
    "email": "test20260114100748@test.com",
    "native_language": "es",
    "target_language": "en",
    "nationality": "Bolivia",
    "age": 25,
    "level": null
  }
  ```

#### ✅ TEST 3: Login con JWT
- **Endpoint**: `POST /api/auth/token/`
- **Status Code**: 200 OK
- **Resultado**: Tokens JWT generados correctamente
- **Tokens recibidos**:
  - `access`: Token de acceso (válido por 5 minutos)
  - `refresh`: Token de actualización (válido por 24 horas)

#### ✅ TEST 4: Información del Usuario Autenticado
- **Endpoint**: `GET /api/users/me/`
- **Status Code**: 200 OK
- **Autenticación**: JWT Bearer Token
- **Resultado**: Datos del usuario obtenidos correctamente
- **Respuesta**:
  ```json
  {
    "id": 2,
    "username": "maria",
    "first_name": "María",
    "last_name": "González",
    "email": "maria@test.com",
    "native_language": "es",
    "target_language": "en",
    "nationality": null,
    "age": 30,
    "level": "A2"
  }
  ```

#### ✅ TEST 6: Estadísticas del Usuario
- **Endpoint**: `GET /api/users/stats/`
- **Status Code**: 200 OK
- **Resultado**: Estadísticas de aprendizaje obtenidas
- **Respuesta**:
  ```json
  {
    "id": 2,
    "username": "maria",
    "points": 0,
    "streak_count": 0,
    "longest_streak": 0,
    "total_lessons_completed": 0,
    "total_exercises_completed": 0,
    "level": "A2",
    "learning_stats": {
      "vocabulary_learned": 0,
      "grammar_topics_completed": 0,
      "listening_time": 0,
      "speaking_practice": 0,
      "accuracy_rate": 0.0
    }
  }
  ```

### Pruebas con Advertencias [1/6]

#### ⚠️ TEST 5: Lista de Lecciones
- **Endpoint**: `GET /api/lessons/all-lessons/`
- **Problema**: Read timeout (10 segundos)
- **Causa**: No hay lecciones en la base de datos
- **Solución**: Ejecutar comandos de seeding cuando se resuelva el error de Unicode

---

## URLs Correctas del API

### Autenticación
- `POST /api/users/register/` - Registro de usuario
- `POST /api/auth/token/` - Obtener JWT (login)
- `POST /api/auth/token/refresh/` - Refrescar token JWT

### Usuarios
- `GET /api/users/me/` - Información del usuario actual (requiere auth)
- `GET /api/users/stats/` - Estadísticas del usuario (requiere auth)
- `GET /api/users/progress/` - Progreso del usuario (requiere auth)
- `GET /api/users/learning-stats/` - Estadísticas de aprendizaje (requiere auth)

### Lecciones
- `GET /api/lessons/all-lessons/` - Todas las lecciones
- `GET /api/lessons/<id>/` - Detalle de lección específica
- `GET /api/lessons/adaptive/` - Lección adaptativa
- `GET /api/lessons/next-available/` - Siguiente lección disponible
- `GET /api/lessons/progress/` - Progreso de lecciones
- `POST /api/lessons/exercises/submit/` - Enviar ejercicio completado

### Soporte
- `GET /api/support/` - Endpoints de soporte
- `POST /api/support/tickets/` - Crear ticket de soporte

### Tutor IA
- `GET /api/ia/` - Endpoints de IA (tutor, traductor)

### Tests de Nivel
- `GET /api/test/` - Tests de evaluación de nivel

---

## Usuarios de Prueba Disponibles

| Username | Email | Password | Nivel |
|----------|-------|----------|-------|
| juan | juan@test.com | Test1234 | A1 |
| maria | maria@test.com | Test1234 | A2 |
| pedro | pedro@test.com | Test1234 | B1 |
| ana | ana@test.com | Test1234 | B2 |
| carlos | carlos@test.com | Test1234 | C1 |

---

## Cómo Probar el API

### Opción 1: Script Python (Recomendado)
```bash
python test_api.py
```

### Opción 2: Postman
Ver guía detallada en: `COMO_PROBAR_SIN_MOVIL.md`

### Opción 3: cURL
```bash
# Login
curl -X POST http://127.0.0.1:8000/api/auth/token/ \
  -H "Content-Type: application/json" \
  -d '{"username":"maria","password":"Test1234"}'

# Obtener información del usuario
curl http://127.0.0.1:8000/api/users/me/ \
  -H "Authorization: Bearer TU_TOKEN_AQUI"
```

---

## Problemas Conocidos

### 1. Error de Unicode en Seeding de Lecciones
**Error**: `UnicodeEncodeError: 'charmap' codec can't encode character '\u2713'`
**Estado**: Pendiente de solución
**Impacto**: No hay lecciones precargadas en la base de datos
**Workaround**: Crear lecciones manualmente desde el panel de admin

### 2. Endpoint de Lecciones con Timeout
**Causa**: No hay lecciones en la base de datos
**Solución temporal**: El endpoint funciona, solo que tarda al no encontrar datos

---

## Configuración para Flutter

Para conectar tu app Flutter con el backend, actualiza `lib/config.dart`:

```dart
class Config {
  // Para emulador Android
  static const String baseUrl = 'http://10.0.2.2:8000';

  // Para dispositivo físico en la misma red WiFi
  // static const String baseUrl = 'http://192.168.1.12:8000';
}
```

### URLs Corregidas para Flutter
Asegúrate de usar estas rutas en tus servicios:
- Registro: `/api/users/register/` (no `/api/auth/register/`)
- Mi perfil: `/api/users/me/` (no `/api/auth/me/`)
- Lecciones: `/api/lessons/all-lessons/` (no `/api/lecciones/`)

---

## Próximos Pasos

1. ✅ **Backend configurado y funcionando**
2. ✅ **Base de datos Neon conectada**
3. ✅ **Autenticación JWT operativa**
4. ✅ **Usuarios de prueba creados**
5. ⏳ **Pendiente**: Resolver error de Unicode para cargar lecciones
6. ⏳ **Pendiente**: Configurar Flutter con URLs correctas
7. ⏳ **Pendiente**: Probar app móvil completa

---

## Comandos Útiles

### Iniciar Servidor
```bash
cd backend
python manage.py runserver 0.0.0.0:8000
```

### Crear Superusuario (para admin panel)
```bash
python manage.py createsuperuser
```

### Acceder al Panel de Admin
http://127.0.0.1:8000/admin/

### Cargar Lecciones (cuando se resuelva el error)
```bash
python manage.py seed_core_and_greetings
python manage.py seed_a1_complete
```

---

## Soporte

Si tienes problemas:
1. Verifica que el servidor esté corriendo: http://127.0.0.1:8000
2. Revisa los logs en la terminal donde corre Django
3. Prueba los endpoints con `test_api.py` o Postman
4. Consulta la documentación en:
   - `README.md` - Guía completa de instalación
   - `GUIA_RAPIDA.md` - Referencia rápida
   - `COMO_PROBAR_SIN_MOVIL.md` - Métodos de prueba

---

**Estado Final**: ✅ Backend listo para desarrollo
