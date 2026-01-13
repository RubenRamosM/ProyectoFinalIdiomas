import random
from django.core.management.base import BaseCommand
from django.db import transaction
from core.models import Language
from leccion.models import Lesson, LessonLocalization, Exercise, ExerciseLocalization, ExerciseOption

def ensure_languages():
    for code, name in {"es": "Español", "en": "English"}.items():
        Language.objects.get_or_create(code=code, defaults={"name": name})

def create_mc(ex, q, c, d):
    loc = ExerciseLocalization.objects.create(
        exercise=ex, native_language=Language.objects.get(code="es"),
        target_language=Language.objects.get(code="en"),
        question=q, instructions="Elige la opción más apropiada."
    )
    opts = [{"text": c[0], "correct": True, "feedback": c[1]}]
    opts.extend([{"text": x[0], "correct": False, "feedback": x[1]} for x in d])
    random.shuffle(opts)
    for o in opts:
        ExerciseOption.objects.create(
            exercise_localization=loc, text=o["text"],
            is_correct=o["correct"], feedback=o["feedback"]
        )

def create_fill(ex, gap, ans, alt):
    loc = ExerciseLocalization.objects.create(
        exercise=ex, native_language=Language.objects.get(code="es"),
        target_language=Language.objects.get(code="en"),
        question="Completa con la palabra adecuada: " + gap,
        instructions="Escribe la respuesta correcta."
    )
    ExerciseOption.objects.create(
        exercise_localization=loc, text=ans, is_correct=True,
        feedback="✓ '{}' es correcto.".format(ans)
    )
    for a in alt:
        ExerciseOption.objects.create(
            exercise_localization=loc, text=a[0], is_correct=False,
            feedback="✗ " + a[1]
        )

def create_pron(ex, text, tip):
    ExerciseLocalization.objects.create(
        exercise=ex, native_language=Language.objects.get(code="es"),
        target_language=Language.objects.get(code="en"),
        question="Lee en voz alta: \"{}\"".format(text),
        instructions="Pronuncia con claridad. " + tip,
        expected_audio_text=text
    )

def create_match(ex, pairs):
    shuffled = pairs.copy()
    random.shuffle(shuffled)
    loc = ExerciseLocalization.objects.create(
        exercise=ex, native_language=Language.objects.get(code="es"),
        target_language=Language.objects.get(code="en"),
        question="Empareja las expresiones idiomáticas con su significado:",
        instructions="Arrastra para emparejar.",
        matching_pairs=[{"target": t, "native": n} for t, n in shuffled]
    )
    ExerciseOption.objects.create(
        exercise_localization=loc, text="fb", is_correct=True,
        feedback="✓ Dominaste estas expresiones avanzadas."
    )

@transaction.atomic
def seed_lesson(tk, seq, title, content, exs):
    lesson, _ = Lesson.objects.get_or_create(
        title_key=tk, level="B2", lesson_type="conversation",
        defaults={"sequence": seq, "difficulty": 4, "is_active": True}
    )
    LessonLocalization.objects.get_or_create(
        lesson=lesson, native_language=Language.objects.get(code="es"),
        target_language=Language.objects.get(code="en"),
        defaults={"title": title, "content": content, "resources": {"cefr": "B2"}}
    )
    s = 10
    for e in exs:
        s += 10
        ex, _ = Exercise.objects.get_or_create(
            lesson=lesson, sequence=s, exercise_type=e["type"],
            defaults={"instructions_key": e["type"]}
        )
        if e["type"] == "multiple_choice":
            create_mc(ex, e["q"], e["c"], e["d"])
        elif e["type"] == "fill_blank":
            create_fill(ex, e["gap"], e["ans"], e["alt"])
        elif e["type"] == "shadowing":
            create_pron(ex, e["text"], e["tip"])
        elif e["type"] == "matching":
            create_match(ex, e["pairs"])

class Command(BaseCommand):
    help = "Crea 3 lecciones para nivel B2"

    def handle(self, *args, **options):
        self.stdout.write(self.style.MIGRATE_HEADING("=" * 70))
        self.stdout.write(self.style.MIGRATE_HEADING("POBLANDO NIVEL B2 - 3 LECCIONES"))
        self.stdout.write(self.style.MIGRATE_HEADING("=" * 70))
        
        ensure_languages()
        
        # ========== LECCIÓN 1: PHRASAL VERBS COMUNES ==========
        self.stdout.write("\n[1/3] Creando: Phrasal Verbs Comunes...")
        ex1 = [
            {"type": "multiple_choice", "q": "¿Qué significa 'give up' en este contexto: 'Don't give up on your dreams'?",
             "c": ("rendirse", "✓ 'Give up' significa rendirse o abandonar."),
             "d": [("regalar", "✗ Eso sería 'give away'."), ("levantar", "✗ Eso sería 'lift up'."), ("subir", "✗ No es el significado de 'give up'.")]},
            {"type": "shadowing", "text": "You should never give up, even when things are difficult.",
             "tip": "Conecta 'give up' como una unidad. El acento está en 'give'."},
            {"type": "matching", "pairs": [("give up", "rendirse"), ("look after", "cuidar"), ("turn on", "encender"), ("turn off", "apagar"), ("put off", "posponer")]},
            {"type": "multiple_choice", "q": "Completa: I need to ___ this report by tomorrow. (entregar)",
             "c": ("hand in", "✓ 'Hand in' significa entregar algo oficial."),
             "d": [("hand out", "✗ 'Hand out' es repartir, no entregar."), ("hand over", "✗ 'Hand over' es transferir control."), ("hand up", "✗ No es un phrasal verb común.")]},
            {"type": "shadowing", "text": "Please hand in your assignments before Friday.",
             "tip": "'Hand in' es inseparable en este contexto. Acento en 'hand'."},
            {"type": "matching", "pairs": [("hand in", "entregar"), ("break down", "descomponerse"), ("call off", "cancelar"), ("come across", "encontrar por casualidad"), ("figure out", "resolver/entender")]},
            {"type": "fill_blank", "gap": "The meeting was ___ ___ due to bad weather. (cancelar)",
             "ans": "called off", "alt": [("called on", "'Called on' es visitar o pedir a alguien hablar."), ("called out", "'Called out' es gritar o confrontar.")]},
            {"type": "shadowing", "text": "We had to call off the picnic because of the rain.",
             "tip": "'Called off' puede separarse: 'call the picnic off'."},
            {"type": "fill_blank", "gap": "Can you ___ ___ the volume? It's too loud. (bajar)",
             "ans": "turn down", "alt": [("turn up", "'Turn up' es subir el volumen."), ("turn in", "'Turn in' es entregar o ir a dormir.")]},
        ]
        seed_lesson("phrasal_verbs_b2", 10, "Phrasal Verbs Comunes",
                    "Domina los phrasal verbs más frecuentes en conversaciones y escritura en inglés.", ex1)
        self.stdout.write(self.style.SUCCESS("  ✓ 9 ejercicios creados"))
        
        # ========== LECCIÓN 2: EXPRESIONES IDIOMÁTICAS ==========
        self.stdout.write("\n[2/3] Creando: Expresiones Idiomáticas...")
        ex2 = [
            {"type": "multiple_choice", "q": "¿Qué significa 'break the ice' en una reunión?",
             "c": ("romper el hielo/iniciar conversación", "✓ Es comenzar una conversación en situación incómoda."),
             "d": [("romper algo literalmente", "✗ Es figurativo, no literal."), ("hacer frío", "✗ No tiene relación con temperatura."), ("terminar una relación", "✗ Eso sería 'break up'.")]},
            {"type": "shadowing", "text": "He told a joke to break the ice at the beginning of the meeting.",
             "tip": "'Break the ice' es una frase hecha. Enfatiza 'break'."},
            {"type": "matching", "pairs": [("break the ice", "romper el hielo"), ("piece of cake", "muy fácil"), ("hit the nail on the head", "dar en el clavo"), ("let the cat out of the bag", "revelar un secreto"), ("under the weather", "enfermo/indispuesto")]},
            {"type": "multiple_choice", "q": "Si algo es 'a piece of cake', significa que es:",
             "c": ("muy fácil", "✓ 'Piece of cake' significa algo muy sencillo."),
             "d": [("delicioso", "✗ No se refiere al sabor literal."), ("caro", "✗ No tiene relación con precio."), ("rápido", "✗ Se refiere a facilidad, no velocidad.")]},
            {"type": "shadowing", "text": "The exam was a piece of cake; I finished it in twenty minutes.",
             "tip": "'Piece of cake' se dice completo. Acento en 'cake'."},
            {"type": "matching", "pairs": [("cost an arm and a leg", "costar muy caro"), ("the ball is in your court", "es tu turno/decisión"), ("bite off more than you can chew", "abarcar más de lo que puedes"), ("burn the midnight oil", "trabajar hasta tarde"), ("spill the beans", "revelar información")]},
            {"type": "fill_blank", "gap": "You really ___ the nail on the head with that comment. (dar en el clavo)",
             "ans": "hit", "alt": [("hit on", "'Hit on' es coquetear, no dar en el clavo."), ("kicked", "'Kicked' no forma parte de esta expresión.")]},
            {"type": "shadowing", "text": "She hit the nail on the head when she identified the problem.",
             "tip": "Pronuncia 'nail' /neɪl/ claramente. Acento en 'hit'."},
            {"type": "fill_blank", "gap": "Don't ___ the cat out of the bag about the surprise party. (revelar el secreto)",
             "ans": "let", "alt": [("take", "'Take the cat' no es la expresión."), ("put", "'Put' no forma parte de este idiom.")]},
        ]
        seed_lesson("idioms_b2", 20, "Expresiones Idiomáticas",
                    "Aprende expresiones idiomáticas comunes para sonar más natural en inglés.", ex2)
        self.stdout.write(self.style.SUCCESS("  ✓ 9 ejercicios creados"))
        
        # ========== LECCIÓN 3: VOZ PASIVA Y ESTILO FORMAL ==========
        self.stdout.write("\n[3/3] Creando: Voz Pasiva y Estilo Formal...")
        ex3 = [
            {"type": "multiple_choice", "q": "Convierte a voz pasiva: 'The chef prepares the meal.'",
             "c": ("The meal is prepared by the chef.", "✓ Estructura pasiva correcta: objeto + be + participio."),
             "d": [("The meal prepares by the chef.", "✗ Falta el verbo 'be' (is)."), ("The chef is prepared the meal.", "✗ El sujeto está al revés."), ("The meal prepared by the chef.", "✗ Falta el auxiliar 'is'.")]},
            {"type": "shadowing", "text": "The report was written by the manager last week.",
             "tip": "Estructura: sujeto + was/were + participio + by + agente."},
            {"type": "matching", "pairs": [("is written", "es escrito/a"), ("was built", "fue construido/a"), ("has been sent", "ha sido enviado/a"), ("will be finished", "será terminado/a"), ("is being prepared", "está siendo preparado/a")]},
            {"type": "multiple_choice", "q": "¿Cuál es más formal: 'They are building a new bridge' o 'A new bridge is being built'?",
             "c": ("A new bridge is being built", "✓ La voz pasiva es más formal y objetiva."),
             "d": [("They are building a new bridge", "✗ Voz activa es menos formal."), ("Both are equally formal", "✗ La pasiva es más formal."), ("None is formal", "✗ La pasiva sí lo es.")]},
            {"type": "shadowing", "text": "The decision will be made by the committee next month.",
             "tip": "Futuro pasivo: will be + participio. Acento en 'made'."},
            {"type": "matching", "pairs": [("It is believed that", "Se cree que"), ("It is said that", "Se dice que"), ("It is reported that", "Se reporta que"), ("It is considered that", "Se considera que"), ("It is known that", "Se sabe que")]},
            {"type": "fill_blank", "gap": "The package ___ ___ yesterday. (entregar)",
             "ans": "was delivered", "alt": [("delivered", "Falta el auxiliar 'was'."), ("is delivered", "El tiempo verbal debe ser pasado: 'was'.")]},
            {"type": "shadowing", "text": "It is widely believed that education improves quality of life.",
             "tip": "'It is believed' es estructura impersonal formal. Acento en 'believed'."},
            {"type": "fill_blank", "gap": "The new policy will ___ ___ next year. (implementar)",
             "ans": "be implemented", "alt": [("implement", "Falta 'be' para formar la pasiva."), ("been implemented", "'Been' se usa con 'has/have', no con 'will'.")]},
        ]
        seed_lesson("passive_formal_b2", 30, "Voz Pasiva y Estilo Formal",
                    "Domina la voz pasiva y estructuras formales para escritura académica y profesional.", ex3)
        self.stdout.write(self.style.SUCCESS("  ✓ 9 ejercicios creados"))
        
        self.stdout.write("\n" + "=" * 70)
        self.stdout.write(self.style.SUCCESS("✓ NIVEL B2 COMPLETO - 3 LECCIONES"))
        self.stdout.write("=" * 70 + "\n")
