"""
Test rápido del servicio del tutor
Ejecutar: python test_tutor_quick.py
"""
import os
import sys
import django
from dotenv import load_dotenv

# Cargar variables de entorno
load_dotenv()

# Configurar Django
sys.path.insert(0, os.path.dirname(__file__))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'idiomasapp.settings')
django.setup()

from ia.services.tutor_service import chat_with_tutor

def test():
    print("🧪 Probando el servicio del tutor...\n")
    
    # Verificar API key
    if not os.getenv("GROQ_API_KEY"):
        print("❌ ERROR: GROQ_API_KEY no está configurada")
        return
    
    print("✅ GROQ_API_KEY configurada")
    print(f"✅ Modelo: {os.getenv('GROQ_MODEL', 'llama-3.3-70b-versatile')}\n")
    
    # Test simple
    print("📤 Pregunta: ¿Cómo se dice 'hello' en francés?")
    print("⏳ Esperando respuesta...\n")
    
    try:
        response = chat_with_tutor(
            message="¿Cómo se dice 'hello' en francés?",
            conversation_history=[],
            user_target_language="francés"
        )
        
        print("🤖 Respuesta del tutor:")
        print("-" * 60)
        print(response)
        print("-" * 60)
        print("\n✅ Test completado exitosamente!")
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test()
