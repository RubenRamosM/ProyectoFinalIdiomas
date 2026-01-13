import random
from django.core.management.base import BaseCommand
from django.db import transaction
from core.models import Language
from leccion.models import Lesson, LessonLocalization, Exercise, ExerciseLocalization, ExerciseOption

PROMPTS = {
    "es": {
        "mc": "Selecciona la opción correcta: {question}",
        "fill": "Completa la frase: {gap}",
        "pron": "Lee en voz alta: \"{text}\"",
        "match": "Empareja las expresiones con su traducción:",
    }
}

def p(lang, key, **kw):
    return PROMPTS.get(lang, PROMPTS["es"]).get(key, key).format(**kw)

def ensure_languages():
    for code, name in {"es": "Español", "en": "English"}.items():
        Language.objects.get_or_create(code=code, defaults={"name": name})

def create_mc(ex, q, correct, distractors):
    loc = ExerciseLocalization.objects.create(
        exercise=ex,
        native_language=Language.objects.get(code="es"),
        target_language=Language.objects.get(code="en"),
        question=p("es", "mc", question=q),
        instructions="Elige la respuesta correcta."
    )
    opts = [{"text": correct[0], "correct": True, "feedback": correct[1]}]
    opts.extend([{"text": d[0], "correct": False, "feedback": d[1]} for d in distractors])
    random.shuffle(opts)
    for opt in opts:
        ExerciseOption.objects.create(
            exercise_localization=loc, text=opt["text"],
            is_correct=opt["correct"], feedback=opt["feedback"]
        )

def create_fill(ex, gap, answer, alt):
    loc = ExerciseLocalization.objects.create(
        exercise=ex,
        native_language=Language.objects.get(code="es"),
        target_language=Language.objects.get(code="en"),
        question=p("es", "fill", gap=gap),
        instructions="Escribe la palabra que falta."
    )
    ExerciseOption.objects.create(
        exercise_localization=loc, text=answer, is_correct=True,
        feedback="✓ Correcto. '{}' es la respuesta adecuada.".format(answer)
    )
    for a in alt:
        ExerciseOption.objects.create(
            exercise_localization=loc, text=a[0], is_correct=False,
            feedback="✗ Incorrecto. {}".format(a[1])
        )

def create_pron(ex, text, tip):
    ExerciseLocalization.objects.create(
        exercise=ex,
        native_language=Language.objects.get(code="es"),
        target_language=Language.objects.get(code="en"),
        question=p("es", "pron", text=text),
        instructions="Graba tu pronunciación. " + tip,
        expected_audio_text=text
    )

def create_match(ex, pairs):
    shuffled = pairs.copy()
    random.shuffle(shuffled)
    loc = ExerciseLocalization.objects.create(
        exercise=ex,
        native_language=Language.objects.get(code="es"),
        target_language=Language.objects.get(code="en"),
        question=p("es", "match"),
        instructions="Arrastra para emparejar.",
        matching_pairs=[{"target": t, "native": n} for t, n in shuffled]
    )
    ExerciseOption.objects.create(
        exercise_localization=loc, text="fb", is_correct=True,
        feedback="✓ Bien hecho. Dominaste este vocabulario."
    )

@transaction.atomic
def seed_lesson(title_key, seq, title, content, ex_data):
    lesson, _ = Lesson.objects.get_or_create(
        title_key=title_key, level="A2", lesson_type="vocabulary",
        defaults={"sequence": seq, "difficulty": 2, "is_active": True}
    )
    LessonLocalization.objects.get_or_create(
        lesson=lesson,
        native_language=Language.objects.get(code="es"),
        target_language=Language.objects.get(code="en"),
        defaults={"title": title, "content": content, "resources": {"cefr": "A2"}}
    )
    
    s = 10
    for ed in ex_data:
        s += 10
        ex, _ = Exercise.objects.get_or_create(
            lesson=lesson, sequence=s, exercise_type=ed["type"],
            defaults={"instructions_key": ed["type"]}
        )
        if ed["type"] == "multiple_choice":
            create_mc(ex, ed["q"], ed["correct"], ed["dist"])
        elif ed["type"] == "fill_blank":
            create_fill(ex, ed["gap"], ed["ans"], ed["alt"])
        elif ed["type"] == "shadowing":
            create_pron(ex, ed["text"], ed["tip"])
        elif ed["type"] == "matching":
            create_match(ex, ed["pairs"])

class Command(BaseCommand):
    help = "Crea 3 lecciones para el nivel A2"

    def handle(self, *args, **options):
        self.stdout.write(self.style.MIGRATE_HEADING("=" * 70))
        self.stdout.write(self.style.MIGRATE_HEADING("POBLANDO NIVEL A2 - 3 LECCIONES"))
        self.stdout.write(self.style.MIGRATE_HEADING("=" * 70))
        
        ensure_languages()
        
        # ========== LECCIÓN 1: FAMILIA Y RELACIONES ==========
        self.stdout.write("\n[1/3] Creando: Familia y Relaciones...")
        ex1 = [
            {"type": "multiple_choice", "q": "¿Cómo se dice 'hermana' en inglés?",
             "correct": ("Sister", "✓ 'Sister' es hermana."),
             "dist": [("Brother", "✗ 'Brother' es hermano."), ("Mother", "✗ 'Mother' es madre."), ("Aunt", "✗ 'Aunt' es tía.")]},
            {"type": "shadowing", "text": "My sister is younger than my brother.",
             "tip": "Enfatiza 'younger than' como una unidad."},
            {"type": "matching", "pairs": [("Mother", "Madre"), ("Father", "Padre"), ("Sister", "Hermana"), ("Brother", "Hermano"), ("Cousin", "Primo/a")]},
            {"type": "multiple_choice", "q": "¿Quién es el padre de tu padre?",
             "correct": ("Grandfather", "✓ 'Grandfather' es abuelo."),
             "dist": [("Uncle", "✗ 'Uncle' es tío."), ("Father", "✗ Tu padre, no su padre."), ("Nephew", "✗ 'Nephew' es sobrino.")]},
            {"type": "shadowing", "text": "My grandparents live in the countryside.",
             "tip": "Pronuncia 'grandparents' /ˈɡrænpɛrənts/ claramente."},
            {"type": "matching", "pairs": [("Grandmother", "Abuela"), ("Grandfather", "Abuelo"), ("Uncle", "Tío"), ("Aunt", "Tía"), ("Nephew", "Sobrino")]},
            {"type": "fill_blank", "gap": "My ___ is my mother's sister.",
             "ans": "aunt", "alt": [("uncle", "'Uncle' es tío, no tía."), ("sister", "'Sister' es tu hermana, no la de tu madre.")]},
            {"type": "shadowing", "text": "I have two aunts and three uncles.",
             "tip": "Diferencia 'aunts' /ænts/ de 'ants' (hormigas)."},
            {"type": "fill_blank", "gap": "Her ___ is only five years old.",
             "ans": "son", "alt": [("sun", "'Sun' es sol, no hijo."), ("daughter", "'Daughter' es hija, no hijo.")]}
        ]
        seed_lesson("family_relations_a2", 10, "Familia y Relaciones",
                    "Vocabulario sobre miembros de la familia y relaciones familiares básicas.", ex1)
        self.stdout.write(self.style.SUCCESS("  ✓ 9 ejercicios creados"))
        
        # ========== LECCIÓN 2: COMIDA Y BEBIDAS ==========
        self.stdout.write("\n[2/3] Creando: Comida y Bebidas...")
        ex2 = [
            {"type": "multiple_choice", "q": "¿Qué bebes en el desayuno típicamente?",
             "correct": ("Coffee or tea", "✓ Bebidas comunes en el desayuno."),
             "dist": [("Wine", "✗ 'Wine' se bebe generalmente en la cena."), ("Soup", "✗ 'Soup' es sopa, se come, no se bebe."), ("Bread", "✗ 'Bread' es pan, no bebida.")]},
            {"type": "shadowing", "text": "I usually drink coffee with milk for breakfast.",
             "tip": "Conecta 'drink coffee' fluidamente. 'Milk' tiene 'l' silenciosa para algunos."},
            {"type": "matching", "pairs": [("Water", "Agua"), ("Coffee", "Café"), ("Tea", "Té"), ("Juice", "Jugo"), ("Milk", "Leche")]},
            {"type": "multiple_choice", "q": "¿Qué fruta es amarilla y dulce?",
             "correct": ("Banana", "✓ 'Banana' es amarilla."),
             "dist": [("Apple", "✗ 'Apple' es generalmente roja o verde."), ("Carrot", "✗ 'Carrot' es zanahoria, una verdura naranja."), ("Tomato", "✗ 'Tomato' es rojo.")]},
            {"type": "shadowing", "text": "I eat an apple and a banana every day.",
             "tip": "Pronuncia 'apple' /ˈæpəl/ y 'banana' /bəˈnænə/."},
            {"type": "matching", "pairs": [("Apple", "Manzana"), ("Banana", "Plátano"), ("Orange", "Naranja"), ("Bread", "Pan"), ("Rice", "Arroz")]},
            {"type": "fill_blank", "gap": "I need to buy some ___ for the salad. (lechuga)",
             "ans": "lettuce", "alt": [("meat", "'Meat' es carne, no va típicamente en ensalada."), ("sugar", "'Sugar' es azúcar, no para ensalada.")]},
            {"type": "shadowing", "text": "We need lettuce, tomatoes, and onions for the salad.",
             "tip": "Pronuncia 'lettuce' /ˈlɛtɪs/ y 'tomatoes' /təˈmeɪtoʊz/."},
            {"type": "fill_blank", "gap": "She drinks a glass of ___ every morning. (agua)",
             "ans": "water", "alt": [("wine", "'Wine' no es común en la mañana."), ("soup", "'Soup' es sopa, no se bebe en vaso típicamente.")]}
        ]
        seed_lesson("food_drinks_a2", 20, "Comida y Bebidas",
                    "Aprende vocabulario sobre alimentos, bebidas y comidas del día.", ex2)
        self.stdout.write(self.style.SUCCESS("  ✓ 9 ejercicios creados"))
        
        # ========== LECCIÓN 3: LA CASA Y HABITACIONES ==========
        self.stdout.write("\n[3/3] Creando: La Casa y Habitaciones...")
        ex3 = [
            {"type": "multiple_choice", "q": "¿Dónde duermes por la noche?",
             "correct": ("Bedroom", "✓ 'Bedroom' es el dormitorio."),
             "dist": [("Kitchen", "✗ 'Kitchen' es la cocina."), ("Bathroom", "✗ 'Bathroom' es el baño."), ("Living room", "✗ 'Living room' es la sala.")]},
            {"type": "shadowing", "text": "I sleep in my bedroom and cook in the kitchen.",
             "tip": "Conecta 'sleep in' y 'cook in' naturalmente."},
            {"type": "matching", "pairs": [("Bedroom", "Dormitorio"), ("Kitchen", "Cocina"), ("Bathroom", "Baño"), ("Living room", "Sala"), ("Dining room", "Comedor")]},
            {"type": "multiple_choice", "q": "¿Dónde te lavas las manos?",
             "correct": ("Bathroom", "✓ Te lavas en el baño."),
             "dist": [("Bedroom", "✗ El dormitorio es para dormir."), ("Garage", "✗ El garaje es para el auto."), ("Garden", "✗ El jardín está afuera.")]},
            {"type": "shadowing", "text": "The bathroom has a sink, a toilet, and a shower.",
             "tip": "Pronuncia 'sink' /sɪŋk/ y 'toilet' /ˈtɔɪlət/."},
            {"type": "matching", "pairs": [("Window", "Ventana"), ("Door", "Puerta"), ("Roof", "Techo"), ("Wall", "Pared"), ("Floor", "Piso")]},
            {"type": "fill_blank", "gap": "We watch TV in the ___. (sala)",
             "ans": "living room", "alt": [("bedroom", "Bedroom es dormitorio."), ("kitchen", "Kitchen es cocina.")]},
            {"type": "shadowing", "text": "There are three bedrooms and two bathrooms in our house.",
             "tip": "Enfatiza 'three bedrooms' y 'two bathrooms'."},
            {"type": "fill_blank", "gap": "The car is parked in the ___. (garaje)",
             "ans": "garage", "alt": [("garden", "'Garden' es jardín."), ("kitchen", "'Kitchen' es cocina.")]}
        ]
        seed_lesson("house_rooms_a2", 30, "La Casa y Habitaciones",
                    "Identifica las habitaciones de una casa y objetos comunes en cada espacio.", ex3)
        self.stdout.write(self.style.SUCCESS("  ✓ 9 ejercicios creados"))
        
        self.stdout.write("\n" + "=" * 70)
        self.stdout.write(self.style.SUCCESS("✓ NIVEL A2 COMPLETO - 3 LECCIONES"))
        self.stdout.write("=" * 70 + "\n")
