# Configuración de Red Dinámica - Cambiar IP sin Recompilar

## ✅ Problema Resuelto

Antes tenías que editar manualmente `config.dart` cada vez que cambiabas de red. Ahora la IP se puede cambiar **desde la aplicación** sin recompilar.

---

## 🎯 Cómo Usar la Nueva Configuración

### 1. **Desde la Pantalla de Login**

1. Abre la app IdiomasApp
2. En la pantalla de login, verás un **icono de configuración** (⚙️🔌) en la esquina superior derecha
3. Presiona el icono
4. Se abrirá la pantalla "Configuración del Servidor"

### 2. **Cambiar la IP del Servidor**

En la pantalla de configuración:

1. **Campo "IP del Servidor"**: Escribe solo la IP de tu computadora
   - Ejemplo: `192.168.0.102`
   - No necesitas escribir `http://` ni `:8000` ni `/api/`
   - La app lo agrega automáticamente

2. **Botón "Probar"**: Prueba si la IP funciona antes de guardar
   - ✅ Verde: Servidor encontrado
   - ❌ Rojo: No se pudo conectar

3. **Botón "Guardar"**: Guarda la nueva IP
   - La app se conectará a esta IP automáticamente
   - Incluso si cierras y vuelves a abrir la app

---

## 🔍 Cómo Encontrar la IP de tu Computadora

### **Windows**

1. Presiona `Win + R`
2. Escribe `cmd` y presiona Enter
3. En la ventana negra, escribe:
   ```
   ipconfig
   ```
4. Busca la línea **"Dirección IPv4"** en tu adaptador activo:
   - Si usas WiFi, busca en "Adaptador de LAN inalámbrica Wi-Fi"
   - Si usas cable, busca en "Adaptador de Ethernet"
   - Si compartes internet desde el móvil, busca en el adaptador del hotspot

**Ejemplo de salida:**
```
Adaptador de LAN inalámbrica Wi-Fi:
   Dirección IPv4. . . . . . . . . . . : 192.168.0.102  ← Esta es tu IP
```

### **Mac**

1. Abre **Terminal** (Cmd + Espacio → escribe "terminal")
2. Escribe:
   ```bash
   ifconfig | grep "inet " | grep -v 127.0.0.1
   ```
3. Verás algo como:
   ```
   inet 192.168.0.102 netmask 0xffffff00  ← Tu IP
   ```

### **Linux**

1. Abre **Terminal**
2. Escribe:
   ```bash
   ip addr show | grep "inet " | grep -v 127.0.0.1
   ```
3. Busca tu IP en la interfaz activa (wlan0 para WiFi, eth0 para Ethernet)

---

## 📱 Escenarios Comunes

### **Escenario 1: Casa (WiFi)**

Tu computadora y teléfono conectados a la misma red WiFi:

1. Tu computadora tiene IP: `192.168.0.102`
2. Tu teléfono está en la misma WiFi
3. En la app, configura: `192.168.0.102`

### **Escenario 2: Trabajo (WiFi Diferente)**

Tu computadora tiene otra IP en la red del trabajo:

1. Obtén la nueva IP: `192.168.1.85` (ejemplo)
2. Abre la app en el teléfono
3. Ve a Configuración del Servidor
4. Cambia la IP a: `192.168.1.85`
5. Presiona "Probar" y luego "Guardar"

### **Escenario 3: Hotspot Móvil (Compartiendo Internet)**

Tu teléfono comparte internet con tu computadora:

1. Activa el hotspot en tu teléfono
2. Conecta tu computadora al hotspot
3. En tu computadora, obtén la IP asignada por el hotspot
   - Android: Suele ser `192.168.43.X`
   - iOS: Suele ser `172.20.10.X`
4. En la app, configura esa IP

**Ejemplo Android:**
- IP de la computadora conectada al hotspot: `192.168.43.1`
- Configurar en la app: `192.168.43.1`

**Ejemplo iOS:**
- IP de la computadora conectada al hotspot: `172.20.10.2`
- Configurar en la app: `172.20.10.2`

---

## 🚀 Proceso Completo (Paso a Paso)

### **Primera Vez (Configuración Inicial)**

1. **Inicia el servidor Django** en tu computadora:
   ```bash
   cd "C:\Disco D\SW1\Sw1ProyectoFinal\backend"
   python manage.py runserver 0.0.0.0:8000
   ```

2. **Obtén la IP de tu computadora** (usando `ipconfig` en Windows)
   - Ejemplo: `192.168.0.102`

3. **Abre la app IdiomasApp** en tu teléfono

4. **Configura el servidor**:
   - Presiona el icono ⚙️🔌 en la pantalla de login
   - Escribe la IP: `192.168.0.102`
   - Presiona "Probar"
   - Si sale ✅ "Servidor encontrado", presiona "Guardar"

5. **Inicia sesión** normalmente

### **Cuando Cambias de Red**

1. **Obtén la nueva IP** de tu computadora en la nueva red
   - Ejemplo: Antes era `192.168.0.102`, ahora es `192.168.1.85`

2. **Actualiza en la app**:
   - Si aún no has iniciado sesión: Usa el botón ⚙️🔌 en login
   - Si ya iniciaste sesión: Cierra sesión, luego usa el botón ⚙️🔌

3. **Cambia la IP** y guarda

4. **Listo** - Ya puedes usar la app en la nueva red

---

## 🔧 Características Técnicas

### **Almacenamiento Persistente**

- La IP se guarda en `flutter_secure_storage`
- Se carga automáticamente al abrir la app
- No necesitas recompilarla

### **Validación Automática**

- La función `getApiUrl()` normaliza la IP que ingresas:
  - Agrega `http://` si no lo tiene
  - Agrega el puerto `:8000`
  - Agrega `/api/` al final
  - Ejemplo: Escribes `192.168.0.102` → Se convierte en `http://192.168.0.102:8000/api/`

### **Prueba de Conexión**

- El botón "Probar" hace una petición real al servidor
- Verifica que el servidor Django esté corriendo
- Muestra error específico si no puede conectar

---

## ⚠️ Solución de Problemas

### **Error: "No se pudo conectar"**

**Posibles causas:**

1. **El servidor Django no está corriendo**
   - Solución: Inicia el servidor con `python manage.py runserver 0.0.0.0:8000`

2. **La IP es incorrecta**
   - Solución: Verifica con `ipconfig` (Windows) o `ifconfig` (Mac/Linux)

3. **Firewall bloqueando la conexión**
   - Solución: Permite Python en el firewall de Windows
   - Windows Defender → Permitir una aplicación → Python

4. **Teléfono y computadora en redes diferentes**
   - Solución: Conecta ambos a la misma red WiFi

### **Error al iniciar sesión: "Connection refused"**

- Revisa que Django esté corriendo en `0.0.0.0:8000` (no en `127.0.0.1`)
- Verifica que la IP en la app sea la correcta

### **La app se queda cargando**

- El servidor Django probablemente esté caído
- Revisa la terminal donde corre Django para ver errores

---

## 📋 Checklist de Configuración

Antes de usar la app en una nueva red:

- [ ] Conectar computadora y teléfono a la **misma red**
- [ ] Iniciar servidor Django: `python manage.py runserver 0.0.0.0:8000`
- [ ] Obtener IP de la computadora: `ipconfig` (Windows)
- [ ] Abrir app y configurar IP en Configuración del Servidor
- [ ] Probar conexión con el botón "Probar"
- [ ] Guardar si la conexión es exitosa
- [ ] Intentar iniciar sesión

---

## 💡 Tips y Recomendaciones

### **Para Desarrollo Frecuente**

Si cambias de red constantemente:

1. **Usa un router portátil** o hotspot móvil siempre
   - La IP será siempre la misma
   - No necesitarás cambiar la configuración

2. **Asigna IP estática** en tu router
   - Configura tu computadora para usar siempre la misma IP
   - Ejemplo: Siempre `192.168.0.102`

3. **Usa hostname en lugar de IP** (avanzado):
   - Configura un nombre DNS local
   - Ejemplo: `idiomasapp.local` en lugar de `192.168.0.102`

### **Para Producción**

Cuando despliegues la app:

1. Usa un dominio real: `https://api.idiomasapp.com`
2. Cambia `kDefaultApiBase` en `config.dart` a tu dominio
3. Los usuarios nunca tendrán que cambiar la IP

---

## 🎉 Resumen

**Antes:**
- Cambias de red → Editas `config.dart` → Recompilas la app (5-10 minutos) → Pruebas

**Ahora:**
- Cambias de red → Abres Configuración → Cambias IP (30 segundos) → Listo

**Beneficios:**
- ✅ No necesitas recompilar
- ✅ Cambio en 30 segundos
- ✅ Prueba de conexión integrada
- ✅ Almacenamiento persistente
- ✅ Fácil de usar

---

## 📞 Soporte

Si tienes problemas:

1. Verifica que Django esté corriendo: `http://TU_IP:8000/admin`
2. Verifica que el teléfono y computadora estén en la misma red
3. Revisa los logs de Django para ver errores
4. Prueba con `curl http://TU_IP:8000/api/users/me/` desde otra computadora

---

**Última actualización:** 2025-10-10
**Versión:** 1.0
