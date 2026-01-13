# Credenciales de Usuarios - App de Idiomas

## Estado del Sistema

✅ Servidor Django corriendo en: `http://192.168.0.102:8000` y `http://localhost:8000`
✅ Base de datos PostgreSQL configurada
✅ Migraciones aplicadas
✅ Usuarios de prueba creados

---

## Superusuario (Django Admin)

Acceso al panel de administración en: `http://localhost:8000/admin/` o `http://192.168.0.102:8000/admin/`

```
Username: admin
Email: admin@idiomasapp.com
Password: Admin1234
```

---

## Usuarios de Prueba

Todos estos usuarios pueden iniciar sesión en la aplicación móvil.

### Usuario 1
```
Username: juan
Email: juan@test.com
Password: Test1234
Nivel: A1
```

### Usuario 2
```
Username: maria
Email: maria@test.com
Password: Test1234
Nivel: A2
```

### Usuario 3
```
Username: pedro
Email: pedro@test.com
Password: Test1234
Nivel: B1
```

### Usuario 4
```
Username: ana
Email: ana@test.com
Password: Test1234
Nivel: B2
```

### Usuario 5
```
Username: carlos
Email: carlos@test.com
Password: Test1234
Nivel: C1
```

---

## Endpoints de la API

### Autenticación

**Login (obtener tokens JWT)**
```bash
POST http://192.168.0.102:8000/api/auth/token/
Content-Type: application/json

{
  "username": "juan",
  "password": "Test1234"
}
```

**Refresh Token**
```bash
POST http://192.168.0.102:8000/api/auth/token/refresh/
Content-Type: application/json

{
  "refresh": "tu_refresh_token_aqui"
}
```

**Registro de nuevo usuario**
```bash
POST http://192.168.0.102:8000/api/users/register/
Content-Type: application/json

{
  "username": "nuevo_usuario",
  "first_name": "Nombre",
  "last_name": "Apellido",
  "email": "email@ejemplo.com",
  "password": "Tu_Contraseña_Segura123!",
  "password2": "Tu_Contraseña_Segura123!",
  "native_language": "es",
  "target_language": "en",
  "age": 25,
  "level": "A1"
}
```

---

## Iniciar el Servidor

Si necesitas reiniciar el servidor Django:

```bash
cd "C:\Disco D\SW1\Sw1ProyectoFinal\backend"
python manage.py runserver 0.0.0.0:8000
```

---

## Crear Más Usuarios de Prueba

Para crear nuevamente los usuarios de prueba (si los borraste):

```bash
cd "C:\Disco D\SW1\Sw1ProyectoFinal\backend"
python manage.py create_test_users
```

Para crear el superusuario nuevamente:

```bash
cd "C:\Disco D\SW1\Sw1ProyectoFinal\backend"
python manage.py create_superuser
```

---

## Notas Importantes

1. **Login desde Flutter**: La app Flutter está configurada para usar el username (no el email) para iniciar sesión.
   - Si el usuario ingresa un email, la app automáticamente extrae la parte antes del @ como username.
   - Por ejemplo, si ingresas `juan@test.com`, la app usará `juan` como username.

2. **Contraseñas**: Los usuarios de prueba tienen la contraseña `Test1234`. Para crear nuevos usuarios, la contraseña debe cumplir con:
   - Mínimo 8 caracteres
   - No puede ser muy común (evitar contraseñas como "password123", "12345678", etc.)
   - No puede ser completamente numérica

3. **Tokens JWT**:
   - El access token expira después de 5 minutos (por defecto)
   - El refresh token expira después de 1 día (por defecto)
   - La app Flutter maneja automáticamente el refresh de tokens

4. **Base de Datos**:
   - Nombre: `app_idiomas`
   - Usuario: `postgres`
   - Host: `localhost:5432`

---

## Solución de Problemas

### Error: "Credenciales inválidas"
- Verifica que estés usando el **username** (no el email) para iniciar sesión
- Verifica que la contraseña sea correcta (distingue mayúsculas/minúsculas)

### Error: "No se pudo registrar"
- La contraseña debe tener al menos 8 caracteres
- La contraseña no puede ser muy común
- El email y username deben ser únicos

### El servidor no responde
- Verifica que el servidor Django esté corriendo
- Verifica que la IP en `config.dart` coincida con la IP de tu servidor
- Verifica que no haya firewall bloqueando el puerto 8000
