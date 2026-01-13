import random
from django.core.management.base import BaseCommand
from django.db import transaction
from core.models import Language
from leccion.models import Lesson, LessonLocalization, Exercise, ExerciseLocalization, ExerciseOption

def ensure_languages():
    for code, name in {"es": "Español", "en": "English"}.items():
        Language.objects.get_or_create(code=code, defaults={"name": name})

def create_mc(ex, q, correct, dist):
    loc = ExerciseLocalization.objects.create(
        exercise=ex, native_language=Language.objects.get(code="es"),
        target_language=Language.objects.get(code="en"),
        question=q, instructions="Selecciona la respuesta correcta."
    )
    opts = [{"text": correct[0], "correct": True, "feedback": correct[1]}]
    opts.extend([{"text": d[0], "correct": False, "feedback": d[1]} for d in dist])
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
        question="Completa: " + gap, instructions="Escribe la palabra correcta."
    )
    ExerciseOption.objects.create(
        exercise_localization=loc, text=ans, is_correct=True,
        feedback="✓ Correcto. '{}' es adecuado aquí.".format(ans)
    )
    for a in alt:
        ExerciseOption.objects.create(
            exercise_localization=loc, text=a[0], is_correct=False, feedback="✗ " + a[1]
        )

def create_pron(ex, text, tip):
    ExerciseLocalization.objects.create(
        exercise=ex, native_language=Language.objects.get(code="es"),
        target_language=Language.objects.get(code="en"),
        question="Pronuncia: \"{}\"".format(text),
        instructions="Lee en voz alta. " + tip, expected_audio_text=text
    )

def create_match(ex, pairs):
    shuffled = pairs.copy()
    random.shuffle(shuffled)
    loc = ExerciseLocalization.objects.create(
        exercise=ex, native_language=Language.objects.get(code="es"),
        target_language=Language.objects.get(code="en"),
        question="Empareja cada expresión con su traducción:",
        instructions="Arrastra para emparejar.",
        matching_pairs=[{"target": t, "native": n} for t, n in shuffled]
    )
    ExerciseOption.objects.create(
        exercise_localization=loc, text="fb", is_correct=True,
        feedback="✓ Excelente trabajo con este vocabulario."
    )

@transaction.atomic
def seed_lesson(tk, seq, title, content, exs):
    lesson, _ = Lesson.objects.get_or_create(
        title_key=tk, level="B1", lesson_type="grammar",
        defaults={"sequence": seq, "difficulty": 3, "is_active": True}
    )
    LessonLocalization.objects.get_or_create(
        lesson=lesson, native_language=Language.objects.get(code="es"),
        target_language=Language.objects.get(code="en"),
        defaults={"title": title, "content": content, "resources": {"cefr": "B1"}}
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
    help = "Crea 3 lecciones para nivel B1"

    def handle(self, *args, **options):
        self.stdout.write(self.style.MIGRATE_HEADING("=" * 70))
        self.stdout.write(self.style.MIGRATE_HEADING("POBLANDO NIVEL B1 - 3 LECCIONES"))
        self.stdout.write(self.style.MIGRATE_HEADING("=" * 70))
        
        ensure_languages()
        
        # ========== LECCIÓN 1: TIEMPOS VERBALES PASADOS ==========
        self.stdout.write("\n[1/3] Creando: Tiempos Verbales Pasados...")
        ex1 = [
            {"type": "multiple_choice", "q": "¿Cuál es el pasado simple de 'go'?",
             "c": ("went", "✓ 'Went' es el pasado irregular de 'go'."),
             "d": [("goed", "✗ No existe 'goed'. El pasado es 'went'."), ("gone", "✗ 'Gone' es participio pasado, no pasado simple."), ("going", "✗ 'Going' es gerundio, no pasado.")]},
            {"type": "shadowing", "text": "I went to the store yesterday and bought some milk.",
             "tip": "Conecta 'went to' como una unidad. 'Bought' se pronuncia /bɔːt/."},
            {"type": "matching", "pairs": [("go → went", "ir → fui"), ("buy → bought", "comprar → compré"), ("see → saw", "ver → vi"), ("eat → ate", "comer → comí"), ("drink → drank", "beber → bebí")]},
            {"type": "multiple_choice", "q": "Completa: She ___ a movie last night.",
             "c": ("watched", "✓ 'Watched' es pasado regular de 'watch'."),
             "d": [("watch", "✗ Falta la terminación -ed para pasado."), ("watching", "✗ Es gerundio, no pasado simple."), ("watches", "✗ Es presente tercera persona.")]},
            {"type": "shadowing", "text": "They studied English for three hours last Monday.",
             "tip": "Pronuncia 'studied' /ˈstʌdid/ con dos sílabas."},
            {"type": "matching", "pairs": [("work → worked", "trabajar → trabajé"), ("play → played", "jugar → jugué"), ("watch → watched", "ver → vi"), ("study → studied", "estudiar → estudié"), ("clean → cleaned", "limpiar → limpié")]},
            {"type": "fill_blank", "gap": "We ___ to Paris last summer. (ir)",
             "ans": "went", "alt": [("go", "Necesitas pasado: 'went'."), ("gone", "'Gone' es participio, no pasado simple.")]},
            {"type": "shadowing", "text": "Last year, I visited five different countries.",
             "tip": "'Visited' termina en /ɪd/. 'Countries' /ˈkʌntriz/."},
            {"type": "fill_blank", "gap": "He ___ his homework before dinner. (hacer)",
             "ans": "did", "alt": [("do", "Necesitas pasado: 'did'."), ("done", "'Done' es participio.")]}
        ]
        seed_lesson("past_tenses_b1", 10, "Tiempos Verbales Pasados",
                    "Domina el pasado simple de verbos regulares e irregulares en inglés.", ex1)
        self.stdout.write(self.style.SUCCESS("  ✓ 9 ejercicios creados"))
        
        # ========== LECCIÓN 2: PRESENTE PERFECTO ==========
        self.stdout.write("\n[2/3] Creando: Presente Perfecto...")
        ex2 = [
            {"type": "multiple_choice", "q": "¿Cuál oración usa presente perfecto correctamente?",
             "c": ("I have lived here for five years.", "✓ 'Have lived' es presente perfecto con duración."),
             "d": [("I live here for five years.", "✗ Falta el auxiliar 'have'."), ("I lived here for five years.", "✗ Esto es pasado simple, no presente perfecto."), ("I am living here for five years.", "✗ Presente continuo, no perfecto.")]},
            {"type": "shadowing", "text": "She has worked at this company since 2015.",
             "tip": "Conecta 'has worked' fluidamente. 'Since' indica punto de inicio."},
            {"type": "matching", "pairs": [("I have seen", "He visto"), ("You have been", "Has estado"), ("He has done", "Él ha hecho"), ("We have eaten", "Hemos comido"), ("They have gone", "Ellos han ido")]},
            {"type": "multiple_choice", "q": "¿Qué palabra indica presente perfecto: 'already', 'yesterday', o 'last week'?",
             "c": ("already", "✓ 'Already' se usa con presente perfecto."),
             "d": [("yesterday", "✗ 'Yesterday' requiere pasado simple."), ("last week", "✗ 'Last week' requiere pasado simple."), ("tomorrow", "✗ 'Tomorrow' es futuro.")]},
            {"type": "shadowing", "text": "Have you ever been to London?",
             "tip": "'Ever' enfatiza experiencia. 'Been' /biːn/ se pronuncia claramente."},
            {"type": "matching", "pairs": [("already", "ya"), ("yet", "todavía/aún"), ("just", "justo/acabar de"), ("ever", "alguna vez"), ("never", "nunca")]},
            {"type": "fill_blank", "gap": "I ___ never ___ sushi before. (comer)",
             "ans": "have eaten", "alt": [("eat", "Necesitas presente perfecto: 'have eaten'."), ("ate", "Pasado simple no funciona con 'never' en este contexto.")]},
            {"type": "shadowing", "text": "They have just finished their homework.",
             "tip": "'Just' indica acción reciente. 'Finished' /ˈfɪnɪʃt/."},
            {"type": "fill_blank", "gap": "She ___ already ___ the report. (escribir)",
             "ans": "has written", "alt": [("write", "Necesitas 'has written'."), ("wrote", "Pasado simple, pero aquí es presente perfecto.")]}
        ]
        seed_lesson("present_perfect_b1", 20, "Presente Perfecto",
                    "Aprende a usar el presente perfecto para experiencias y acciones con relevancia actual.", ex2)
        self.stdout.write(self.style.SUCCESS("  ✓ 9 ejercicios creados"))
        
        # ========== LECCIÓN 3: CONDICIONALES (TIPO 1 Y 2) ==========
        self.stdout.write("\n[3/3] Creando: Condicionales...")
        ex3 = [
            {"type": "multiple_choice", "q": "Completa la condicional tipo 1: If it rains, I ___ stay home.",
             "c": ("will", "✓ Condicional tipo 1: If + presente, ... will + verbo."),
             "d": [("would", "✗ 'Would' es para condicional tipo 2."), ("can", "✗ Aunque posible, 'will' es más apropiado aquí."), ("must", "✗ Cambia el significado a obligación.")]},
            {"type": "shadowing", "text": "If you study hard, you will pass the exam.",
             "tip": "Primera parte presente ('study'), segunda futuro ('will pass')."},
            {"type": "matching", "pairs": [("If I have time", "Si tengo tiempo"), ("I will call you", "Te llamaré"), ("If it rains", "Si llueve"), ("We will cancel", "Cancelaremos"), ("If you come", "Si vienes")]},
            {"type": "multiple_choice", "q": "Completa la condicional tipo 2: If I ___ rich, I would travel the world.",
             "c": ("were", "✓ Condicional tipo 2: If + pasado simple, ... would + verbo."),
             "d": [("am", "✗ Necesitas pasado: 'were' o 'was'."), ("will be", "✗ Es futuro, no condicional tipo 2."), ("have been", "✗ Es presente perfecto.")]},
            {"type": "shadowing", "text": "If I had more money, I would buy a new car.",
             "tip": "'Had' en condicional tipo 2. 'Would buy' es el resultado hipotético."},
            {"type": "matching", "pairs": [("If I were you", "Si yo fuera tú"), ("I would accept", "Yo aceptaría"), ("If he knew", "Si él supiera"), ("He would help", "Él ayudaría"), ("If we could", "Si pudiéramos")]},
            {"type": "fill_blank", "gap": "If she ___ here, she would help us. (estar)",
             "ans": "were", "alt": [("is", "Necesitas pasado: 'were'."), ("will be", "Es futuro, no condicional tipo 2.")]},
            {"type": "shadowing", "text": "If they invited me, I would go to the party.",
             "tip": "'Invited' es pasado. 'Would go' es el resultado condicional."},
            {"type": "fill_blank", "gap": "If you ___ early, you will catch the bus. (salir)",
             "ans": "leave", "alt": [("left", "Tipo 1 usa presente, no pasado."), ("will leave", "No uses 'will' en la cláusula 'if'.")]}
        ]
        seed_lesson("conditionals_b1", 30, "Condicionales (Tipo 1 y 2)",
                    "Domina las estructuras condicionales para expresar posibilidades reales e hipotéticas.", ex3)
        self.stdout.write(self.style.SUCCESS("  ✓ 9 ejercicios creados"))
        
        self.stdout.write("\n" + "=" * 70)
        self.stdout.write(self.style.SUCCESS("✓ NIVEL B1 COMPLETO - 3 LECCIONES"))
        self.stdout.write("=" * 70 + "\n")
