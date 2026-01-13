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
        question=q, instructions="Selecciona la opción más precisa y sofisticada."
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
        question="Completa con el término más apropiado: " + gap,
        instructions="Usa vocabulario avanzado."
    )
    ExerciseOption.objects.create(
        exercise_localization=loc, text=ans, is_correct=True,
        feedback="✓ Excelente. '{}' es el término más preciso.".format(ans)
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
        question="Pronuncia con fluidez y entonación natural: \"{}\"".format(text),
        instructions="Mantén ritmo y entonación nativos. " + tip,
        expected_audio_text=text
    )

def create_match(ex, pairs):
    shuffled = pairs.copy()
    random.shuffle(shuffled)
    loc = ExerciseLocalization.objects.create(
        exercise=ex, native_language=Language.objects.get(code="es"),
        target_language=Language.objects.get(code="en"),
        question="Empareja términos académicos con sus definiciones:",
        instructions="Arrastra para conectar correctamente.",
        matching_pairs=[{"target": t, "native": n} for t, n in shuffled]
    )
    ExerciseOption.objects.create(
        exercise_localization=loc, text="fb", is_correct=True,
        feedback="✓ Excelente dominio del vocabulario académico avanzado."
    )

@transaction.atomic
def seed_lesson(tk, seq, title, content, exs):
    lesson, _ = Lesson.objects.get_or_create(
        title_key=tk, level="C1", lesson_type="grammar",
        defaults={"sequence": seq, "difficulty": 5, "is_active": True}
    )
    LessonLocalization.objects.get_or_create(
        lesson=lesson, native_language=Language.objects.get(code="es"),
        target_language=Language.objects.get(code="en"),
        defaults={"title": title, "content": content, "resources": {"cefr": "C1"}}
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
    help = "Crea 3 lecciones para nivel C1"

    def handle(self, *args, **options):
        self.stdout.write(self.style.MIGRATE_HEADING("=" * 70))
        self.stdout.write(self.style.MIGRATE_HEADING("POBLANDO NIVEL C1 - 3 LECCIONES"))
        self.stdout.write(self.style.MIGRATE_HEADING("=" * 70))
        
        ensure_languages()
        
        # ========== LECCIÓN 1: ESTRUCTURAS COMPLEJAS Y SUBORDINADAS ==========
        self.stdout.write("\n[1/3] Creando: Estructuras Complejas y Subordinadas...")
        ex1 = [
            {"type": "multiple_choice", "q": "Elige la estructura más sofisticada: 'If I had known, I would have helped' vs 'If I knew, I would help'.",
             "c": ("If I had known, I would have helped", "✓ Condicional tipo 3 (pasado irreal) es más complejo y preciso."),
             "d": [("If I knew, I would help", "✗ Condicional tipo 2 es más simple."), ("Both are equally complex", "✗ El tipo 3 es más avanzado."), ("Neither is complex", "✗ Ambas son estructuras condicionales complejas.")]},
            {"type": "shadowing", "text": "Had I known about the issue, I would have addressed it immediately.",
             "tip": "Inversión sin 'if': 'Had I known' = 'If I had known'. Muy formal."},
            {"type": "matching", "pairs": [("Had I known", "Si hubiera sabido"), ("Were it not for", "Si no fuera por"), ("Should you need", "Si necesitaras"), ("Had they arrived earlier", "Si hubieran llegado antes"), ("Were I in your position", "Si estuviera en tu posición")]},
            {"type": "multiple_choice", "q": "Completa formalmente: '_____ the circumstances, we will proceed as planned.'",
             "c": ("Notwithstanding", "✓ 'Notwithstanding' es formal y significa 'a pesar de'."),
             "d": [("Despite of", "✗ 'Despite' no lleva 'of' después."), ("Although", "✗ 'Although' necesita una cláusula completa."), ("However", "✗ 'However' no conecta sustantivos directamente.")]},
            {"type": "shadowing", "text": "Notwithstanding the delays, the project was completed successfully.",
             "tip": "'Notwithstanding' /ˌnɑtwɪθˈstændɪŋ/ es muy formal. Acento en 'stand'."},
            {"type": "matching", "pairs": [("Notwithstanding", "A pesar de"), ("Henceforth", "De aquí en adelante"), ("Whereby", "Por el cual/mediante el cual"), ("Pursuant to", "De conformidad con"), ("Albeit", "Aunque")]},
            {"type": "fill_blank", "gap": "The data suggests that, ___ the initial hypothesis, the results are inconclusive. (contrario a)",
             "ans": "contrary to", "alt": [("despite of", "'Despite' no usa 'of'."), ("although", "'Although' necesita verbo después.")]},
            {"type": "shadowing", "text": "Contrary to popular belief, the study reveals significant discrepancies.",
             "tip": "'Contrary to' /ˈkɑntrɛri tu/ se conecta fluidamente."},
            {"type": "fill_blank", "gap": "The policy, ___ well-intentioned, failed to address the core issues. (aunque)",
             "ans": "albeit", "alt": [("despite", "'Despite' necesita sustantivo, no adjetivo directo."), ("however", "'However' no se usa así en medio de oración.")]},
        ]
        seed_lesson("complex_structures_c1", 10, "Estructuras Complejas y Subordinadas",
                    "Domina estructuras gramaticales avanzadas, inversiones y conectores formales de nivel C1.", ex1)
        self.stdout.write(self.style.SUCCESS("  ✓ 9 ejercicios creados"))
        
        # ========== LECCIÓN 2: VOCABULARIO ACADÉMICO Y COLOCACIONES ==========
        self.stdout.write("\n[2/3] Creando: Vocabulario Académico y Colocaciones...")
        ex2 = [
            {"type": "multiple_choice", "q": "¿Qué colocación es correcta con 'research'?",
             "c": ("conduct research", "✓ 'Conduct research' es la colocación estándar en académico."),
             "d": [("make research", "✗ No se usa 'make' con 'research'."), ("do research", "✗ Informal. En académico se prefiere 'conduct'."), ("create research", "✗ 'Create' no coloca con 'research'.")]},
            {"type": "shadowing", "text": "The researchers conducted extensive research on climate change mitigation strategies.",
             "tip": "'Conducted' /kənˈdʌktɪd/ conecta con 'research'. Acento en 'duct'."},
            {"type": "matching", "pairs": [("conduct research", "realizar investigación"), ("draw conclusions", "sacar conclusiones"), ("raise awareness", "crear conciencia"), ("pose a question", "plantear una pregunta"), ("yield results", "arrojar resultados")]},
            {"type": "multiple_choice", "q": "Completa: The findings ___ significant implications for future policy.",
             "c": ("have", "✓ 'Have implications' es la colocación correcta."),
             "d": [("make", "✗ 'Make implications' no es correcto."), ("give", "✗ 'Give implications' no es estándar."), ("do", "✗ 'Do implications' no existe.")]},
            {"type": "shadowing", "text": "These results have far-reaching implications for educational policy reform.",
             "tip": "'Far-reaching' /fɑr ˈriʧɪŋ/ es compuesto. Acento en 'reach'."},
            {"type": "matching", "pairs": [("have implications", "tener implicaciones"), ("meet criteria", "cumplir criterios"), ("reach consensus", "alcanzar consenso"), ("hold significance", "tener importancia"), ("bear resemblance", "tener semejanza")]},
            {"type": "fill_blank", "gap": "The study aims to ___ light on the underlying mechanisms. (arrojar/echar)",
             "ans": "shed", "alt": [("throw", "'Throw light' es menos formal que 'shed light'."), ("give", "'Give light' no es la colocación correcta.")]},
            {"type": "shadowing", "text": "This research sheds light on previously unexplored aspects of the phenomenon.",
             "tip": "'Sheds light' /ʃɛdz laɪt/ es expresión fija. Acento en 'sheds'."},
            {"type": "fill_blank", "gap": "The committee will ___ a decision by the end of the month. (tomar/alcanzar)",
             "ans": "reach", "alt": [("take", "'Take a decision' es menos formal que 'reach'."), ("make", "'Make a decision' es correcto pero 'reach' es más formal.")]},
        ]
        seed_lesson("academic_vocab_c1", 20, "Vocabulario Académico y Colocaciones",
                    "Domina colocaciones académicas y vocabulario especializado para escritura y presentaciones formales.", ex2)
        self.stdout.write(self.style.SUCCESS("  ✓ 9 ejercicios creados"))
        
        # ========== LECCIÓN 3: MATICES SEMÁNTICOS Y REGISTRO ==========
        self.stdout.write("\n[3/3] Creando: Matices Semánticos y Registro...")
        ex3 = [
            {"type": "multiple_choice", "q": "Diferencia: 'childish' vs 'childlike'. ¿Cuál es positivo?",
             "c": ("childlike", "✓ 'Childlike' es positivo (inocencia, maravilla). 'Childish' es negativo (inmaduro)."),
             "d": [("childish", "✗ 'Childish' implica inmadurez, no es positivo."), ("Both are positive", "✗ Solo 'childlike' es positivo."), ("Neither is positive", "✗ 'Childlike' sí lo es.")]},
            {"type": "shadowing", "text": "Her childlike wonder and curiosity made her an excellent scientist.",
             "tip": "'Childlike' /ˈʧaɪldlaɪk/ con acento en 'child'. Connotación positiva."},
            {"type": "matching", "pairs": [("childlike (positive)", "como niño (positivo)"), ("childish (negative)", "infantil (negativo)"), ("economic (objective)", "económico (objetivo)"), ("economical (efficient)", "económico (eficiente)"), ("historic (important)", "histórico (importante)")]},
            {"type": "multiple_choice", "q": "Elige el término más formal para 'buy': 'purchase', 'acquire', or 'procure'?",
             "c": ("procure", "✓ 'Procure' es el más formal, usado en contextos legales/oficiales."),
             "d": [("purchase", "✗ Formal, pero 'procure' es más específico y formal."), ("acquire", "✗ Formal, pero implica obtener, no necesariamente comprar."), ("buy", "✗ Es informal.")]},
            {"type": "shadowing", "text": "The institution procured specialized equipment for the research facility.",
             "tip": "'Procured' /proʊˈkjʊrd/ es muy formal. Acento en 'cure'."},
            {"type": "matching", "pairs": [("procure (very formal)", "adquirir formalmente"), ("purchase (formal)", "comprar formalmente"), ("acquire (neutral)", "adquirir"), ("obtain (neutral)", "obtener"), ("get (informal)", "conseguir")]},
            {"type": "fill_blank", "gap": "The company seeks to ___ talented individuals. (reclutar formalmente)",
             "ans": "recruit", "alt": [("hire", "'Hire' es menos formal que 'recruit'."), ("get", "'Get' es demasiado informal para contexto corporativo.")]},
            {"type": "shadowing", "text": "We actively recruit diverse candidates from various backgrounds.",
             "tip": "'Recruit' /rɪˈkrut/ enfatiza selección activa. Acento en 'cruit'."},
            {"type": "fill_blank", "gap": "The proposal was ___ by all stakeholders. (rechazar formalmente)",
             "ans": "rejected", "alt": [("refused", "'Refused' es correcto pero menos formal que 'rejected'."), ("said no", "Demasiado informal para contexto formal.")]},
        ]
        seed_lesson("semantic_nuances_c1", 30, "Matices Semánticos y Registro",
                    "Distingue sutilezas entre palabras similares y selecciona el registro apropiado según el contexto.", ex3)
        self.stdout.write(self.style.SUCCESS("  ✓ 9 ejercicios creados"))
        
        self.stdout.write("\n" + "=" * 70)
        self.stdout.write(self.style.SUCCESS("✓ NIVEL C1 COMPLETO - 3 LECCIONES"))
        self.stdout.write("=" * 70 + "\n")
