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
        print(f"✅ Servidor está corriendo")
        print(f"Status Code: {response.status_code}")
        return True
    except requests.exceptions.ConnectionError:
        print(f"❌ ERROR: No se puede conectar al servidor")
        print(f"   Asegúrate de que Django esté corriendo en {BASE_URL}")
        return False
    except Exception as e:
        print(f"❌ ERROR: {e}")
        return False

def test_register():
    """Probar registro de usuario"""
    print_separator("TEST 2: Registro de Usuario")
    url = f"{BASE_URL}/api/auth/register/"

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
            print("✅ Registro exitoso")
            return True, data['username']
        else:
            print("⚠️  Registro falló")
            return False, None
    except Exception as e:
        print(f"❌ ERROR: {e}")
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
            print("✅ Login exitoso")
            print(f"Access Token: {tokens['access'][:50]}...")
            return tokens['access']
        else:
            print("❌ Login falló")
            return None
    except Exception as e:
        print(f"❌ ERROR: {e}")
        return None

def test_me(token):
    """Probar endpoint protegido /me/"""
    print_separator("TEST 4: GET /api/auth/me/")
    url = f"{BASE_URL}/api/auth/me/"
    headers = {
        "Authorization": f"Bearer {token}"
    }

    print(f"GET {url}")
    print(f"Authorization: Bearer {token[:30]}...")

    try:
        response = requests.get(url, headers=headers, timeout=10)
        print_response(response)

        if response.status_code == 200:
            print("✅ Endpoint /me/ funciona correctamente")
            return True
        else:
            print("❌ Error al acceder a /me/")
            return False
    except Exception as e:
        print(f"❌ ERROR: {e}")
        return False

def test_lessons(token):
    """Probar lista de lecciones"""
    print_separator("TEST 5: GET /api/lecciones/")
    url = f"{BASE_URL}/api/lecciones/"
    headers = {
        "Authorization": f"Bearer {token}"
    }

    print(f"GET {url}")

    try:
        response = requests.get(url, headers=headers, timeout=10)
        print(f"Status Code: {response.status_code}")

        if response.status_code == 200:
            lessons = response.json()
            print(f"✅ Total de lecciones disponibles: {len(lessons)}")

            if lessons:
                print(f"\nPrimera lección:")
                print(json.dumps(lessons[0], indent=2, ensure_ascii=False))
            else:
                print("⚠️  No hay lecciones en la base de datos")
                print("   Ejecuta: python manage.py seed_core_and_greetings")
            return True
        else:
            print("❌ Error al obtener lecciones")
            print_response(response)
            return False
    except Exception as e:
        print(f"❌ ERROR: {e}")
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
            print("✅ Estadísticas obtenidas correctamente")
            return True
        else:
            print("⚠️  Endpoint de estadísticas no responde correctamente")
            return False
    except Exception as e:
        print(f"❌ ERROR: {e}")
        return False

def main():
    """Ejecutar todos los tests"""
    print("\n" + "╔" + "="*58 + "╗")
    print("║" + " "*10 + "PRUEBAS DE API - BACKEND IDIOMAS" + " "*16 + "║")
    print("╚" + "="*58 + "╝")

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
        print("\n⚠️  El servidor no está corriendo. Deteniendo pruebas.")
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
        print("\n❌ No se pudo obtener token. Deteniendo pruebas.")
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
    print("\n" + "╔" + "="*58 + "╗")
    print("║" + " "*18 + "RESUMEN DE PRUEBAS" + " "*23 + "║")
    print("╠" + "="*58 + "╣")
    print(f"║  Total de pruebas: {results['total']:<42} ║")
    print(f"║  ✅ Exitosas: {results['passed']:<46} ║")
    print(f"║  ❌ Fallidas: {results['failed']:<46} ║")
    print("╚" + "="*58 + "╝")

    if results['failed'] == 0:
        print("\n🎉 ¡TODAS LAS PRUEBAS PASARON EXITOSAMENTE!")
    else:
        print(f"\n⚠️  {results['failed']} prueba(s) fallaron. Revisa los logs arriba.")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n⚠️  Pruebas interrumpidas por el usuario")
    except Exception as e:
        print(f"\n\n❌ ERROR CRÍTICO: {e}")
        import traceback
        traceback.print_exc()
