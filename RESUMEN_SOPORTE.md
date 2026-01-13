# Resumen - Sistema de Soporte

## Estado del Sistema

✅ Backend Django funcionando correctamente
✅ API de soporte implementada
✅ 14 FAQs creadas en la base de datos
✅ Sistema de tickets de soporte implementado
✅ Frontend Flutter corregido y conectado a la API

---

## Funcionalidades Implementadas

### 1. Preguntas Frecuentes (FAQs)

Sistema de consulta pública de preguntas frecuentes organizadas por categorías.

#### Categorías Disponibles:

1. **General** - Información general sobre la aplicación
2. **Cuenta y Perfil** - Gestión de cuentas de usuario
3. **Lecciones** - Información sobre el sistema de lecciones
4. **Técnico** - Solución de problemas técnicos
5. **Pagos** - Información sobre suscripciones y pagos

#### FAQs Creadas (14 en total):

**General (3 FAQs):**
- ¿Qué es Idiomas App?
- ¿Qué idiomas puedo aprender?
- ¿La aplicación funciona sin conexión a internet?

**Cuenta y Perfil (3 FAQs):**
- ¿Cómo creo una cuenta?
- ¿Cómo cambio mi contraseña?
- ¿Puedo usar mi cuenta en múltiples dispositivos?

**Lecciones (3 FAQs):**
- ¿Cómo funcionan las lecciones adaptativas?
- ¿Qué tipos de ejercicios hay disponibles?
- ¿Puedo repetir una lección?

**Técnico (3 FAQs):**
- La aplicación no reconoce mi voz correctamente
- ¿Por qué no se carga mi progreso?
- La aplicación se cierra inesperadamente

**Pagos (2 FAQs):**
- ¿La aplicación es gratuita?
- ¿Cómo cancelo mi suscripción?

---

### 2. Sistema de Tickets de Soporte

Los usuarios autenticados pueden crear tickets de soporte para reportar problemas o hacer consultas personalizadas.

#### Estados de Tickets:

- **Abierto (open)** - Ticket recién creado
- **En Progreso (in_progress)** - Ticket siendo atendido
- **Resuelto (resolved)** - Problema solucionado
- **Cerrado (closed)** - Ticket finalizado

---

## Endpoints de la API

### 1. Obtener FAQs

**Endpoint**: `GET /api/support/faqs/`

**Autenticación**: No requiere (público)

**Parámetros opcionales**:
- `category` - Filtrar por categoría (general, account, lessons, technical, payment)

**Respuesta exitosa**:
```json
[
  {
    "id": 1,
    "question": "¿Qué es Idiomas App?",
    "answer": "Idiomas App es una aplicación de aprendizaje de idiomas...",
    "category": "general",
    "category_display": "General",
    "order": 1,
    "created_at": "2025-10-15T14:16:32.578934Z"
  }
]
```

**Ejemplo de uso**:
```bash
# Todas las FAQs
curl -X GET http://127.0.0.1:8000/api/support/faqs/

# FAQs de una categoría específica
curl -X GET http://127.0.0.1:8000/api/support/faqs/?category=general
```

---

### 2. Obtener FAQ por ID

**Endpoint**: `GET /api/support/faqs/{id}/`

**Autenticación**: No requiere (público)

**Respuesta exitosa**:
```json
{
  "id": 1,
  "question": "¿Qué es Idiomas App?",
  "answer": "Idiomas App es una aplicación de aprendizaje de idiomas...",
  "category": "general",
  "category_display": "General",
  "order": 1,
  "created_at": "2025-10-15T14:16:32.578934Z"
}
```

---

### 3. Crear Ticket de Soporte

**Endpoint**: `POST /api/support/tickets/`

**Autenticación**: Requiere JWT token

**Request**:
```json
{
  "subject": "Problema con la pronunciación",
  "message": "La aplicación no reconoce mi voz cuando intento practicar pronunciación"
}
```

**Respuesta exitosa (201 Created)**:
```json
{
  "id": 1,
  "user": 2,
  "user_username": "maria",
  "user_email": "maria@test.com",
  "subject": "Problema con la pronunciación",
  "message": "La aplicación no reconoce mi voz cuando intento practicar pronunciación",
  "status": "open",
  "status_display": "Abierto",
  "admin_response": null,
  "created_at": "2025-10-15T14:30:37.649286Z",
  "updated_at": "2025-10-15T14:30:37.649312Z"
}
```

**Ejemplo de uso**:
```bash
# Primero obtener token
curl -X POST http://127.0.0.1:8000/api/auth/token/ \
  -H "Content-Type: application/json" \
  -d '{"username":"maria","password":"Test1234"}'

# Crear ticket
curl -X POST http://127.0.0.1:8000/api/support/tickets/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer {tu_token_aqui}" \
  -d '{"subject":"Problema con la pronunciación","message":"La aplicación no reconoce mi voz"}'
```

---

### 4. Ver Mis Tickets

**Endpoint**: `GET /api/support/tickets/`

**Autenticación**: Requiere JWT token

**Respuesta exitosa**:
```json
[
  {
    "id": 1,
    "user": 2,
    "user_username": "maria",
    "user_email": "maria@test.com",
    "subject": "Problema con la pronunciación",
    "message": "La aplicación no reconoce mi voz...",
    "status": "open",
    "status_display": "Abierto",
    "admin_response": null,
    "created_at": "2025-10-15T14:30:37.649286Z",
    "updated_at": "2025-10-15T14:30:37.649312Z"
  }
]
```

---

### 5. Ver Ticket por ID

**Endpoint**: `GET /api/support/tickets/{id}/`

**Autenticación**: Requiere JWT token

**Respuesta exitosa**:
```json
{
  "id": 1,
  "user": 2,
  "user_username": "maria",
  "user_email": "maria@test.com",
  "subject": "Problema con la pronunciación",
  "message": "La aplicación no reconoce mi voz...",
  "status": "open",
  "status_display": "Abierto",
  "admin_response": null,
  "created_at": "2025-10-15T14:30:37.649286Z",
  "updated_at": "2025-10-15T14:30:37.649312Z"
}
```

---

## Flujo en la App Flutter

### Ver Preguntas Frecuentes:

1. Usuario navega a "Ayuda y Soporte"
2. Selecciona "Preguntas Frecuentes"
3. La app llama a `GET /api/support/faqs/`
4. Usuario puede filtrar por categoría
5. Usuario puede expandir una FAQ para ver la respuesta completa

### Crear Ticket de Soporte:

1. Usuario navega a "Ayuda y Soporte"
2. Selecciona "Crear Nuevo Ticket"
3. Completa el formulario (asunto y mensaje)
4. La app verifica el token de autenticación
5. La app envía `POST /api/support/tickets/` con los datos
6. Usuario recibe confirmación
7. El ticket queda registrado para revisión del equipo de soporte

### Ver Mis Tickets:

1. Usuario navega a "Ayuda y Soporte"
2. Selecciona "Mis Tickets"
3. La app llama a `GET /api/support/tickets/`
4. Usuario ve lista de sus tickets con estado
5. Usuario puede ver detalle de cada ticket

---

## Correcciones Aplicadas

### Problema Original:

**Error 1 - FAQs (404)**:
- El servicio Flutter usaba `http.get()` con URLs mal construidas
- URL incorrecta: `http://127.0.0.1:8000/api/support/faqs/` duplicando `/api/`

**Error 2 - Tickets (No hay token de autenticación)**:
- El token no se enviaba correctamente en los headers
- No se aprovechaban los interceptores de autenticación de Dio

### Solución Implementada:

**Archivo modificado**: `flutter/idiomasapp/lib/services/support_service.dart`

**Cambios aplicados**:

1. **Eliminado**: Import de `http` y `dart:convert`
2. **Agregado**: Uso del cliente `Api.dio` configurado

**Antes**:
```dart
final response = await http.get(
  Uri.parse('${Api.baseUrl}support/faqs/'),
  headers: {'Content-Type': 'application/json'},
);
```

**Después**:
```dart
final response = await Api.dio.get('support/faqs/');
```

**Beneficios de usar Api.dio**:
- ✅ URL base ya configurada (`http://127.0.0.1:8000/api/`)
- ✅ Interceptores de autenticación automáticos
- ✅ Manejo automático de refresh tokens
- ✅ Headers configurados correctamente
- ✅ Manejo de errores mejorado

---

## Comandos Útiles

### Ver FAQs en la base de datos
```bash
cd "f:\JHOEL\SEMESTRE 2-2025\SW1\FINAL\Sw1ProyectoFinal\backend"
venv\Scripts\python.exe manage.py shell -c "from support.models import FAQ; print(f'Total FAQs: {FAQ.objects.count()}')"
```

### Ver tickets de un usuario
```bash
venv\Scripts\python.exe manage.py shell -c "from support.models import SupportTicket; from users.models import User; u = User.objects.get(username='maria'); [print(f'#{t.id}: {t.subject} - {t.status}') for t in SupportTicket.objects.filter(user=u)]"
```

### Crear FAQs adicionales
```bash
venv\Scripts\python.exe manage.py shell
```
```python
from support.models import FAQ

FAQ.objects.create(
    question="Tu pregunta aquí",
    answer="Tu respuesta aquí",
    category="general",  # o account, lessons, technical, payment
    order=1,
    is_active=True
)
```

### Verificar migraciones
```bash
venv\Scripts\python.exe manage.py showmigrations support
```

---

## Estructura de la Base de Datos

### Modelos Principales

**FAQ (Preguntas Frecuentes)**:
- `question` (CharField) - La pregunta
- `answer` (TextField) - La respuesta detallada
- `category` (CharField) - Categoría (general, account, lessons, technical, payment)
- `order` (IntegerField) - Orden de visualización
- `is_active` (BooleanField) - Si se muestra o no
- `created_at` (DateTimeField) - Fecha de creación
- `updated_at` (DateTimeField) - Fecha de actualización

**SupportTicket (Tickets de Soporte)**:
- `user` (ForeignKey) - Usuario que crea el ticket
- `subject` (CharField) - Asunto del ticket
- `message` (TextField) - Descripción del problema
- `status` (CharField) - Estado (open, in_progress, resolved, closed)
- `admin_response` (TextField) - Respuesta del administrador
- `created_at` (DateTimeField) - Fecha de creación
- `updated_at` (DateTimeField) - Fecha de última actualización

---

## Panel de Administración

### Acceso al Admin de Django

URL: `http://localhost:8000/admin/`

**Credenciales**:
```
Username: admin
Password: Admin1234
```

### Gestionar FAQs:
1. Ir a "Support" > "FAQs"
2. Puede agregar, editar o eliminar FAQs
3. Puede cambiar el orden de visualización
4. Puede activar/desactivar FAQs

### Gestionar Tickets:
1. Ir a "Support" > "Tickets de Soporte"
2. Ver todos los tickets de usuarios
3. Cambiar estado de tickets
4. Agregar respuestas de administrador
5. Filtrar por usuario o estado

---

## Próximos Pasos Recomendados

1. **Sistema de notificaciones**
   - Notificar al usuario cuando su ticket reciba respuesta
   - Usar push notifications o email

2. **Chat en vivo**
   - Implementar chat en tiempo real con WebSockets
   - Para soporte más inmediato

3. **Base de conocimiento**
   - Artículos más detallados además de FAQs
   - Sistema de búsqueda mejorado

4. **Sistema de calificación**
   - Permitir que usuarios califiquen las respuestas de soporte
   - Métricas de satisfacción del cliente

5. **Respuestas automáticas**
   - Bot con IA para respuestas automáticas basadas en FAQs
   - Sugerencias de FAQs relevantes al crear tickets

6. **Adjuntos en tickets**
   - Permitir subir capturas de pantalla
   - Logs de errores automáticos

7. **SLA (Service Level Agreement)**
   - Tiempos de respuesta objetivo
   - Priorización de tickets

---

## Notas de Desarrollo

- Las FAQs son públicas y no requieren autenticación
- Los tickets requieren autenticación JWT
- Cada usuario solo puede ver sus propios tickets
- Los administradores pueden ver y responder todos los tickets desde el panel de admin
- El sistema usa el mismo sistema de autenticación JWT que el resto de la aplicación
- Los interceptores de Dio manejan automáticamente el refresh de tokens expirados

---

## Troubleshooting

### Error: "No hay token de autenticación"
**Causa**: El usuario no ha iniciado sesión
**Solución**: Redirigir al usuario a la pantalla de login

### Error: "Error al cargar FAQs: 404"
**Causa**: El servicio no estaba usando Api.dio correctamente
**Solución**: Ya corregido en la última versión

### Error: "Sesión expirada"
**Causa**: El token JWT ha expirado y el refresh token también
**Solución**: El usuario debe volver a iniciar sesión

### FAQs no se muestran
**Verificar**:
1. Que el servidor Django esté corriendo
2. Que haya FAQs con `is_active=True` en la base de datos
3. Que la URL en `config.dart` sea correcta
4. Ver logs en consola de Flutter para más detalles

### No se puede crear ticket
**Verificar**:
1. Que el usuario esté autenticado
2. Que los campos subject y message no estén vacíos
3. Que el token JWT sea válido
4. Ver respuesta del servidor en logs de Flutter
