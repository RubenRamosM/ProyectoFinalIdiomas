# Guía Rápida - Proyecto Idiomas

## Estado Actual del Proyecto

✅ **Backend configurado y corriendo**
✅ **Base de datos Neon conectada**
✅ **Usuarios de prueba creados**
✅ **Migraciones aplicadas**

## Servidor Backend

El servidor Django está corriendo en:
- **Localhost**: http://127.0.0.1:8000
- **Red local**: http://192.168.1.12:8000

### Verificar que el servidor está corriendo

```bash
# En una nueva terminal
curl http://127.0.0.1:8000/api/auth/token/
```

## Usuarios de Prueba

Se crearon 5 usuarios para testing:

| Usuario | Email | Password | Nivel |
|---------|-------|----------|-------|
| juan | juan@test.com | Test1234 | A1 |
| maria | maria@test.com | Test1234 | A2 |
| pedro | pedro@test.com | Test1234 | B1 |
| ana | ana@test.com | Test1234 | B2 |
| carlos | carlos@test.com | Test1234 | C1 |

## Configuración Flutter

### 1. Configurar URL del Backend

Edita el archivo: `flutter/idiomasapp/lib/config.dart`

```dart
class Config {
  // Para emulador Android usa:
  static const String baseUrl = 'http://10.0.2.2:8000';

  // Para dispositivo físico en la misma red usa:
  // static const String baseUrl = 'http://192.168.1.12:8000';

  // Para dispositivo físico con localtunnel/ngrok, ver más abajo
}
```

### 2. Verificar permisos en AndroidManifest.xml

Archivo: `flutter/idiomasapp/android/app/src/main/AndroidManifest.xml`

Debe incluir:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

## Solución de Problemas

### Error: ERR_CONNECTION_TIMED_OUT

**Problema**: El dispositivo móvil no puede conectarse al backend.

**Soluciones**:

#### Opción A: Usar Emulador Android
- El emulador Android usa `10.0.2.2` para acceder a localhost
- Cambia `baseUrl` en `config.dart` a: `http://10.0.2.2:8000`

#### Opción B: Dispositivo Físico en la misma red WiFi
1. Asegúrate que tu PC y el dispositivo estén en la misma red WiFi
2. Verifica tu IP local:
   ```bash
   ipconfig  # Windows
   # Busca "IPv4 Address" en tu adaptador WiFi
   ```
3. Cambia `baseUrl` a: `http://TU_IP_LOCAL:8000`
4. Verifica que el firewall de Windows permita conexiones en el puerto 8000

#### Opción C: Usar localtunnel/ngrok (dispositivo en otra red)

**Con localtunnel** (gratis):
```bash
# Instalar (solo una vez)
npm install -g localtunnel

# Ejecutar
lt --port 8000 --subdomain mi-app-idiomas
```

**Con ngrok** (requiere cuenta):
```bash
ngrok http 8000
```

Luego usa la URL pública en `config.dart`:
```dart
static const String baseUrl = 'https://tu-url.loca.lt';
```

### Problema: Registro no funciona

**Verificar campos requeridos**:

El endpoint de registro (`POST /api/auth/register/`) requiere:

```json
{
  "username": "usuario123",
  "email": "usuario@ejemplo.com",
  "password": "Password123",
  "password2": "Password123",
  "first_name": "Nombre",
  "last_name": "Apellido",
  "native_language": "es",
  "target_language": "en"
}
```

Campos opcionales:
- `age`: número entre 5 y 120
- `level`: "A1", "A2", "B1", "B2", "C1"
- `nationality`: texto libre

**Validaciones**:
- Email debe ser único
- Password mínimo 8 caracteres
- password y password2 deben coincidir

### Probar el Registro con curl

```bash
# Probar registro desde la terminal
curl -X POST http://127.0.0.1:8000/api/auth/register/ \
  -H "Content-Type: application/json" \
  -d "{
    \"username\":\"testuser\",
    \"email\":\"test@example.com\",
    \"password\":\"Test1234\",
    \"password2\":\"Test1234\",
    \"first_name\":\"Test\",
    \"last_name\":\"User\",
    \"native_language\":\"es\",
    \"target_language\":\"en\"
  }"
```

### Probar el Login con curl

```bash
# Obtener token JWT
curl -X POST http://127.0.0.1:8000/api/auth/token/ \
  -H "Content-Type: application/json" \
  -d "{
    \"username\":\"maria\",
    \"password\":\"Test1234\"
  }"
```

## Estructura del Proyecto

```
ProyectoFinalIdiomas/
├── backend/                 # Django Backend
│   ├── .env                # ⚠️ NO en Git (credenciales)
│   ├── .env.example        # Plantilla de variables
│   ├── manage.py
│   ├── requirements.txt
│   ├── users/              # Autenticación
│   ├── leccion/            # Lecciones
│   ├── ia/                 # Tutor IA, Whisper
│   ├── test/               # Tests de nivel
│   └── support/            # Soporte
│
└── flutter/idiomasapp/     # App Flutter
    ├── lib/
    │   ├── config.dart     # ⚠️ Configurar aquí la URL
    │   ├── screens/
    │   └── services/
    └── pubspec.yaml
```

## Comandos Útiles

### Backend

```bash
cd backend

# Iniciar servidor
python manage.py runserver 0.0.0.0:8000

# Crear migraciones
python manage.py makemigrations

# Aplicar migraciones
python manage.py migrate

# Crear superusuario
python manage.py createsuperuser

# Crear usuarios de prueba
python manage.py create_test_users
```

### Flutter

```bash
cd flutter/idiomasapp

# Instalar dependencias
flutter pub get

# Ejecutar en emulador/dispositivo
flutter run

# Ver dispositivos conectados
flutter devices

# Limpiar build
flutter clean
```

## Endpoints API Principales

### Autenticación
- `POST /api/auth/register/` - Registro
- `POST /api/auth/token/` - Login (obtener JWT)
- `POST /api/auth/token/refresh/` - Refrescar token
- `GET /api/auth/me/` - Información del usuario actual

### Lecciones
- `GET /api/lecciones/` - Lista de lecciones
- `GET /api/lecciones/{id}/` - Detalle de lección
- `GET /api/lecciones/{id}/exercises/` - Ejercicios

### Tutor IA
- `POST /api/ia/tutor/conversations/` - Nueva conversación
- `GET /api/ia/tutor/conversations/` - Historial
- `POST /api/ia/tutor/conversations/{id}/messages/` - Enviar mensaje

### WebSocket
- `ws://localhost:8000/ws/translator/?token={jwt}` - Traductor en tiempo real

## Próximos Pasos

1. **Configurar Flutter**: Edita `lib/config.dart` con la URL correcta
2. **Probar Login**: Usa uno de los usuarios de prueba
3. **Verificar Conexión**: Asegúrate que el dispositivo puede conectarse
4. **Cargar Datos**: Ejecuta los comandos de seeding si necesitas lecciones

## Recursos

- **Groq API**: https://console.groq.com
- **Neon Database**: https://neon.tech
- **Documentación Django**: https://docs.djangoproject.com
- **Documentación Flutter**: https://docs.flutter.dev

## Soporte

Si encuentras problemas:
1. Verifica que el servidor esté corriendo
2. Revisa la URL en `config.dart`
3. Verifica los logs del servidor Django
4. Prueba con curl/Postman primero
5. Verifica permisos de red/firewall
