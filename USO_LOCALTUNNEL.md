# ✅ Configuración Completada - localtunnel

## 🎉 ¡Ya está configurado!

Tu servidor Django ahora está disponible públicamente en:

**🌐 URL Pública:** `https://smart-apples-go.loca.lt`

Esto significa que tu app funciona desde **cualquier red** sin necesidad de configurar IPs.

---

## 🚀 Cómo Funciona

### **Servidores Corriendo:**

1. **Django** (Terminal 1):
   - Corriendo en: `http://0.0.0.0:8000`
   - Estado: ✅ Activo
   - Accesible solo en tu red local

2. **localtunnel** (Terminal en segundo plano):
   - Expone Django a internet
   - URL pública: `https://smart-apples-go.loca.lt`
   - Estado: ✅ Activo
   - Accesible desde cualquier parte del mundo

### **Flujo de Conexión:**

```
📱 App Flutter (tu teléfono)
    ↓
🌐 https://smart-apples-go.loca.lt (Internet público)
    ↓
🔒 Túnel de localtunnel
    ↓
💻 http://localhost:8000 (Tu computadora)
    ↓
🐍 Django API
```

---

## 📱 Probar la App

### **Paso 1: Reinicia la app Flutter**

Si la app ya está corriendo, detenla completamente (no hot restart):

```bash
# Detén la app (Ctrl+C en la terminal de Flutter)
# Luego reinicia:
cd "C:\Disco D\SW1\Sw1ProyectoFinal\flutter\idiomasapp"
flutter run
```

### **Paso 2: Prueba el login**

1. Abre la app en tu teléfono
2. Intenta iniciar sesión con:
   - Usuario: `juan` (o cualquier usuario que tengas)
   - Contraseña: `Test1234`

3. Si funciona, verás la pantalla de Home ✅

### **Paso 3: Prueba con 4G/5G (opcional)**

Para verificar que funciona desde cualquier red:

1. **Desconecta tu teléfono del WiFi**
2. **Usa datos móviles (4G/5G)**
3. Abre la app y prueba iniciar sesión
4. Debería funcionar igual ✅

---

## 🔄 Reiniciar localtunnel

Si apagas tu computadora o cierras la terminal, necesitarás reiniciar localtunnel.

### **Opción 1: Misma URL (Recomendado)**

Para mantener la misma URL (`smart-apples-go`), usa:

```bash
npx localtunnel --port 8000 --subdomain smart-apples-go
```

**NOTA:** El nombre `smart-apples-go` puede no estar disponible si alguien más lo está usando. Si falla, usa la Opción 2.

### **Opción 2: Nueva URL Aleatoria**

Si te da igual cambiar la URL:

```bash
npx localtunnel --port 8000
```

Esto te dará una nueva URL como `https://funny-dogs-456.loca.lt`

**Si usas esta opción:**
1. Copia la nueva URL
2. Actualiza `config.dart`:
   ```dart
   const String kDefaultApiBase = 'https://NUEVA-URL.loca.lt/api/';
   ```
3. Reinicia la app Flutter

---

## ⚡ Comandos Rápidos

### **Iniciar todo de cero:**

**Terminal 1 - Django:**
```bash
cd "C:\Disco D\SW1\Sw1ProyectoFinal\backend"
python manage.py runserver 0.0.0.0:8000
```

**Terminal 2 - localtunnel:**
```bash
npx localtunnel --port 8000 --subdomain smart-apples-go
```

**Terminal 3 - Flutter:**
```bash
cd "C:\Disco D\SW1\Sw1ProyectoFinal\flutter\idiomasapp"
flutter run
```

### **Verificar que localtunnel está activo:**

Abre en tu navegador:
```
https://smart-apples-go.loca.lt
```

Deberías ver una página de "Tunnel Password" la primera vez. Haz clic en "Continue" y verás el admin de Django.

---

## 🎯 Ventajas de Esta Configuración

### ✅ **Funciona desde cualquier red**
- Casa (WiFi) ✅
- Trabajo (WiFi diferente) ✅
- 4G/5G ✅
- Hotspot móvil ✅
- Cualquier lugar ✅

### ✅ **No necesitas configurar nada**
- Sin cambiar IPs
- Sin configurar router
- Sin abrir puertos
- Sin firewall

### ✅ **Fácil de compartir**
Si un compañero quiere probar tu app:
- Le das la URL: `https://smart-apples-go.loca.lt`
- Puede conectarse desde su teléfono
- No necesita estar en tu red

### ✅ **HTTPS gratis**
localtunnel automáticamente usa HTTPS (más seguro que HTTP)

---

## ⚠️ Limitaciones

### **1. Necesitas la PC encendida**
- localtunnel solo funciona mientras tu PC está encendida
- Django también necesita estar corriendo
- Si apagas la PC, la app deja de funcionar

### **2. URL puede cambiar**
- Si cierras localtunnel, la URL cambia
- Para mantenerla, usa `--subdomain smart-apples-go`
- O edita `config.dart` con la nueva URL

### **3. Primera vez pide contraseña**
La primera vez que accedas a la URL desde un navegador nuevo, verás:
```
Tunnel Password Required
This page is protected by a tunnel password.
[Continue]
```

Solo haz clic en "Continue" y ya no volverá a pedirla.

**Esto NO afecta a la app Flutter** - la app funciona directamente.

---

## 🔧 Solución de Problemas

### **Error: "Connection refused" en la app**

**Causa:** Django no está corriendo

**Solución:**
```bash
cd "C:\Disco D\SW1\Sw1ProyectoFinal\backend"
python manage.py runserver 0.0.0.0:8000
```

### **Error: "Tunnel not found"**

**Causa:** localtunnel no está corriendo

**Solución:**
```bash
npx localtunnel --port 8000 --subdomain smart-apples-go
```

### **La URL cambió y la app no funciona**

**Causa:** Reiniciaste localtunnel sin `--subdomain`

**Solución:**
1. Copia la nueva URL de localtunnel
2. Edita `flutter/idiomasapp/lib/config.dart`:
   ```dart
   const String kDefaultApiBase = 'https://NUEVA-URL.loca.lt/api/';
   ```
3. Reinicia Flutter: `flutter run`

### **localtunnel se cierra solo**

**Causa:** La terminal se cerró

**Solución:** Vuelve a ejecutar:
```bash
npx localtunnel --port 8000 --subdomain smart-apples-go
```

---

## 📊 Estado Actual

### **Configuración:**
- ✅ Django: `http://0.0.0.0:8000`
- ✅ localtunnel: `https://smart-apples-go.loca.lt`
- ✅ Flutter config.dart: Actualizado con la URL de localtunnel
- ✅ CORS: Configurado en Django
- ✅ ALLOWED_HOSTS: Permite todos los dominios

### **Próximos pasos:**
1. Reinicia la app Flutter
2. Prueba el login
3. Verifica que todo funcione

---

## 💡 Tips

### **Para desarrollo diario:**

Crea un archivo `.bat` (Windows) para iniciar todo automáticamente:

**`iniciar_servidor.bat`:**
```batch
@echo off
echo Iniciando Django...
start cmd /k "cd C:\Disco D\SW1\Sw1ProyectoFinal\backend && python manage.py runserver 0.0.0.0:8000"

timeout /t 3

echo Iniciando localtunnel...
start cmd /k "npx localtunnel --port 8000 --subdomain smart-apples-go"

echo.
echo ✅ Servidores iniciados!
echo Django: http://localhost:8000
echo Público: https://smart-apples-go.loca.lt
pause
```

Guárdalo en la raíz del proyecto y ejecuta haciendo doble clic.

### **Para producción:**

Cuando termines el proyecto y quieras desplegarlo:

1. **Railway.app** (Recomendado - Gratis):
   - Conecta tu repo de GitHub
   - Railway despliega automáticamente
   - Te da una URL fija: `https://idiomasapp.railway.app`
   - Plan gratis: 500 horas/mes (suficiente para desarrollo)

2. **Render.com** (Alternativa - Gratis):
   - Similar a Railway
   - URL fija gratis
   - Plan gratis: Duerme después de 15 min sin uso

3. **Fly.io** (Otra alternativa):
   - Gratis hasta 3 apps
   - Más complejo de configurar

---

## 🎉 Resumen

**Antes:**
- Cambiar de red → Editar config.dart → Cambiar IP → Recompilar (10 min) → Reinstalar

**Ahora:**
- Cambiar de red → Nada - sigue funcionando ✅

**Esfuerzo:**
- Configuración inicial: ✅ Completada (5 minutos)
- Mantenimiento diario: Solo ejecutar `npx localtunnel --port 8000`

---

**🌐 Tu URL pública:** `https://smart-apples-go.loca.lt`

**📱 Ahora puedes probar la app desde cualquier red!**
