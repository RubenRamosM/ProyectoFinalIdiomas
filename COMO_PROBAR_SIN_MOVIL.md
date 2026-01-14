# Cómo Probar el Backend sin Dispositivo Móvil

## Opción 1: Usar Postman (Recomendado) 🌟

### 1. Descargar e Instalar Postman

1. Ve a: https://www.postman.com/downloads/
2. Descarga e instala Postman
3. Abre Postman

### 2. Probar el Registro de Usuario

**Configuración:**
- **Método**: POST
- **URL**: `http://127.0.0.1:8000/api/auth/register/`
- **Headers**:
  - `Content-Type`: `application/json`

**Body** (selecciona "raw" y "JSON"):
```json
{
  "username": "testuser",
  "email": "testuser@ejemplo.com",
  "password": "Test1234",
  "password2": "Test1234",
  "first_name": "Test",
  "last_name": "Usuario",
  "native_language": "es",
  "target_language": "en",
  "age": 25,
  "nationality": "Bolivia"
}
```

**Click en "Send"**

**Respuesta esperada (201 Created)**:
```json
{
  "id": 6,
  "username": "testuser",
  "first_name": "Test",
  "last_name": "Usuario",
  "email": "testuser@ejemplo.com",
  "native_language": "es",
  "target_language": "en",
  "nationality": "Bolivia",
  "age": 25,
  "level": null
}
```

### 3. Probar el Login

**Configuración:**
- **Método**: POST
- **URL**: `http://127.0.0.1:8000/api/auth/token/`
- **Headers**:
  - `Content-Type`: `application/json`

**Body** (raw JSON):
```json
{
  "username": "maria",
  "password": "Test1234"
}
```

**Respuesta esperada (200 OK)**:
```json
{
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "access": "eyJ0eXAiOiJKV1QiLCJhbGc..."
}
```

**¡IMPORTANTE!** Copia el token `access`, lo necesitarás para las siguientes pruebas.

### 4. Probar Endpoints Protegidos

**Configuración:**
- **Método**: GET
- **URL**: `http://127.0.0.1:8000/api/auth/me/`
- **Headers**:
  - `Authorization`: `Bearer TU_TOKEN_ACCESS_AQUI`
  - `Content-Type`: `application/json`

**Respuesta esperada**:
```json
{
  "id": 2,
  "username": "maria",
  "first_name": "María",
  "last_name": "González",
  "email": "maria@test.com",
  "native_language": "es",
  "target_language": "en",
  "nationality": "Bolivia",
  "age": 28,
  "level": "A2"
}
```

---

## Opción 2: Usar el Navegador (Para GET) 🌐

### Panel de Administración Django

1. **Crear un superusuario** (si aún no lo hiciste):
   ```bash
   cd backend
   python manage.py createsuperuser
   ```

   Ingresa:
   - Username: admin
   - Email: admin@test.com
   - Password: admin123 (o el que prefieras)

2. **Abrir el panel de admin**:
   - Ve a: http://127.0.0.1:8000/admin/
   - Login con las credenciales del superusuario
   - Aquí puedes ver y gestionar todos los datos

### Django REST Framework Browsable API

1. **Ir a cualquier endpoint en el navegador**:
   - http://127.0.0.1:8000/api/auth/register/
   - http://127.0.0.1:8000/api/lecciones/

2. **Verás una interfaz web** donde puedes:
   - Ver la documentación del endpoint
   - Hacer requests directamente desde el navegador
   - Enviar formularios

**Para registrar un usuario desde el navegador**:
1. Ve a: http://127.0.0.1:8000/api/auth/register/
2. Baja hasta el formulario HTML
3. Llena los campos
4. Click en "POST"

---

## Opción 3: Usar cURL (Línea de Comandos) 💻

### 1. Probar Registro

Abre PowerShell o CMD y ejecuta:

```powershell
curl -X POST http://127.0.0.1:8000/api/auth/register/ -H "Content-Type: application/json" -d "{\"username\":\"testcurl\",\"email\":\"testcurl@test.com\",\"password\":\"Test1234\",\"password2\":\"Test1234\",\"first_name\":\"Test\",\"last_name\":\"Curl\",\"native_language\":\"es\",\"target_language\":\"en\"}"
```

### 2. Probar Login

```powershell
curl -X POST http://127.0.0.1:8000/api/auth/token/ -H "Content-Type: application/json" -d "{\"username\":\"maria\",\"password\":\"Test1234\"}"
```

### 3. Probar con Token

```powershell
curl http://127.0.0.1:8000/api/auth/me/ -H "Authorization: Bearer TU_TOKEN_AQUI"
```

---

## Opción 4: Crear un Script Python de Prueba 🐍

Crea un archivo `test_api.py` en la raíz del proyecto:

```python
import requests
import json

BASE_URL = "http://127.0.0.1:8000"

def test_register():
    """Probar registro de usuario"""
    print("\n=== TEST: REGISTRO ===")
    url = f"{BASE_URL}/api/auth/register/"
    data = {
        "username": "pythontest",
        "email": "pythontest@test.com",
        "password": "Test1234",
        "password2": "Test1234",
        "first_name": "Python",
        "last_name": "Test",
        "native_language": "es",
        "target_language": "en",
        "age": 25
    }

    response = requests.post(url, json=data)
    print(f"Status Code: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    return response.status_code == 201

def test_login(username="maria", password="Test1234"):
    """Probar login"""
    print("\n=== TEST: LOGIN ===")
    url = f"{BASE_URL}/api/auth/token/"
    data = {
        "username": username,
        "password": password
    }

    response = requests.post(url, json=data)
    print(f"Status Code: {response.status_code}")

    if response.status_code == 200:
        tokens = response.json()
        print(f"Access Token: {tokens['access'][:50]}...")
        print(f"Refresh Token: {tokens['refresh'][:50]}...")
        return tokens['access']
    else:
        print(f"Error: {response.json()}")
        return None

def test_me(token):
    """Probar endpoint protegido /me/"""
    print("\n=== TEST: GET /me/ ===")
    url = f"{BASE_URL}/api/auth/me/"
    headers = {
        "Authorization": f"Bearer {token}"
    }

    response = requests.get(url, headers=headers)
    print(f"Status Code: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    return response.status_code == 200

def test_lessons(token):
    """Probar lista de lecciones"""
    print("\n=== TEST: GET /lecciones/ ===")
    url = f"{BASE_URL}/api/lecciones/"
    headers = {
        "Authorization": f"Bearer {token}"
    }

    response = requests.get(url, headers=headers)
    print(f"Status Code: {response.status_code}")

    if response.status_code == 200:
        lessons = response.json()
        print(f"Total de lecciones: {len(lessons)}")
        if lessons:
            print(f"Primera lección: {lessons[0]}")
    else:
        print(f"Response: {response.json()}")

if __name__ == "__main__":
    print("="*50)
    print("PRUEBAS DE API - BACKEND IDIOMAS")
    print("="*50)

    # 1. Probar registro (comentar si el usuario ya existe)
    # test_register()

    # 2. Probar login
    token = test_login()

    if token:
        # 3. Probar endpoint /me/
        test_me(token)

        # 4. Probar lecciones
        test_lessons(token)

        print("\n" + "="*50)
        print("✅ TODAS LAS PRUEBAS COMPLETADAS")
        print("="*50)
    else:
        print("\n❌ Error en el login. Verifica las credenciales.")
```

**Para ejecutar**:
```bash
# Instalar requests si no lo tienes
pip install requests

# Ejecutar
python test_api.py
```

---

## Opción 5: Usar Insomnia (Alternativa a Postman) 🔮

1. **Descargar**: https://insomnia.rest/download
2. **Crear una colección** para tu proyecto
3. **Importar o crear requests** manualmente (igual que Postman)

---

## Opción 6: Extensión de VS Code - Thunder Client ⚡

Si usas VS Code:

1. **Instalar extensión**: Thunder Client
2. **Abrir desde la barra lateral**
3. **Crear New Request**:
   - URL: `http://127.0.0.1:8000/api/auth/token/`
   - Method: POST
   - Body: JSON (como en los ejemplos anteriores)

---

## Verificar que el Servidor Está Corriendo

### Método 1: Navegador
Abre en tu navegador: http://127.0.0.1:8000/

Deberías ver algo o un error, pero NO "No se puede acceder al sitio".

### Método 2: Comando
```bash
curl http://127.0.0.1:8000/
```

### Método 3: Verificar proceso Python
```bash
# Windows PowerShell
Get-Process python

# Debería mostrar procesos de Python corriendo
```

---

## Colección de Postman Lista para Importar

Crea un archivo `idiomas_api.postman_collection.json`:

```json
{
  "info": {
    "name": "Idiomas API",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": [
    {
      "name": "Auth",
      "item": [
        {
          "name": "Registro",
          "request": {
            "method": "POST",
            "header": [{"key": "Content-Type", "value": "application/json"}],
            "body": {
              "mode": "raw",
              "raw": "{\n  \"username\": \"nuevo\",\n  \"email\": \"nuevo@test.com\",\n  \"password\": \"Test1234\",\n  \"password2\": \"Test1234\",\n  \"first_name\": \"Nuevo\",\n  \"last_name\": \"Usuario\",\n  \"native_language\": \"es\",\n  \"target_language\": \"en\"\n}"
            },
            "url": {"raw": "http://127.0.0.1:8000/api/auth/register/"}
          }
        },
        {
          "name": "Login",
          "request": {
            "method": "POST",
            "header": [{"key": "Content-Type", "value": "application/json"}],
            "body": {
              "mode": "raw",
              "raw": "{\n  \"username\": \"maria\",\n  \"password\": \"Test1234\"\n}"
            },
            "url": {"raw": "http://127.0.0.1:8000/api/auth/token/"}
          }
        },
        {
          "name": "Mi Perfil",
          "request": {
            "method": "GET",
            "header": [
              {"key": "Authorization", "value": "Bearer {{access_token}}"}
            ],
            "url": {"raw": "http://127.0.0.1:8000/api/auth/me/"}
          }
        }
      ]
    },
    {
      "name": "Lecciones",
      "item": [
        {
          "name": "Lista de Lecciones",
          "request": {
            "method": "GET",
            "header": [
              {"key": "Authorization", "value": "Bearer {{access_token}}"}
            ],
            "url": {"raw": "http://127.0.0.1:8000/api/lecciones/"}
          }
        }
      ]
    }
  ]
}
```

**Importar en Postman**:
1. File → Import
2. Selecciona el archivo JSON
3. Listo para usar

---

## Solución de Problemas Comunes

### Error: "No se puede acceder al sitio"

**Verificar que el servidor está corriendo**:
```bash
cd backend
python manage.py runserver 0.0.0.0:8000
```

### Error 500 Internal Server Error

**Ver logs del servidor** en la terminal donde está corriendo Django.

### Error 404 Not Found

Verifica que la URL sea correcta:
- ✅ `http://127.0.0.1:8000/api/auth/register/`
- ❌ `http://127.0.0.1:8000/auth/register/` (falta /api/)

### Error 401 Unauthorized

El token JWT expiró o es inválido. Haz login nuevamente para obtener uno nuevo.

---

## Recomendación Final

**La mejor opción es Postman** porque:
- ✅ Interfaz gráfica amigable
- ✅ Guarda las peticiones
- ✅ Puede guardar variables (como el token)
- ✅ Tiene herramientas de prueba y debugging
- ✅ Genera código en múltiples lenguajes

**Para desarrollo rápido**: Django Admin + REST Framework Browsable API
**Para automatización**: Script Python
