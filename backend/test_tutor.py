# Test script para verificar el servicio del tutor
# Ejecutar con: python test_tutor.py

import os
import sys
import django

# Configurar Django
sys.path.insert(0, os.path.dirname(__file__))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'idiomasapp.settings')
django.setup()

from ia.services.tutor_service import chat_with_tutor, generate_conversation_title

def test_basic_chat():
    """Test básico de chat con el tutor."""
    print("=" * 60)
    print("TEST 1: Chat básico con el tutor")
    print("=" * 60)
    
    message = "¿Cuál es la diferencia entre 'do' y 'make' en inglés?"
    print(f"\n📤 Usuario: {message}")
    
    response = chat_with_tutor(
        message=message,
        conversation_history=[],
        user_target_language="inglés"
    )
    
    print(f"\n🤖 Tutor: {response}")
    print("\n✅ Test completado exitosamente\n")
    return response

def test_conversation_context():
    """Test de chat con contexto de conversación."""
    print("=" * 60)
    print("TEST 2: Chat con contexto de conversación")
    print("=" * 60)
    
    # Primer mensaje
    msg1 = "¿Qué es el presente perfecto?"
    print(f"\n📤 Usuario: {msg1}")
    
    resp1 = chat_with_tutor(
        message=msg1,
        conversation_history=[],
        user_target_language="inglés"
    )
    print(f"\n🤖 Tutor: {resp1[:200]}...")
    
    # Segundo mensaje con contexto
    history = [
        {"role": "user", "content": msg1},
        {"role": "assistant", "content": resp1}
    ]
    
    msg2 = "Dame 3 ejemplos"
    print(f"\n📤 Usuario: {msg2}")
    
    resp2 = chat_with_tutor(
        message=msg2,
        conversation_history=history,
        user_target_language="inglés"
    )
    print(f"\n🤖 Tutor: {resp2}")
    print("\n✅ Test completado exitosamente\n")

def test_title_generation():
    """Test de generación de títulos."""
    print("=" * 60)
    print("TEST 3: Generación de títulos")
    print("=" * 60)
    
    messages = [
        "¿Cómo se dice 'hola' en francés?",
        "Explícame el uso de los artículos en alemán",
        "¿Cuál es la mejor manera de mejorar mi pronunciación?",
    ]
    
    for msg in messages:
        print(f"\n📤 Mensaje: {msg}")
        title = generate_conversation_title(msg)
        print(f"📋 Título generado: {title}")
    
    print("\n✅ Test completado exitosamente\n")

def test_different_languages():
    """Test con diferentes idiomas objetivo."""
    print("=" * 60)
    print("TEST 4: Diferentes idiomas objetivo")
    print("=" * 60)
    
    languages = [
        ("inglés", "¿Cómo formar preguntas?"),
        ("francés", "¿Cuándo usar tu vs vous?"),
        ("portugués", "¿Diferencia entre ser y estar?"),
    ]
    
    for lang, question in languages:
        print(f"\n📚 Idioma objetivo: {lang}")
        print(f"📤 Usuario: {question}")
        
        response = chat_with_tutor(
            message=question,
            conversation_history=[],
            user_target_language=lang
        )
        
        print(f"🤖 Tutor: {response[:150]}...")
    
    print("\n✅ Test completado exitosamente\n")

if __name__ == "__main__":
    print("\n" + "=" * 60)
    print("🧪 INICIANDO TESTS DEL TUTOR INTELIGENTE")
    print("=" * 60 + "\n")
    
    # Verificar que GROQ_API_KEY esté configurada
    if not os.environ.get("GROQ_API_KEY"):
        print("⚠️  WARNING: GROQ_API_KEY no está configurada")
        print("Las respuestas podrían ser el texto original sin procesar\n")
    
    try:
        # Ejecutar tests
        test_basic_chat()
        test_conversation_context()
        test_title_generation()
        test_different_languages()
        
        print("=" * 60)
        print("✅ TODOS LOS TESTS COMPLETADOS EXITOSAMENTE")
        print("=" * 60 + "\n")
        
    except Exception as e:
        print("\n" + "=" * 60)
        print("❌ ERROR EN LOS TESTS")
        print("=" * 60)
        print(f"\n{type(e).__name__}: {e}")
        import traceback
        traceback.print_exc()
