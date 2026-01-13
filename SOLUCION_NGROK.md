# Solución Profesional: ngrok - URL Pública para tu Servidor Local

## 🎯 El Problema

Cada vez que cambias de red, tienes que cambiar la IP manualmente en la app. **Esto no es profesional.**

## ✅ La Solución: ngrok

**ngrok** crea un túnel público a tu servidor local. Tu app usará una URL fija que funciona desde cualquier red.

**Ventajas:**
- ✅ URL fija: `https://abc123.ngrok.io`
- ✅ Funciona desde cualquier red (casa, trabajo, 4G)
- ✅ No necesitas configurar firewall
- ✅ HTTPS automático (más seguro)
- ✅ Gratis para desarrollo

---

## 📦 Instalación de ngrok

### **Opción 1: Descarga Directa (Más Rápido)**

1. Ve a: https://ngrok.com/download
2. Descarga la versión para Windows
3. Extrae el archivo `ngrok.exe` en una carpeta (ej: `C:\ngrok\`)
4. Listo - ya puedes usarlo

### **Opción 2: Con Chocolatey**

Si tienes Chocolatey instalado:
```powershell
choco install ngrok
```

### **Opción 3: Con Scoop**

Si tienes Scoop instalado:
```powershell
scoop install ngrok
```

---

## 🚀 Uso Básico

### **1. Inicia tu servidor Django**

```bash
cd "C:\Disco D\SW1\Sw1ProyectoFinal\backend"
python manage.py runserver 0.0.0.0:8000
```

Deja esta terminal abierta.

### **2. Inicia ngrok en otra terminal**

```bash
cd C:\ngrok  # O donde hayas extraído ngrok.exe
ngrok http 8000
```

Verás algo así:
```
ngrok

Session Status                online
Account                       Free (Limite: 1 tunnel)
Version                       3.x.x
Region                        United States (us)
Forwarding                    https://abc123.ngrok.io -> http://localhost:8000

Connections                   ttl     opn     rt1     rt5     p50     p90
                              0       0       0.00    0.00    0.00    0.00
```

### **3. Copia la URL de "Forwarding"**

En el ejemplo anterior: `https://abc123.ngrok.io`

Esta es tu URL pública. **Funciona desde cualquier red.**

### **4. Actualiza tu app Flutter**

Edita `flutter/idiomasapp/lib/config.dart`:

```dart
// Antes:
const String kDefaultApiBase = 'http://192.168.0.102:8000/api/';

// Después:
const String kDefaultApiBase = 'https://abc123.ngrok.io/api/';
```

**IMPORTANTE:** Reemplaza `abc123` con tu URL real de ngrok.

### **5. Reinicia la app Flutter**

```bash
cd "C:\Disco D\SW1\Sw1ProyectoFinal\flutter\idiomasapp"
flutter run
```

¡Listo! Ahora tu app funciona desde cualquier red.

---

## ⚡ Ventajas de ngrok

### **1. Funciona desde cualquier red**

- Casa (WiFi) ✅
- Trabajo (WiFi corporativo) ✅
- 4G/5G ✅
- Hotspot móvil ✅
- Cualquier lugar del mundo ✅

### **2. No necesitas configurar nada**

- Sin configuración de router
- Sin abrir puertos
- Sin configurar firewall
- Sin IP estática

### **3. HTTPS gratis**

ngrok automáticamente agrega HTTPS, lo cual es más seguro.

### **4. Fácil de compartir**

Si quieres que un compañero pruebe tu app:
- Le das la URL de ngrok
- Él puede conectarse desde su teléfono
- No necesita estar en tu misma red

---

## 📱 Ejemplo Completo

### **Terminal 1: Django**

```bash
cd "C:\Disco D\SW1\Sw1ProyectoFinal\backend"
python manage.py runserver 0.0.0.0:8000
```

Salida:
```
Starting development server at http://0.0.0.0:8000/
Quit the server with CTRL-BREAK.
```

### **Terminal 2: ngrok**

```bash
cd C:\ngrok
ngrok http 8000
```

Salida:
```
Forwarding     https://f3a2b1c4.ngrok.io -> http://localhost:8000
```

### **Flutter config.dart**

```dart
const String kDefaultApiBase = 'https://f3a2b1c4.ngrok.io/api/';
```

### **Resultado**

- Abres la app en tu teléfono
- Funciona con 4G (no necesitas WiFi)
- Funciona en casa, trabajo, donde sea
- Sin cambiar configuración nunca

---

## 🔒 Configuración de Django para ngrok

ngrok usa un dominio diferente, así que necesitas configurar Django para aceptar ese dominio.

### **Edita `backend/idiomasapp/settings.py`:**

```python
# Busca la línea ALLOWED_HOSTS
ALLOWED_HOSTS = ['*']  # Permite todos los dominios (solo para desarrollo)

# O específicamente:
ALLOWED_HOSTS = [
    'localhost',
    '127.0.0.1',
    '0.0.0.0',
    '.ngrok.io',  # Permite cualquier subdominio de ngrok
]
```

### **Agrega configuración de CORS:**

Si aún no lo tienes, instala django-cors-headers:

```bash
pip install django-cors-headers
```

En `settings.py`:

```python
INSTALLED_APPS = [
    # ...
    'corsheaders',
    # ...
]

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',  # Agregar al inicio
    'django.middleware.common.CommonMiddleware',
    # ...
]

# Permitir peticiones desde cualquier origen (solo desarrollo)
CORS_ALLOW_ALL_ORIGINS = True
```

---

## 🆓 ngrok Gratis vs Pago

### **Plan Gratis (Suficiente para desarrollo):**

- ✅ 1 túnel simultáneo
- ✅ URL aleatoria (ej: `abc123.ngrok.io`)
- ✅ La URL cambia cada vez que reinicias ngrok
- ✅ Sin límite de tiempo
- ✅ Límite de 40 conexiones/minuto

### **Plan Pago ($8/mes):**

- ✅ 3+ túneles simultáneos
- ✅ URL personalizada fija (ej: `idiomasapp.ngrok.io`)
- ✅ Sin límites de conexiones
- ✅ Dominios personalizados

**Para tu proyecto:** El plan gratis es suficiente.

---

## 🔄 URL Dinámica de ngrok

El único "problema" del plan gratis es que la URL cambia cada vez que reinicias ngrok:

**Reinicio 1:** `https://abc123.ngrok.io`
**Reinicio 2:** `https://xyz789.ngrok.io`

### **Solución 1: No apagar ngrok**

Deja ngrok corriendo todo el tiempo mientras desarrollas. Puedes minimizar la terminal.

### **Solución 2: Script de actualización automática**

Crea un script que actualice automáticamente `config.dart` con la nueva URL.

### **Solución 3: URL fija (Pago)**

Si pagas $8/mes, puedes tener una URL fija como `https://idiomasapp.ngrok.io`

### **Solución 4: Variable de entorno**

Configura la app para leer la URL desde una variable de entorno:

```dart
// config.dart
const String kDefaultApiBase = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://abc123.ngrok.io/api/',
);
```

Luego ejecutas:
```bash
flutter run --dart-define=API_URL=https://nueva-url.ngrok.io/api/
```

---

## 🎯 Recomendación para Tu Proyecto

### **Opción A: ngrok (Desarrollo)**

**Para desarrollo y pruebas:**
- Usa ngrok con el plan gratis
- La URL cambia cada vez que reinicias, pero es raro que lo hagas
- Funciona desde cualquier red

**Pasos:**
1. Instala ngrok
2. Ejecuta `ngrok http 8000`
3. Copia la URL en `config.dart`
4. Reinicia la app Flutter
5. Listo

**Cuándo reiniciar ngrok:**
- Si apagas tu computadora
- Si cierras la terminal de ngrok por error

**Frecuencia:** Rara vez (solo cuando apagas la PC)

### **Opción B: Servidor en la Nube (Producción)**

**Para cuando termines el proyecto:**
- Despliega Django en Railway, Render, o DigitalOcean
- Tendrás una URL fija como `https://idiomasapp.railway.app`
- Funciona 24/7 sin tener tu PC encendida

---

## 📋 Checklist de Implementación

1. **Instalar ngrok:**
   - [ ] Descargar de ngrok.com/download
   - [ ] Extraer `ngrok.exe` en `C:\ngrok\`

2. **Configurar Django:**
   - [ ] Editar `settings.py`: `ALLOWED_HOSTS = ['*']`
   - [ ] Instalar django-cors-headers
   - [ ] Configurar CORS

3. **Iniciar servidores:**
   - [ ] Terminal 1: `python manage.py runserver 0.0.0.0:8000`
   - [ ] Terminal 2: `ngrok http 8000`

4. **Configurar Flutter:**
   - [ ] Copiar URL de ngrok
   - [ ] Editar `config.dart` con la nueva URL
   - [ ] Reiniciar app: `flutter run`

5. **Probar:**
   - [ ] Iniciar sesión en la app
   - [ ] Verificar que funciona
   - [ ] Probar con 4G (sin WiFi)

---

## 🚨 Solución de Problemas

### **Error: "ALLOWED_HOSTS validation failed"**

**Solución:** Edita `settings.py`:
```python
ALLOWED_HOSTS = ['*']
```

### **Error: CORS**

**Solución:** Instala y configura django-cors-headers (ver arriba)

### **ngrok no se conecta**

**Solución:** Verifica que Django esté corriendo primero en el puerto 8000

### **La app no se conecta**

**Solución:** Verifica que la URL en `config.dart` sea exactamente la de ngrok (con `/api/` al final)

---

## 💡 Alternativas a ngrok

Si ngrok no te gusta, hay otras opciones similares:

1. **Cloudflare Tunnel** (Gratis, URL fija)
2. **localtunnel** (Gratis, más simple)
3. **serveo** (Gratis, SSH-based)
4. **Tailscale** (Gratis, VPN)

Todas hacen lo mismo: exponer tu servidor local a internet.

---

## 🎉 Resultado Final

**Antes:**
- Cambias de red → Error de conexión → Editar config.dart → Cambiar IP → Recompilar (10 min)

**Con ngrok:**
- Cambias de red → La app sigue funcionando ✅
- No importa si estás en casa, trabajo, o con 4G
- Una sola configuración que funciona siempre

**Esfuerzo:**
- Configuración inicial: 5 minutos
- Mantenimiento: 0 minutos (mientras no apagues ngrok)

---

¿Quieres que te ayude a instalar y configurar ngrok ahora?
