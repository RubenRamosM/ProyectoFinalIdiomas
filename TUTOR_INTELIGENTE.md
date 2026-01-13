# Tutor Inteligente - Funcionalidad Completa

## 📚 Descripción

El **Tutor Inteligente** es una nueva funcionalidad que permite a los usuarios interactuar con un asistente de inteligencia artificial disponible 24/7 para resolver dudas sobre el aprendizaje de idiomas. Utiliza Groq (LLaMA 3.3 70B) para generar respuestas naturales, contextualizadas y educativas.

## ✨ Características

- 🤖 **Chat inteligente** con respuestas personalizadas según el idioma que estudia el usuario
- 💬 **Historial de conversaciones** guardado en la base de datos
- 🔄 **Conversaciones persistentes** - continúa donde lo dejaste
- 📱 **Interfaz moderna** con diseño tipo chat (burbujas de mensajes)
- 🎨 **UI atractiva** con gradientes y animaciones fluidas
- 📖 **Títulos automáticos** generados por IA para cada conversación
- 🗑️ **Gestión completa** - eliminar o limpiar conversaciones

## 🏗️ Arquitectura

### Backend (Django)

#### Modelos (`ia/models.py`)

```python
class TutorConversation(models.Model):
    user = ForeignKey(User)
    title = CharField(max_length=200)
    target_language = CharField(max_length=50)
    created_at = DateTimeField()
    updated_at = DateTimeField()
    is_active = BooleanField()

class TutorMessage(models.Model):
    conversation = ForeignKey(TutorConversation)
    role = CharField(choices=['user', 'assistant'])
    content = TextField()
    created_at = DateTimeField()
```

#### Servicio de IA (`ia/services/tutor_service.py`)

- `chat_with_tutor()` - Procesa mensajes y genera respuestas con Groq
- `generate_conversation_title()` - Crea títulos descriptivos automáticamente
- `get_tutor_system_prompt()` - Prompt optimizado para educación de idiomas

#### API REST (`ia/views_tutor.py`)

- `GET /api/ia/tutor/conversations/` - Lista conversaciones del usuario
- `GET /api/ia/tutor/conversations/{id}/` - Obtiene una conversación específica
- `POST /api/ia/tutor/send/` - Envía mensaje y recibe respuesta
- `DELETE /api/ia/tutor/conversations/{id}/delete/` - Elimina conversación
- `POST /api/ia/tutor/conversations/{id}/clear/` - Limpia mensajes

### Frontend (Flutter)

#### Servicio (`lib/services/tutor_service.dart`)

Clase `TutorService` con métodos para:

- `getConversations()` - Obtener lista de conversaciones
- `getConversation(id)` - Obtener conversación con mensajes
- `sendMessage()` - Enviar mensaje al tutor
- `deleteConversation(id)` - Eliminar conversación
- `clearConversation(id)` - Limpiar mensajes

#### Pantallas

1. **TutorChatScreen** (`lib/screens/tutor/tutor_chat_screen.dart`)

   - Interfaz principal de chat
   - Burbujas de mensajes (usuario y asistente)
   - Campo de entrada con botón de envío
   - Animación de "escribiendo..."
   - Estado vacío con bienvenida

2. **TutorHistoryScreen** (`lib/screens/tutor/tutor_history_screen.dart`)
   - Lista de todas las conversaciones
   - Tarjetas con resumen de cada conversación
   - Acceso rápido a conversaciones previas
   - Botón para crear nueva conversación

## 🎯 Flujo de Uso

1. Usuario toca la tarjeta **"Tutor Inteligente"** en el home
2. Se abre `TutorChatScreen` con estado vacío
3. Usuario escribe su primera pregunta
4. Sistema:
   - Crea nueva conversación
   - Guarda mensaje del usuario
   - Envía a Groq con contexto del idioma objetivo
   - Guarda respuesta del tutor
   - Genera título automático
5. Usuario puede continuar la conversación
6. Todos los mensajes quedan guardados
7. Usuario puede ver historial desde el menú
8. Puede retomar conversaciones anteriores

## 🔧 Configuración Requerida

### Variables de Entorno (Backend)

```bash
GROQ_API_KEY=tu_clave_groq_aqui
GROQ_MODEL=llama-3.3-70b-versatile  # opcional
```

### Dependencias Python

```bash
groq>=0.4.0
```

### Dependencias Flutter

```yaml
dependencies:
  http: ^1.2.1
  intl: ^0.19.0
  flutter_secure_storage: ^9.2.2
```

## 📝 Migraciones

Aplicar migraciones de base de datos:

```bash
cd backend
python manage.py migrate ia
```

## 🚀 Ejemplo de Uso

### Consultas que el tutor puede responder:

- **Gramática**: "¿Cuándo uso 'have' vs 'has' en inglés?"
- **Vocabulario**: "¿Cuál es la diferencia entre 'big', 'large' y 'huge'?"
- **Pronunciación**: "¿Cómo se pronuncia 'through' correctamente?"
- **Cultura**: "¿Qué significa 'break a leg' en inglés?"
- **Práctica**: "Dame ejemplos de oraciones con el presente perfecto"
- **Consejos**: "¿Cómo puedo mejorar mi listening en inglés?"

## 🎨 Diseño UI

### Paleta de Colores

- **Primary**: `#667eea` (Púrpura suave)
- **Secondary**: `#764ba2` (Púrpura medio)
- **Accent**: `#4facfe` (Azul cyan)
- **Background**: `#F5F7FA` (Gris claro)

### Componentes Destacados

- Burbujas de chat con gradientes
- Avatares circulares (usuario y bot)
- Animación de puntos "escribiendo"
- Tarjetas con sombras suaves
- Botones con gradientes

## 📊 Prompts del Sistema

El tutor está configurado con un prompt especializado que:

- Se adapta al idioma que estudia el usuario
- Proporciona explicaciones claras y concisas
- Da ejemplos prácticos contextualizados
- Corrige errores de forma constructiva
- Mantiene un tono amigable y motivador
- Sugiere ejercicios cuando es relevante
- Limita respuestas a ~300 palabras

## 🔐 Seguridad

- Todas las endpoints requieren autenticación (`IsAuthenticated`)
- Las conversaciones solo son accesibles por su propietario
- Soft delete para conversaciones (no se borran físicamente)
- Cache de traducciones para optimizar uso de API

## 🚦 Estado Actual

✅ **Completado al 100%**

- Backend con modelos, serializers, views y URLs
- Servicio de IA con Groq integrado
- Frontend con pantallas de chat e historial
- Integración completa backend-frontend
- UI moderna y responsiva
- Migraciones aplicadas
- Documentación completa

## 📱 Capturas de Pantalla Sugeridas

1. Home con nueva tarjeta "Tutor Inteligente"
2. Pantalla vacía de chat con mensaje de bienvenida
3. Conversación activa con mensajes
4. Lista de historial de conversaciones
5. Menú de opciones de conversación

## 🔄 Mejoras Futuras (Opcionales)

- [ ] Exportar conversaciones a PDF
- [ ] Búsqueda en historial de conversaciones
- [ ] Filtros por fecha/idioma en historial
- [ ] Sugerencias de preguntas frecuentes
- [ ] Modo de voz para preguntas habladas
- [ ] Integración con progreso de lecciones
- [ ] Estadísticas de uso del tutor
- [ ] Compartir conversaciones útiles

## 🐛 Troubleshooting

### Error: "No hay token de autenticación"

- Asegúrate de estar logueado
- Verifica que el token esté guardado en FlutterSecureStorage

### Error: "GROQ_API_KEY ausente"

- Configura la variable de entorno en el backend
- Reinicia el servidor Django después de configurarla

### Conversaciones no se cargan

- Verifica la conexión a internet
- Revisa que el backend esté corriendo
- Comprueba logs del servidor para errores

## 👨‍💻 Archivos Creados/Modificados

### Backend

- ✅ `ia/services/tutor_service.py` (nuevo)
- ✅ `ia/models.py` (modificado - agregados TutorConversation y TutorMessage)
- ✅ `ia/serializers.py` (nuevo)
- ✅ `ia/views_tutor.py` (nuevo)
- ✅ `ia/urls.py` (modificado)
- ✅ `ia/admin.py` (modificado)

### Frontend

- ✅ `lib/services/tutor_service.dart` (nuevo)
- ✅ `lib/screens/tutor/tutor_chat_screen.dart` (nuevo)
- ✅ `lib/screens/tutor/tutor_history_screen.dart` (nuevo)
- ✅ `lib/screens/home.dart` (modificado - agregada tarjeta)

---

**Autor**: GitHub Copilot  
**Fecha**: Noviembre 2025  
**Versión**: 1.0.0
