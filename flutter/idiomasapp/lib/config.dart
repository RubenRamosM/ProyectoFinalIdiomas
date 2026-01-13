// Configuración dinámica del servidor
// La IP se puede cambiar desde la app sin recompilar

// IPs comunes para desarrollo (detección automática)
const List<String> kCommonLocalIPs = [
  '192.168.0.', // Red doméstica común
  '192.168.1.', // Red doméstica común
  '192.168.43.', // Hotspot móvil Android
  '172.20.10.', // Hotspot móvil iOS
  '10.0.0.', // Algunas redes corporativas
];

const String kDefaultApiBase = 'http://192.168.1.12:8000/api/';

// Puerto del servidor Django (normalmente no cambia)
const String kApiPort = '8000';

// Función para construir la URL completa
String getApiUrl(String ip) {
  // Limpiar la IP de espacios y barras
  ip = ip.trim().replaceAll(RegExp(r'[/:]+$'), '');

  // Agregar http:// si no lo tiene
  if (!ip.startsWith('http://') && !ip.startsWith('https://')) {
    ip = 'http://$ip';
  }

  // Agregar puerto si no lo tiene
  if (!ip.contains(':$kApiPort')) {
    ip = '$ip:$kApiPort';
  }

  // Agregar /api/ al final
  if (!ip.endsWith('/api/')) {
    ip = ip.endsWith('/') ? '${ip}api/' : '$ip/api/';
  }

  return ip;
}

// Variable global que se actualiza desde el storage
String kApiBase = kDefaultApiBase;
