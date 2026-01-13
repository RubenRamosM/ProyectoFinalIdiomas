# Aplicación de Aprendizaje de Idiomas

Proyecto final de Ingeniería de Software 1 - Una aplicación completa para el aprendizaje de múltiples idiomas con inteligencia artificial.

## Características Principales

- **Tutor Inteligente con IA**: Asistente conversacional 24/7 usando Groq (Llama 3.3)
- **Reconocimiento de Voz**: Transcripción y evaluación de pronunciación con OpenAI Whisper
- **Ejercicios Interactivos**: Multiple choice, completar oraciones, ordenar palabras, matching
- **Sistema de Lecciones**: Contenido estructurado por niveles (A1-C2)
- **Traductor en Tiempo Real**: WebSocket para traducción instantánea
- **Soporte y Tickets**: Sistema completo de ayuda al usuario
- **Estadísticas de Progreso**: Seguimiento de racha, logros y rendimiento

## Tecnologías

### Backend
- Django 5.2.6 + Django REST Framework
- PostgreSQL (Neon Serverless)
- Django Channels (WebSockets)
- Celery (tareas asíncronas)
- JWT Authentication
- Groq API (IA conversacional)
- OpenAI Whisper (ASR)
- gTTS (Text-to-Speech)

### Frontend
- Flutter 3.7+
- Dio (HTTP client)
- WebSocket Client
- Speech-to-Text
- Google ML Kit
- Lottie (animaciones)

## Requisitos Previos

### Sistema
- Windows 11 (o Windows 10)
- Python 3.10+
- Flutter SDK 3.7+
- ffmpeg (requerido para Whisper)

### Cuentas y API Keys
- Cuenta en [Groq Console](https://console.groq.com) (gratis)
- Cuenta en [Neon](https://neon.tech) (gratis)

## Instalación

### 1. Clonar el Repositorio

```bash
git clone https://github.com/RubenRamosM/ProyectoFinalIdiomas.git
cd ProyectoFinalIdiomas
```

### 2. Instalar ffmpeg

**Opción A - Con winget (Recomendado):**
```bash
winget install ffmpeg
```

**Opción B - Manual:**
1. Descargar de https://www.gyan.dev/ffmpeg/builds/
2. Extraer en `C:\ffmpeg`
3. Agregar `C:\ffmpeg\bin` al PATH

**Verificar instalación:**
```bash
ffmpeg -version
```

### 3. Configurar Backend

#### 3.1. Crear entorno virtual

```bash
cd backend
python -m venv venv
```

#### 3.2. Activar entorno virtual

```bash
# Windows CMD
venv\Scripts\activate

# Windows PowerShell
venv\Scripts\Activate.ps1

# Git Bash
source venv/Scripts/activate
```

#### 3.3. Instalar dependencias

```bash
pip install -r requirements.txt
```

#### 3.4. Configurar variables de entorno

El proyecto ya incluye un archivo `.env.example`. Copia y renombra:

```bash
copy .env.example .env
```

Edita el archivo `.env` con tus credenciales:

```env
# Obtén tu Groq API Key en: https://console.groq.com/keys
GROQ_API_KEY=tu_api_key_aqui

# Configura tu base de datos Neon
DB_NAME=tu_database
DB_USER=tu_usuario
DB_PASSWORD=tu_password
DB_HOST=tu-proyecto.neon.tech
DB_PORT=5432
```

#### 3.5. Configurar Base de Datos Neon

**Opción A - Usar el proyecto existente:**

Ya se creó un proyecto en Neon con estas credenciales:
- **Database**: neondb
- **Host**: ep-crimson-sun-ahmfa3uv-pooler.c-3.us-east-1.aws.neon.tech
- **User**: neondb_owner

**Opción B - Crear tu propio proyecto:**

1. Ve a https://neon.tech
2. Crea una cuenta (gratis)
3. Crea un nuevo proyecto
4. Copia las credenciales de conexión al archivo `.env`

#### 3.6. Ejecutar migraciones

```bash
python manage.py migrate
```

#### 3.7. Crear superusuario (opcional)

```bash
python manage.py createsuperuser
```

#### 3.8. Cargar datos de ejemplo (lecciones)

```bash
python manage.py seed_core_and_greetings
python manage.py seed_a1_complete
python manage.py seed_placement_questions
python manage.py create_sample_faqs
```

#### 3.9. Iniciar servidor

```bash
python manage.py runserver
```

El servidor estará disponible en: http://127.0.0.1:8000

### 4. Configurar Frontend (Flutter)

#### 4.1. Instalar dependencias

```bash
cd ../flutter/idiomasapp
flutter pub get
```

#### 4.2. Configurar URL del backend

Edita `lib/config.dart` y ajusta la URL del backend si es necesario:

```dart
class Config {
  static const String baseUrl = 'http://127.0.0.1:8000';
  // Para dispositivo físico usa tu IP local: 'http://192.168.X.X:8000'
}
```

#### 4.3. Ejecutar aplicación

**Emulador Android:**
```bash
flutter run
```

**Dispositivo físico:**
1. Habilita depuración USB en tu dispositivo
2. Conecta el dispositivo
3. Ejecuta `flutter run`

## Estructura del Proyecto

```
ProyectoFinalIdiomas/
├── backend/
│   ├── users/              # Autenticación y gestión de usuarios
│   ├── leccion/            # Lecciones y ejercicios
│   ├── ia/                 # Tutor inteligente y servicios IA
│   │   ├── services/
│   │   │   ├── tutor_service.py      # Groq chat
│   │   │   ├── asr_whisper.py        # Whisper ASR
│   │   │   └── groq_translator.py    # Traductor
│   │   ├── consumers.py    # WebSocket consumers
│   │   └── views_tutor.py  # API del tutor
│   ├── test/               # Tests de nivel
│   ├── support/            # Sistema de soporte
│   ├── core/               # Modelos base
│   ├── idiomasapp/         # Configuración Django
│   ├── manage.py
│   └── requirements.txt
│
└── flutter/idiomasapp/
    ├── lib/
    │   ├── screens/        # Pantallas de la app
    │   ├── services/       # Servicios API
    │   ├── models/         # Modelos de datos
    │   └── widgets/        # Componentes reutilizables
    └── pubspec.yaml
```

## Obtener API Keys

### Groq API (Tutor Inteligente)

1. Ve a https://console.groq.com
2. Crea una cuenta (gratis)
3. Ve a "API Keys": https://console.groq.com/keys
4. Crea una nueva key
5. Copia la key al archivo `.env`

**Límites gratuitos:**
- 30 requests/minuto
- 14,400 tokens/minuto
- Suficiente para desarrollo

### Neon Database

1. Ve a https://neon.tech
2. Crea una cuenta
3. Crea un nuevo proyecto
4. En "Connection Details", copia:
   - Host
   - Database name
   - User
   - Password
5. Pega en el archivo `.env`

**Límites gratuitos:**
- 0.5 GB de almacenamiento
- 1 proyecto
- Ideal para desarrollo

## Configuración de Whisper

El proyecto usa OpenAI Whisper para reconocimiento de voz. Puedes configurar el modelo en `.env`:

```env
# Modelos disponibles (de menor a mayor precisión/recursos):
# tiny   - Más rápido, menos preciso (~1GB RAM)
# base   - Balance básico (~1GB RAM)
# small  - Recomendado para desarrollo (~2GB RAM)
# medium - Más preciso (~5GB RAM)
# large  - Máxima precisión (~10GB RAM)

WHISPER_MODEL=small
```

## Uso de la Aplicación

### Usuarios de Prueba

Puedes crear usuarios de prueba con:

```bash
python manage.py create_test_users
```

### Funcionalidades Principales

1. **Registro e Inicio de Sesión**: JWT authentication
2. **Test de Nivel**: Evalúa tu nivel actual (A1-C2)
3. **Lecciones por Nivel**: Accede a contenido estructurado
4. **Ejercicios Interactivos**: Practica con diferentes tipos de ejercicios
5. **Tutor IA**: Pregunta cualquier duda sobre el idioma
6. **Traductor en Vivo**: Traducción instantánea con voz
7. **Estadísticas**: Revisa tu progreso y racha de aprendizaje
8. **Soporte**: Crea tickets para resolver problemas

## Endpoints API Principales

### Autenticación
- `POST /api/auth/register/` - Registro
- `POST /api/auth/token/` - Login (obtener JWT)
- `POST /api/auth/token/refresh/` - Refrescar token

### Lecciones
- `GET /api/lecciones/` - Lista de lecciones
- `GET /api/lecciones/{id}/` - Detalle de lección
- `GET /api/lecciones/{id}/exercises/` - Ejercicios de lección

### Tutor IA
- `POST /api/ia/tutor/conversations/` - Crear conversación
- `POST /api/ia/tutor/conversations/{id}/messages/` - Enviar mensaje
- `GET /api/ia/tutor/conversations/` - Historial

### WebSocket
- `ws://localhost:8000/ws/translator/?token={jwt}` - Traductor en tiempo real

## Solución de Problemas

### Error: "Whisper model not available"
- Verifica que ffmpeg esté instalado: `ffmpeg -version`
- Verifica que ffmpeg esté en el PATH
- Reinstala openai-whisper: `pip install -U openai-whisper`

### Error: "GROQ_API_KEY no configurada"
- Verifica que el archivo `.env` existe en `backend/`
- Verifica que la variable GROQ_API_KEY está configurada
- Reinicia el servidor Django

### Error de conexión a base de datos
- Verifica las credenciales en `.env`
- Verifica que tu IP está permitida en Neon (por defecto permite todas)
- Prueba la conexión: `psql "postgresql://user:pass@host/db"`

### Flutter no encuentra el backend
- Si usas emulador Android, usa `10.0.2.2:8000` en lugar de `localhost`
- Si usas dispositivo físico, usa tu IP local (ej: `192.168.1.X:8000`)
- Verifica que el backend esté corriendo

## Contribución

Este es un proyecto académico de Ingeniería de Software 1.

## Licencia

Proyecto académico - Universidad

## Autores

Proyecto Final - Ingeniería de Software 1

## Documentación Adicional

Ver archivos en el repositorio:
- `TUTOR_INTELIGENTE.md` - Detalles del tutor con IA
- `WHISPER_IMPLEMENTACION.md` - Implementación de reconocimiento de voz
- `RESUMEN_LECCIONES.md` - Sistema de lecciones
- `RESUMEN_SOPORTE.md` - Sistema de soporte
