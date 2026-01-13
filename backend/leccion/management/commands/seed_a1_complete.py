import random
from django.core.management.base import BaseCommand
from django.db import transaction
from core.models import Language
from leccion.models import Lesson, LessonLocalization, Exercise, ExerciseLocalization, ExerciseOption

PROMPTS = {
    "es": {
        "mc_translate": "¿Cómo se dice \"{phrase}\" en inglés?",
        "mc_choose": "Selecciona la respuesta correcta para: {context}",
        "fill_complete": "Completa la frase: {gap}",
        "pron_say": "Pronuncia correctamente: \"{text}\"",
        "matching": "Empareja cada palabra en inglés con su traducción en español:",
        "instr_mc": "Elige la opción correcta.",
        "instr_fill": "Escribe la palabra que falta.",
        "instr_pron": "Graba tu pronunciación clara y pausada.",
        "instr_match": "Arrastra para emparejar correctamente.",
    }
}

def p(lang, key, **kw):
    return PROMPTS.get(lang, PROMPTS["es"]).get(key, key).format(**kw)

def ensure_languages():
    langs = {"es": "Español", "en": "English"}
    for code, name in langs.items():
        Language.objects.get_or_create(code=code, defaults={"name": name})

def create_mc(ex, native, target, question, correct, distractors):
    loc = ExerciseLocalization.objects.create(
        exercise=ex,
        native_language=Language.objects.get(code=native),
        target_language=Language.objects.get(code=target),
        question=question,
        instructions=p(native, "instr_mc")
    )
    opts = [{"text": correct[0], "correct": True, "feedback": correct[1]}]
    opts.extend([{"text": d[0], "correct": False, "feedback": d[1]} for d in distractors])
    random.shuffle(opts)
    for opt in opts:
        ExerciseOption.objects.create(
            exercise_localization=loc,
            text=opt["text"],
            is_correct=opt["correct"],
            feedback=opt["feedback"]
        )

def create_fill(ex, native, target, gap, answer, alt):
    loc = ExerciseLocalization.objects.create(
        exercise=ex,
        native_language=Language.objects.get(code=native),
        target_language=Language.objects.get(code=target),
        question=p(native, "fill_complete", gap=gap),
        instructions=p(native, "instr_fill")
    )
    ExerciseOption.objects.create(
        exercise_localization=loc, text=answer, is_correct=True,
        feedback="✓ Correcto. Usas '{}' en este contexto.".format(answer)
    )
    for a in alt:
        ExerciseOption.objects.create(
            exercise_localization=loc, text=a[0], is_correct=False,
            feedback="✗ Incorrecto. {}".format(a[1])
        )

def create_pron(ex, native, target, text, tip):
    ExerciseLocalization.objects.create(
        exercise=ex,
        native_language=Language.objects.get(code=native),
        target_language=Language.objects.get(code=target),
        question=p(native, "pron_say", text=text),
        instructions=p(native, "instr_pron") + " Tip: " + tip,
        expected_audio_text=text
    )

def create_match(ex, native, target, pairs):
    shuffled = pairs.copy()
    random.shuffle(shuffled)
    loc = ExerciseLocalization.objects.create(
        exercise=ex,
        native_language=Language.objects.get(code=native),
        target_language=Language.objects.get(code=target),
        question=p(native, "matching"),
        instructions=p(native, "instr_match"),
        matching_pairs=[{"target": t, "native": n} for t, n in shuffled]
    )
    ExerciseOption.objects.create(
        exercise_localization=loc, text="feedback", is_correct=True,
        feedback="✓ Excelente. Has emparejado correctamente el vocabulario básico."
    )

@transaction.atomic
def seed_lesson(title_key, title_es, content_es, exercises_data):
    lesson, _ = Lesson.objects.get_or_create(
        title_key=title_key, level="A1", lesson_type="vocabulary",
        defaults={"sequence": 20, "difficulty": 1, "is_active": True}
    )
    LessonLocalization.objects.get_or_create(
        lesson=lesson,
        native_language=Language.objects.get(code="es"),
        target_language=Language.objects.get(code="en"),
        defaults={"title": title_es, "content": content_es, "resources": {"cefr": "A1"}}
    )
    
    seq = 10
    for ex_data in exercises_data:
        seq += 10
        ex, _ = Exercise.objects.get_or_create(
            lesson=lesson, sequence=seq, exercise_type=ex_data["type"],
            defaults={"instructions_key": ex_data["type"]}
        )
        
        if ex_data["type"] == "multiple_choice":
            create_mc(ex, "es", "en", ex_data["q"], ex_data["correct"], ex_data["distractors"])
        elif ex_data["type"] == "fill_blank":
            create_fill(ex, "es", "en", ex_data["gap"], ex_data["answer"], ex_data["alt"])
        elif ex_data["type"] == "shadowing":
            create_pron(ex, "es", "en", ex_data["text"], ex_data["tip"])
        elif ex_data["type"] == "matching":
            create_match(ex, "es", "en", ex_data["pairs"])

class Command(BaseCommand):
    help = "Completa el nivel A1 con 2 lecciones adicionales (Números y Colores/Objetos)"

    def handle(self, *args, **options):
        self.stdout.write(self.style.MIGRATE_HEADING("=" * 70))
        self.stdout.write(self.style.MIGRATE_HEADING("POBLANDO NIVEL A1 - LECCIONES ADICIONALES"))
        self.stdout.write(self.style.MIGRATE_HEADING("=" * 70))
        
        ensure_languages()
        
        # ========== LECCIÓN 2: NÚMEROS Y CANTIDADES ==========
        self.stdout.write("\n[1/2] Creando lección: Números y Cantidades...")
        exercises_numbers = [
            # MC 1
            {"type": "multiple_choice", "q": "¿Cómo se dice 'uno' en inglés?",
             "correct": ("One", "✓ Correcto. 'One' es el número 1 en inglés."),
             "distractors": [
                 ("First", "✗ 'First' es ordinal (primero), no cardinal."),
                 ("A", "✗ 'A' es un artículo, aunque a veces reemplaza 'one'."),
                 ("Once", "✗ 'Once' significa 'una vez', no el número uno.")
             ]},
            # Pronunciación 1
            {"type": "shadowing", "text": "One, two, three, four, five",
             "tip": "Enfatiza cada número por separado. 'Three' se pronuncia /θriː/."},
            # Matching 1
            {"type": "matching", "pairs": [
                ("One", "Uno"), ("Two", "Dos"), ("Three", "Tres"),
                ("Four", "Cuatro"), ("Five", "Cinco")
            ]},
            # MC 2
            {"type": "multiple_choice", "q": "¿Qué número falta? One, two, ___, four",
             "correct": ("Three", "✓ Correcto. La secuencia es 1, 2, 3, 4."),
             "distractors": [
                 ("Five", "✗ Five viene después de four."),
                 ("Ten", "✗ Ten es el número 10, muy adelante en la secuencia."),
                 ("Zero", "✗ Zero viene antes de one.")
             ]},
            # Pronunciación 2
            {"type": "shadowing", "text": "Six, seven, eight, nine, ten",
             "tip": "Nota la 'x' en 'six' suena como /ks/. 'Eight' se pronuncia /eɪt/."},
            # Matching 2
            {"type": "matching", "pairs": [
                ("Six", "Seis"), ("Seven", "Siete"), ("Eight", "Ocho"),
                ("Nine", "Nueve"), ("Ten", "Diez")
            ]},
            # Fill 1
            {"type": "fill_blank", "gap": "I have ___ apples. (3)",
             "answer": "three",
             "alt": [
                 ("tree", "'Tree' significa árbol, no el número tres."),
                 ("third", "'Third' es ordinal (tercero), no cantidad.")
             ]},
            # Pronunciación 3
            {"type": "shadowing", "text": "I have five books and ten pencils.",
             "tip": "Conecta 'have' y 'five' fluidamente. Pronuncia claramente 'books' /bʊks/."},
            # Fill 2
            {"type": "fill_blank", "gap": "There are ___ days in a week. (7)",
             "answer": "seven",
             "alt": [
                 ("heaven", "'Heaven' significa cielo, no es un número."),
                 ("several", "'Several' significa varios, pero no es el número 7.")
             ]},
        ]
        
        seed_lesson(
            "numbers_quantities_a1",
            "Números y Cantidades",
            "Aprende los números del 1 al 10 en inglés y cómo usarlos en frases simples. Practica pronunciación y reconocimiento de cantidades básicas.",
            exercises_numbers
        )
        self.stdout.write(self.style.SUCCESS("  ✓ Lección 'Números y Cantidades' creada con 9 ejercicios"))
        
        # ========== LECCIÓN 3: COLORES Y OBJETOS COTIDIANOS ==========
        self.stdout.write("\n[2/2] Creando lección: Colores y Objetos Cotidianos...")
        exercises_colors = [
            # MC 1
            {"type": "multiple_choice", "q": "¿De qué color es el cielo en un día soleado?",
             "correct": ("Blue", "✓ Correcto. El cielo es azul (blue) cuando está despejado."),
             "distractors": [
                 ("Red", "✗ Red (rojo) no describe el cielo despejado."),
                 ("Green", "✗ Green (verde) no es el color del cielo."),
                 ("Yellow", "✗ Yellow (amarillo) puede ser el sol, pero no el cielo.")
             ]},
            # Pronunciación 1
            {"type": "shadowing", "text": "The sky is blue and the grass is green.",
             "tip": "Enfatiza 'blue' /bluː/ y 'green' /ɡriːn/. La 'r' en 'grass' es suave."},
            # Matching 1
            {"type": "matching", "pairs": [
                ("Red", "Rojo"), ("Blue", "Azul"), ("Green", "Verde"),
                ("Yellow", "Amarillo"), ("White", "Blanco")
            ]},
            # MC 2
            {"type": "multiple_choice", "q": "¿Qué objeto usas para escribir?",
             "correct": ("Pen", "✓ Correcto. 'Pen' (bolígrafo) se usa para escribir."),
             "distractors": [
                 ("Book", "✗ Un 'book' (libro) es para leer, no para escribir."),
                 ("Chair", "✗ Una 'chair' (silla) es para sentarse."),
                 ("Window", "✗ Una 'window' (ventana) no tiene relación con escribir.")
             ]},
            # Pronunciación 2
            {"type": "shadowing", "text": "I have a red pen and a blue book.",
             "tip": "Conecta 'a red' sin pausa. Pronuncia 'pen' /pen/ y 'book' /bʊk/."},
            # Matching 2
            {"type": "matching", "pairs": [
                ("Book", "Libro"), ("Pen", "Bolígrafo"), ("Table", "Mesa"),
                ("Chair", "Silla"), ("Door", "Puerta")
            ]},
            # Fill 1
            {"type": "fill_blank", "gap": "The apple is ___. (rojo)",
             "answer": "red",
             "alt": [
                 ("read", "'Read' es el verbo leer, no el color rojo."),
                 ("bed", "'Bed' significa cama, no tiene relación con colores.")
             ]},
            # Pronunciación 3
            {"type": "shadowing", "text": "This is a black cat and a white dog.",
             "tip": "Diferencia 'black' /blæk/ de 'blue'. 'Cat' tiene 'a' corta /kæt/."},
            # Fill 2
            {"type": "fill_blank", "gap": "I sit on the ___. (silla)",
             "answer": "chair",
             "alt": [
                 ("table", "'Table' es mesa, no silla."),
                 ("floor", "'Floor' es piso, aunque puedes sentarte ahí, no es una silla.")
             ]},
        ]
        
        seed_lesson(
            "colors_objects_a1",
            "Colores y Objetos Cotidianos",
            "Identifica colores básicos y objetos de uso diario en inglés. Practica describir objetos simples usando adjetivos de color.",
            exercises_colors
        )
        self.stdout.write(self.style.SUCCESS("  ✓ Lección 'Colores y Objetos' creada con 9 ejercicios"))
        
        self.stdout.write("\n" + "=" * 70)
        self.stdout.write(self.style.SUCCESS("✓ NIVEL A1 COMPLETO - 3 LECCIONES TOTALES"))
        self.stdout.write("=" * 70)
        self.stdout.write("\nLecciones A1:")
        self.stdout.write("  1. Saludos y Presentaciones (20 ejercicios) - Ya existente")
        self.stdout.write("  2. Números y Cantidades (9 ejercicios)")
        self.stdout.write("  3. Colores y Objetos Cotidianos (9 ejercicios)")
        self.stdout.write("\n" + "=" * 70 + "\n")
