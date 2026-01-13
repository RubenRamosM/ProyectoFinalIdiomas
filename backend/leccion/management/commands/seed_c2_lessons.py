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
        question=q, instructions="Demuestra dominio nativo seleccionando la opción más matizada."
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
        question="Completa con precisión léxica absoluta: " + gap,
        instructions="Demuestra dominio total del vocabulario."
    )
    ExerciseOption.objects.create(
        exercise_localization=loc, text=ans, is_correct=True,
        feedback="✓ Perfecto. '{}' refleja dominio de nivel nativo.".format(ans)
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
        question="Pronuncia con fluidez, entonación y matices nativos: \"{}\"".format(text),
        instructions="Demuestra dominio prosódico completo. " + tip,
        expected_audio_text=text
    )

def create_match(ex, pairs):
    shuffled = pairs.copy()
    random.shuffle(shuffled)
    loc = ExerciseLocalization.objects.create(
        exercise=ex, native_language=Language.objects.get(code="es"),
        target_language=Language.objects.get(code="en"),
        question="Empareja expresiones idiomáticas avanzadas con sus significados precisos:",
        instructions="Demuestra conocimiento idiomático nativo.",
        matching_pairs=[{"target": t, "native": n} for t, n in shuffled]
    )
    ExerciseOption.objects.create(
        exercise_localization=loc, text="fb", is_correct=True,
        feedback="✓ Dominio magistral de expresiones idiomáticas complejas."
    )

@transaction.atomic
def seed_lesson(tk, seq, title, content, exs):
    lesson, _ = Lesson.objects.get_or_create(
        title_key=tk, level="C2", lesson_type="vocabulary",
        defaults={"sequence": seq, "difficulty": 5, "is_active": True}
    )
    LessonLocalization.objects.get_or_create(
        lesson=lesson, native_language=Language.objects.get(code="es"),
        target_language=Language.objects.get(code="en"),
        defaults={"title": title, "content": content, "resources": {"cefr": "C2"}}
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
    help = "Crea 3 lecciones para nivel C2 (maestría)"

    def handle(self, *args, **options):
        self.stdout.write(self.style.MIGRATE_HEADING("=" * 70))
        self.stdout.write(self.style.MIGRATE_HEADING("POBLANDO NIVEL C2 - 3 LECCIONES (MAESTRÍA)"))
        self.stdout.write(self.style.MIGRATE_HEADING("=" * 70))
        
        ensure_languages()
        
        # ========== LECCIÓN 1: VOCABULARIO ESPECIALIZADO Y TECNICISMOS ==========
        self.stdout.write("\n[1/3] Creando: Vocabulario Especializado y Tecnicismos...")
        ex1 = [
            {"type": "multiple_choice", "q": "En filosofía, ¿qué término describe la existencia independiente de conceptos abstractos?",
             "c": ("Reification", "✓ 'Reification' es tratar abstracciones como si fueran concretas."),
             "d": [("Abstraction", "✗ 'Abstraction' es el proceso opuesto."), ("Concretization", "✗ No es el término filosófico correcto."), ("Materialization", "✗ Es demasiado literal.")]},
            {"type": "shadowing", "text": "The reification of theoretical constructs can obscure their inherent complexity.",
             "tip": "'Reification' /ˌriɪfɪˈkeɪʃən/ con cuatro sílabas. Acento en 'ca'."},
            {"type": "matching", "pairs": [("Reification", "Reificación/cosificación"), ("Epistemology", "Epistemología"), ("Ontology", "Ontología"), ("Paradigm", "Paradigma"), ("Hermeneutics", "Hermenéutica")]},
            {"type": "multiple_choice", "q": "¿Qué término lingüístico describe palabras que suenan igual pero significan diferente?",
             "c": ("Homonyms", "✓ 'Homonyms' son palabras con igual pronunciación, distinto significado."),
             "d": [("Synonyms", "✗ 'Synonyms' son palabras con significado similar."), ("Antonyms", "✗ 'Antonyms' son opuestos."), ("Acronyms", "✗ 'Acronyms' son abreviaciones.")]},
            {"type": "shadowing", "text": "Homonyms can create ambiguity in spoken discourse but are disambiguated by context.",
             "tip": "'Homonyms' /ˈhɑməˌnɪmz/ y 'disambiguated' /dɪsæmˈbɪɡjuˌeɪtɪd/ son técnicos."},
            {"type": "matching", "pairs": [("Homonyms", "Homónimos"), ("Polysemy", "Polisemia"), ("Semantic field", "Campo semántico"), ("Pragmatics", "Pragmática"), ("Syntax", "Sintaxis")]},
            {"type": "fill_blank", "gap": "The study employs a rigorous ___ approach to data analysis. (metodológico estricto)",
             "ans": "methodological", "alt": [("methodical", "'Methodical' es menos formal que 'methodological'."), ("systematic", "'Systematic' es correcto pero menos técnico.")]},
            {"type": "shadowing", "text": "A methodological framework is essential for ensuring research validity and reliability.",
             "tip": "'Methodological' /ˌmɛθədəˈlɑdʒɪkəl/ tiene seis sílabas. Acento en 'log'."},
            {"type": "fill_blank", "gap": "The findings remain ___ despite peer review. (controvertido/disputado)",
             "ans": "contentious", "alt": [("controversial", "'Controversial' es menos formal que 'contentious'."), ("debatable", "'Debatable' es más débil que 'contentious'.")]},
        ]
        seed_lesson("specialized_vocab_c2", 10, "Vocabulario Especializado y Tecnicismos",
                    "Domina terminología especializada de campos académicos y técnicos avanzados.", ex1)
        self.stdout.write(self.style.SUCCESS("  ✓ 9 ejercicios creados"))
        
        # ========== LECCIÓN 2: EXPRESIONES LITERARIAS Y FIGURAS RETÓRICAS ==========
        self.stdout.write("\n[2/3] Creando: Expresiones Literarias y Figuras Retóricas...")
        ex2 = [
            {"type": "multiple_choice", "q": "¿Qué figura retórica es 'The world is a stage'?",
             "c": ("Metaphor", "✓ Es una metáfora que equipara directamente dos conceptos sin 'like'/'as'."),
             "d": [("Simile", "✗ 'Simile' usa 'like' o 'as' explícitamente."), ("Personification", "✗ 'Personification' da cualidades humanas a objetos."), ("Hyperbole", "✗ 'Hyperbole' es exageración.")]},
            {"type": "shadowing", "text": "Shakespeare's metaphor 'All the world's a stage' remains timelessly evocative.",
             "tip": "'Metaphor' /ˈmɛtəˌfɔr/ y 'evocative' /ɪˈvɑkətɪv/ con acento correcto."},
            {"type": "matching", "pairs": [("Metaphor", "Metáfora"), ("Simile", "Símil"), ("Personification", "Personificación"), ("Hyperbole", "Hipérbole"), ("Irony", "Ironía")]},
            {"type": "multiple_choice", "q": "Identifica la ironía: 'The fire station burned down' es un ejemplo de:",
             "c": ("Situational irony", "✓ Ironía situacional: lo opuesto de lo esperado ocurre."),
             "d": [("Verbal irony", "✗ Ironía verbal es decir lo opuesto de lo que se piensa."), ("Dramatic irony", "✗ Ironía dramática es cuando la audiencia sabe algo que los personajes no."), ("Sarcasm", "✗ 'Sarcasm' es burla, no ironía situacional.")]},
            {"type": "shadowing", "text": "The situational irony of the fire station burning down underscores life's unpredictability.",
             "tip": "'Situational' /ˌsɪʧuˈeɪʃənəl/ y 'unpredictability' /ˌʌnprɪˌdɪktəˈbɪləti/ son largas."},
            {"type": "matching", "pairs": [("Situational irony", "Ironía situacional"), ("Verbal irony", "Ironía verbal"), ("Dramatic irony", "Ironía dramática"), ("Oxymoron", "Oxímoron"), ("Paradox", "Paradoja")]},
            {"type": "fill_blank", "gap": "The poem employs vivid ___ to evoke sensory experiences. (imágenes sensoriales)",
             "ans": "imagery", "alt": [("images", "'Images' es demasiado literal para contexto literario."), ("pictures", "'Pictures' no es el término técnico literario.")]},
            {"type": "shadowing", "text": "Rich imagery and meticulous diction distinguish masterful literary compositions.",
             "tip": "'Imagery' /ˈɪmɪdʒri/ y 'meticulous' /məˈtɪkjələs/ con pronunciación precisa."},
            {"type": "fill_blank", "gap": "The author's prose exhibits remarkable ___ and precision. (economía de lenguaje)",
             "ans": "concision", "alt": [("brevity", "'Brevity' es correcto pero 'concision' es más técnico."), ("shortness", "'Shortness' es demasiado simple para análisis literario.")]},
        ]
        seed_lesson("literary_rhetoric_c2", 20, "Expresiones Literarias y Figuras Retóricas",
                    "Analiza y emplea figuras retóricas y recursos literarios con maestría crítica.", ex2)
        self.stdout.write(self.style.SUCCESS("  ✓ 9 ejercicios creados"))
        
        # ========== LECCIÓN 3: SUTILEZAS PRAGMÁTICAS Y COMUNICACIÓN IMPLÍCITA ==========
        self.stdout.write("\n[3/3] Creando: Sutilezas Pragmáticas y Comunicación Implícita...")
        ex3 = [
            {"type": "multiple_choice", "q": "Si alguien dice 'It's getting late' en una fiesta, probablemente está:",
             "c": ("Suggesting they want to leave", "✓ Es una sugerencia indirecta (implicatura conversacional)."),
             "d": [("Stating a fact only", "✗ Hay intención comunicativa implícita."), ("Asking for the time", "✗ No es una pregunta directa."), ("Complaining about tiredness", "✗ No necesariamente, es más sutil.")]},
            {"type": "shadowing", "text": "Pragmatic competence involves interpreting implicit meaning beyond literal semantics.",
             "tip": "'Pragmatic' /præɡˈmætɪk/ y 'semantics' /səˈmæntɪks/ con acento correcto."},
            {"type": "matching", "pairs": [("Implicature", "Implicatura"), ("Presupposition", "Presuposición"), ("Inference", "Inferencia"), ("Context", "Contexto"), ("Speech act", "Acto de habla")]},
            {"type": "multiple_choice", "q": "'With all due respect...' generalmente precede a:",
             "c": ("Disagreement or criticism", "✓ Es atenuador (hedge) que señala desacuerdo cortés."),
             "d": [("Agreement", "✗ No se usa para estar de acuerdo."), ("Neutral statement", "✗ Implica tensión o desacuerdo."), ("Praise", "✗ No precede elogios.")]},
            {"type": "shadowing", "text": "With all due respect, I must respectfully disagree with your conclusion.",
             "tip": "Entonación descendente en 'respect' señala cortesía formal pero firme."},
            {"type": "matching", "pairs": [("With all due respect", "Con el debido respeto"), ("If I may say so", "Si me permite decirlo"), ("To be frank", "Siendo franco"), ("In all honesty", "Con toda honestidad"), ("I'm afraid that", "Me temo que")]},
            {"type": "fill_blank", "gap": "The speaker's tone ___ the gravity of the situation. (transmitir/señalar)",
             "ans": "conveyed", "alt": [("showed", "'Showed' es menos formal que 'conveyed'."), ("told", "'Told' no funciona bien con 'tone' como sujeto.")]},
            {"type": "shadowing", "text": "Her tone conveyed subtle disapproval despite her ostensibly neutral words.",
             "tip": "'Conveyed' /kənˈveɪd/ y 'ostensibly' /ɑˈstɛnsəbli/ son claves."},
            {"type": "fill_blank", "gap": "The statement ___ a familiarity with contemporary discourse. (suponer/presuponer)",
             "ans": "presupposes", "alt": [("assumes", "'Assumes' es menos técnico que 'presupposes'."), ("thinks", "'Thinks' no es apropiado para análisis discursivo.")]},
        ]
        seed_lesson("pragmatic_subtleties_c2", 30, "Sutilezas Pragmáticas y Comunicación Implícita",
                    "Domina implicaturas, atenuadores y la interpretación de significados implícitos en contexto.", ex3)
        self.stdout.write(self.style.SUCCESS("  ✓ 9 ejercicios creados"))
        
        self.stdout.write("\n" + "=" * 70)
        self.stdout.write(self.style.SUCCESS("✓ NIVEL C2 COMPLETO - 3 LECCIONES"))
        self.stdout.write(self.style.SUCCESS("✓ TODOS LOS NIVELES DEL MCER POBLADOS (A1-C2)"))
        self.stdout.write("=" * 70)
        self.stdout.write("\nResumen completo de lecciones:")
        self.stdout.write("  • A1: 3 lecciones (Saludos, Números, Colores)")
        self.stdout.write("  • A2: 3 lecciones (Familia, Comida, Casa)")
        self.stdout.write("  • B1: 3 lecciones (Pasados, Presente Perfecto, Condicionales)")
        self.stdout.write("  • B2: 3 lecciones (Phrasal Verbs, Idioms, Voz Pasiva)")
        self.stdout.write("  • C1: 3 lecciones (Estructuras Complejas, Vocabulario Académico, Matices)")
        self.stdout.write("  • C2: 3 lecciones (Tecnicismos, Retórica, Pragmática)")
        self.stdout.write("\n" + "=" * 70 + "\n")
