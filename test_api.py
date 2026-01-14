"""
Script de prueba para el API del proyecto de idiomas.
Prueba los endpoints principales sin necesidad de dispositivo móvil.
"""
import requests
import json
from datetime import datetime

BASE_URL = "http://127.0.0.1:8000"

def print_separator(title=""):
    print("\n" + "="*60)
    if title:
        print(f"  {title}")
        print("="*60)

def print_response(response):
    """Imprime la respuesta de forma legible"""
    print(f"Status Code: {response.status_code}")
    try:
        print(f"Response:\n{json.dumps(response.json(), indent=2, ensure_ascii=False)}")
    except:
        print(f"Response Text: {response.text}")

def test_server():
    """Verificar que el servidor está corriendo"""
    print_separator("TEST 1: Verificar Servidor")
    try:
        response = requests.get(f"{BASE_URL}/", timeout=5)
        print(f"[OK] Servidor esta corriendo")
        print(f"Status Code: {response.status_code}")
        return True
    except requests.exceptions.ConnectionError:
        print(f"[ERROR] No se puede conectar al servidor")
        print(f"   Asegurate de que Django este corriendo en {BASE_URL}")
        return False
    except Exception as e:
        print(f"[ERROR] {e}")
        return False

def test_register():
    """Probar registro de usuario"""
    print_separator("TEST 2: Registro de Usuario")
    url = f"{BASE_URL}/api/users/register/"

    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    data = {
        "username": f"test{timestamp}",
        "email": f"test{timestamp}@test.com",
        "password": "Test1234",
        "password2": "Test1234",
        "first_name": "Usuario",
        "last_name": "Prueba",
        "native_language": "es",
        "target_language": "en",
        "age": 25,
        "nationality": "Bolivia"
    }

    print(f"POST {url}")
    print(f"Data: {json.dumps(data, indent=2)}")

    try:
        response = requests.post(url, json=data, timeout=10)
        print_response(response)

        if response.status_code == 201:
            print("[OK] Registro exitoso")
            return True, data['username']
        else:
            print("[WARNING] Registro fallo")
            return False, None
    except Exception as e:
        print(f"[ERROR] {e}")
        return False, None

def test_login(username="maria", password="Test1234"):
    """Probar login"""
    print_separator("TEST 3: Login")
    url = f"{BASE_URL}/api/auth/token/"
    data = {
        "username": username,
        "password": password
    }

    print(f"POST {url}")
    print(f"Credentials: username={username}, password={password}")

    try:
        response = requests.post(url, json=data, timeout=10)
        print_response(response)

        if response.status_code == 200:
            tokens = response.json()
            print("[OK] Login exitoso")
            print(f"Access Token: {tokens['access'][:50]}...")
            return tokens['access']
        else:
            print("[ERROR] Login fallo")
            return None
    except Exception as e:
        print(f"[ERROR] {e}")
        return None

def test_me(token):
    """Probar endpoint protegido /me/"""
    print_separator("TEST 4: GET /api/users/me/")
    url = f"{BASE_URL}/api/users/me/"
    headers = {
        "Authorization": f"Bearer {token}"
    }

    print(f"GET {url}")
    print(f"Authorization: Bearer {token[:30]}...")

    try:
        response = requests.get(url, headers=headers, timeout=10)
        print_response(response)

        if response.status_code == 200:
            print("[OK] Endpoint /me/ funciona correctamente")
            return True
        else:
            print("[ERROR] Error al acceder a /me/")
            return False
    except Exception as e:
        print(f"[ERROR] {e}")
        return False

def test_lessons(token):
    """Probar lista de lecciones"""
    print_separator("TEST 5: GET /api/lessons/all-lessons/")
    url = f"{BASE_URL}/api/lessons/all-lessons/"
    headers = {
        "Authorization": f"Bearer {token}"
    }

    print(f"GET {url}")

    try:
        response = requests.get(url, headers=headers, timeout=10)
        print(f"Status Code: {response.status_code}")

        if response.status_code == 200:
            lessons = response.json()
            print(f"[OK] Total de lecciones disponibles: {len(lessons)}")

            if lessons:
                print(f"\nPrimera leccion:")
                print(json.dumps(lessons[0], indent=2, ensure_ascii=False))
            else:
                print("[WARNING] No hay lecciones en la base de datos")
                print("   Ejecuta: python manage.py seed_core_and_greetings")
            return True
        else:
            print("[ERROR] Error al obtener lecciones")
            print_response(response)
            return False
    except Exception as e:
        print(f"[ERROR] {e}")
        return False

def test_stats(token):
    """Probar estadísticas del usuario"""
    print_separator("TEST 6: GET /api/users/stats/")
    url = f"{BASE_URL}/api/users/stats/"
    headers = {
        "Authorization": f"Bearer {token}"
    }

    try:
        response = requests.get(url, headers=headers, timeout=10)
        print_response(response)

        if response.status_code == 200:
            print("[OK] Estadisticas obtenidas correctamente")
            return True
        else:
            print("[WARNING] Endpoint de estadisticas no responde correctamente")
            return False
    except Exception as e:
        print(f"[ERROR] {e}")
        return False

def main():
    """Ejecutar todos los tests"""
    print("\n" + "="*60)
    print(" "*10 + "PRUEBAS DE API - BACKEND IDIOMAS")
    print("="*60)

    results = {
        "total": 0,
        "passed": 0,
        "failed": 0
    }

    # TEST 1: Verificar servidor
    results["total"] += 1
    if test_server():
        results["passed"] += 1
    else:
        results["failed"] += 1
        print("\n[WARNING] El servidor no esta corriendo. Deteniendo pruebas.")
        print("\nPara iniciar el servidor, ejecuta:")
        print("  cd backend")
        print("  python manage.py runserver")
        return

    # TEST 2: Registro (opcional - comentar si falla por usuario duplicado)
    results["total"] += 1
    success, new_username = test_register()
    if success:
        results["passed"] += 1
    else:
        results["failed"] += 1

    # TEST 3: Login
    results["total"] += 1
    token = test_login()  # Usar usuario de prueba
    if token:
        results["passed"] += 1
    else:
        results["failed"] += 1
        print("\n[ERROR] No se pudo obtener token. Deteniendo pruebas.")
        print_final_results(results)
        return

    # TEST 4: Endpoint /me/
    results["total"] += 1
    if test_me(token):
        results["passed"] += 1
    else:
        results["failed"] += 1

    # TEST 5: Lecciones
    results["total"] += 1
    if test_lessons(token):
        results["passed"] += 1
    else:
        results["failed"] += 1

    # TEST 6: Estadísticas
    results["total"] += 1
    if test_stats(token):
        results["passed"] += 1
    else:
        results["failed"] += 1

    # Resultados finales
    print_final_results(results)

def print_final_results(results):
    """Imprimir resultados finales"""
    print("\n" + "="*60)
    print(" "*18 + "RESUMEN DE PRUEBAS")
    print("="*60)
    print(f"  Total de pruebas: {results['total']}")
    print(f"  [OK] Exitosas: {results['passed']}")
    print(f"  [X] Fallidas: {results['failed']}")
    print("="*60)

    if results['failed'] == 0:
        print("\n[SUCCESS] TODAS LAS PRUEBAS PASARON EXITOSAMENTE!")
    else:
        print(f"\n[WARNING] {results['failed']} prueba(s) fallaron. Revisa los logs arriba.")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n[WARNING] Pruebas interrumpidas por el usuario")
    except Exception as e:
        print(f"\n\n[ERROR] ERROR CRITICO: {e}")
        import traceback
        traceback.print_exc()
