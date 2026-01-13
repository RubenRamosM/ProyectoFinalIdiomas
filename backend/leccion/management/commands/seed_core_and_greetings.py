import random
from django.core.management.base import BaseCommand
from django.db import transaction

from core.models import Language
from leccion.models import (
    Lesson, LessonLocalization,
    Exercise, ExerciseLocalization, ExerciseOption
)

# =========================
# Frases base por idioma
# =========================
PROMPTS = {
    "es": {
        "mc_how_say": "¿Cómo se dice \"{phrase}\" en {target_name}?",
        "mc_context": "En {context}, ¿qué dirías en {target_name}?",
        "mc_best_response": "¿Cuál es la mejor respuesta cuando alguien dice \"{phrase}\"?",
        "fill_complete": "Completa: {gap}",
        "pron_say_this": "Pronuncia: \"{text}\"",
        "matching_pick": "Empareja cada expresión con su traducción:",
        "instructions_mc": "Elige la respuesta correcta.",
        "instructions_fill": "Escribe la palabra que falta.",
        "instructions_pron": "Graba tu pronunciación.",
        "instructions_match": "Arrastra para emparejar.",
    },
    "pt": {
        "mc_how_say": "Como se diz \"{phrase}\" em {target_name}?",
        "mc_context": "Em {context}, o que você diria em {target_name}?",
        "mc_best_response": "Qual é a melhor resposta quando alguém diz \"{phrase}\"?",
        "fill_complete": "Complete: {gap}",
        "pron_say_this": "Pronuncie: \"{text}\"",
        "matching_pick": "Associe cada expressão à sua tradução:",
        "instructions_mc": "Escolha a resposta correta.",
        "instructions_fill": "Escreva a palavra que falta.",
        "instructions_pron": "Grave sua pronúncia.",
        "instructions_match": "Arraste para associar.",
    },
    "fr": {
        "mc_how_say": "Comment dit-on « {phrase} » en {target_name} ?",
        "mc_context": "Dans {context}, que diriez-vous en {target_name} ?",
        "mc_best_response": "Quelle est la meilleure réponse quand quelqu'un dit « {phrase} » ?",
        "fill_complete": "Complétez : {gap}",
        "pron_say_this": "Prononcez : « {text} »",
        "matching_pick": "Associez chaque expression à sa traduction :",
        "instructions_mc": "Choisissez la bonne réponse.",
        "instructions_fill": "Écrivez le mot manquant.",
        "instructions_pron": "Enregistrez votre prononciation.",
        "instructions_match": "Glissez pour associer.",
    },
    "de": {
        "mc_how_say": "Wie sagt man \"{phrase}\" auf {target_name}?",
        "mc_context": "In {context}, was würden Sie auf {target_name} sagen?",
        "mc_best_response": "Was ist die beste Antwort, wenn jemand \"{phrase}\" sagt?",
        "fill_complete": "Vervollständige: {gap}",
        "pron_say_this": "Sprich aus: \"{text}\"",
        "matching_pick": "Ordne jeden Ausdruck seiner Übersetzung zu:",
        "instructions_mc": "Wähle die richtige Antwort.",
        "instructions_fill": "Schreibe das fehlende Wort.",
        "instructions_pron": "Nimm deine Aussprache auf.",
        "instructions_match": "Ziehe zum Zuordnen.",
    },
    "it": {
        "mc_how_say": "Come si dice \"{phrase}\" in {target_name}?",
        "mc_context": "In {context}, cosa diresti in {target_name}?",
        "mc_best_response": "Qual è la risposta migliore quando qualcuno dice \"{phrase}\"?",
        "fill_complete": "Completa: {gap}",
        "pron_say_this": "Pronuncia: \"{text}\"",
        "matching_pick": "Abbina ogni espressione alla sua traduzione:",
        "instructions_mc": "Scegli la risposta corretta.",
        "instructions_fill": "Scrivi la parola mancante.",
        "instructions_pron": "Registra la tua pronuncia.",
        "instructions_match": "Trascina per abbinare.",
    },
}

LANG_NAMES = {
    "en": "inglés",
    "es": "español",
    "pt": "portugués",
    "fr": "francés",
    "de": "alemán",
    "it": "italiano",
}

NATIVE_CODES = ["es", "pt", "fr", "de", "it"]
DEFAULT_TARGET = "en"

# Banco mejorado con contextos y variaciones
GREETING_DATA = {
    "hello": {
        "en": "Hello",
        "context": "saludo general",
        "formality": "neutral",
        "translations": {"es": "Hola", "pt": "Olá", "fr": "Bonjour", "de": "Hallo", "it": "Ciao"}
    },
    "good_morning": {
        "en": "Good morning",
        "context": "antes del mediodía",
        "formality": "formal",
        "translations": {"es": "Buenos días", "pt": "Bom dia", "fr": "Bonjour", "de": "Guten Morgen", "it": "Buongiorno"}
    },
    "good_afternoon": {
        "en": "Good afternoon",
        "context": "después del mediodía",
        "formality": "formal",
        "translations": {"es": "Buenas tardes", "pt": "Boa tarde", "fr": "Bon après-midi", "de": "Guten Tag", "it": "Buon pomeriggio"}
    },
    "good_evening": {
        "en": "Good evening",
        "context": "por la noche al saludar",
        "formality": "formal",
        "translations": {"es": "Buenas noches", "pt": "Boa noite", "fr": "Bonsoir", "de": "Guten Abend", "it": "Buonasera"}
    },
    "nice_to_meet_you": {
        "en": "Nice to meet you",
        "context": "al conocer a alguien",
        "formality": "neutral",
        "translations": {"es": "Mucho gusto", "pt": "Prazer em conhecê-lo", "fr": "Enchanté", "de": "Freut mich", "it": "Piacere"}
    },
    "how_are_you": {
        "en": "How are you?",
        "context": "pregunta de cortesía",
        "formality": "neutral",
        "translations": {"es": "¿Cómo estás?", "pt": "Como você está?", "fr": "Comment allez-vous?", "de": "Wie geht es dir?", "it": "Come stai?"}
    },
    "my_name_is": {
        "en": "My name is",
        "context": "presentación personal",
        "formality": "formal",
        "translations": {"es": "Me llamo", "pt": "Meu nome é", "fr": "Je m'appelle", "de": "Ich heiße", "it": "Mi chiamo"}
    },
}

# Feedback pedagógico mejorado
FEEDBACK_TEMPLATES = {
    "es": {
        "correct": "✓ Correcto. {explanation}",
        "incorrect": "✗ Incorrecto. {why_wrong} La respuesta correcta es \"{correct}\". {explanation}",
        "context": "Se usa en: {context}.",
        "formality": "Nivel de formalidad: {level}.",
        "comparison": "A diferencia de \"{other}\", \"{correct}\" {difference}.",
    },
    "pt": {
        "correct": "✓ Correto. {explanation}",
        "incorrect": "✗ Incorreto. {why_wrong} A resposta correta é \"{correct}\". {explanation}",
        "context": "Usado em: {context}.",
        "formality": "Nível de formalidade: {level}.",
        "comparison": "Ao contrário de \"{other}\", \"{correct}\" {difference}.",
    },
    "fr": {
        "correct": "✓ Correct. {explanation}",
        "incorrect": "✗ Incorrect. {why_wrong} La bonne réponse est « {correct} ». {explanation}",
        "context": "Utilisé dans : {context}.",
        "formality": "Niveau de formalité : {level}.",
        "comparison": "Contrairement à « {other} », « {correct} » {difference}.",
    },
    "de": {
        "correct": "✓ Richtig. {explanation}",
        "incorrect": "✗ Falsch. {why_wrong} Die richtige Antwort ist \"{correct}\". {explanation}",
        "context": "Wird verwendet in: {context}.",
        "formality": "Formalitätsstufe: {level}.",
        "comparison": "Im Gegensatz zu \"{other}\" wird \"{correct}\" {difference}.",
    },
    "it": {
        "correct": "✓ Corretto. {explanation}",
        "incorrect": "✗ Sbagliato. {why_wrong} La risposta corretta è \"{correct}\". {explanation}",
        "context": "Si usa in: {context}.",
        "formality": "Livello di formalità: {level}.",
        "comparison": "A differenza di \"{other}\", \"{correct}\" {difference}.",
    },
}


def ensure_languages():
    created = []
    lang_names_db = {
        "es": "Español",
        "en": "English",
        "pt": "Português",
        "fr": "Français",
        "de": "Deutsch",
        "it": "Italiano"
    }
    for code, name in lang_names_db.items():
        obj, was_created = Language.objects.get_or_create(code=code, defaults={"name": name})
        if was_created:
            created.append(code)
        elif obj.name != name:
            obj.name = name
            obj.save(update_fields=["name"])
    return created


def p(lang_code, key, **kwargs):
    base = PROMPTS.get(lang_code, PROMPTS["es"])
    text = base.get(key, PROMPTS["es"].get(key, key))
    return text.format(**kwargs)


def get_feedback(lang_code, template_key, **kwargs):
    templates = FEEDBACK_TEMPLATES.get(lang_code, FEEDBACK_TEMPLATES["es"])
    return templates.get(template_key, "").format(**kwargs)


def create_mc_improved(exercise, native_code, target_code, question_text, correct, distractors_with_reasons):
    """
    Crea selección múltiple con opciones aleatorizadas y feedback detallado.
    correct: tupla (texto, explicación)
    distractors_with_reasons: lista de tuplas (texto, razón_por_qué_es_incorrecto)
    """
    loc = ExerciseLocalization.objects.create(
        exercise=exercise,
        native_language=Language.objects.get(code=native_code),
        target_language=Language.objects.get(code=target_code),
        question=question_text,
        instructions=p(native_code, "instructions_mc"),
    )
    
    # Crear todas las opciones en una lista
    all_options = []
    
    # Opción correcta
    correct_text, correct_explanation = correct
    all_options.append({
        "text": correct_text,
        "is_correct": True,
        "feedback": get_feedback(native_code, "correct", explanation=correct_explanation)
    })
    
    # Distractores
    for distractor_text, why_wrong in distractors_with_reasons:
        all_options.append({
            "text": distractor_text,
            "is_correct": False,
            "feedback": get_feedback(
                native_code, "incorrect",
                why_wrong=why_wrong,
                correct=correct_text,
                explanation=correct_explanation
            )
        })
    
    # IMPORTANTE: Aleatorizar el orden de las opciones
    random.shuffle(all_options)
    
    # Crear las opciones en la base de datos
    for opt in all_options:
        ExerciseOption.objects.create(
            exercise_localization=loc,
            text=opt["text"],
            is_correct=opt["is_correct"],
            feedback=opt["feedback"]
        )


def create_fill_improved(exercise, native_code, target_code, gap_text, answer, context, alternatives):
    """
    Completar espacios con feedback mejorado y alternativas comunes.
    alternatives: lista de tuplas (texto_alternativa, por_qué_es_incorrecta)
    """
    loc = ExerciseLocalization.objects.create(
        exercise=exercise,
        native_language=Language.objects.get(code=native_code),
        target_language=Language.objects.get(code=target_code),
        question=p(native_code, "fill_complete", gap=gap_text),
        instructions=p(native_code, "instructions_fill"),
    )
    
    # Respuesta correcta
    ExerciseOption.objects.create(
        exercise_localization=loc,
        text=answer,
        is_correct=True,
        feedback=get_feedback(native_code, "correct", explanation="Se usa en: {}.".format(context))
    )
    
    # Alternativas incorrectas con explicación
    for alt_text, why_wrong in alternatives:
        ExerciseOption.objects.create(
            exercise_localization=loc,
            text=alt_text,
            is_correct=False,
            feedback=get_feedback(
                native_code, "incorrect",
                why_wrong=why_wrong,
                correct=answer,
                explanation="La forma correcta en este contexto es '{}'.".format(answer)
            )
        )


def create_pron_improved(exercise, native_code, target_code, expected_text, context, pronunciation_tips=None):
    """
    Ejercicio de pronunciación con tips específicos.
    """
    instructions = p(native_code, "instructions_pron")
    if pronunciation_tips:
        instructions += " Tip: {}".format(pronunciation_tips)
    
    ExerciseLocalization.objects.create(
        exercise=exercise,
        native_language=Language.objects.get(code=native_code),
        target_language=Language.objects.get(code=target_code),
        question=p(native_code, "pron_say_this", text=expected_text),
        instructions=instructions,
        expected_audio_text=expected_text,
        audio_url=None
    )


def create_matching_improved(exercise, native_code, target_code, pairs, context_note):
    """
    Emparejar con pares aleatorizados.
    pairs: lista de tuplas (target_text, native_text)
    """
    # Aleatorizar el orden de los pares
    shuffled_pairs = pairs.copy()
    random.shuffle(shuffled_pairs)
    
    loc = ExerciseLocalization.objects.create(
        exercise=exercise,
        native_language=Language.objects.get(code=native_code),
        target_language=Language.objects.get(code=target_code),
        question=p(native_code, "matching_pick"),
        instructions=p(native_code, "instructions_match"),
        matching_pairs=[{"target": t, "native": n} for t, n in shuffled_pairs]
    )
    
    ExerciseOption.objects.create(
        exercise_localization=loc,
        text="feedback",
        is_correct=True,
        feedback=get_feedback(native_code, "correct", explanation=context_note)
    )


@transaction.atomic
def seed_greetings_for_pair(native_code, target_code):
    """
    Crea lección A1 mejorada con ejercicios pedagógicamente efectivos.
    """
    # 1) Lección base
    lesson, _ = Lesson.objects.get_or_create(
        title_key="greetings_introductions_a1",
        level="A1",
        lesson_type="vocabulary",
        defaults=dict(sequence=10, difficulty=1, priority=0, is_active=True)
    )

    # 2) Localización
    title_translations = {
        "es": "Saludos y Presentaciones",
        "pt": "Saudações e Apresentações",
        "fr": "Salutations et Présentations",
        "de": "Begrüßungen und Vorstellungen",
        "it": "Saluti e Presentazioni",
    }
    
    content_translations = {
        "es": "Aprende a saludar, presentarte y mantener conversaciones básicas en {}. Incluye contextos formales e informales.".format(LANG_NAMES[target_code]),
        "pt": "Aprenda a cumprimentar, se apresentar e manter conversas básicas em {}. Inclui contextos formais e informais.".format(LANG_NAMES[target_code]),
        "fr": "Apprenez à saluer, vous présenter et maintenir des conversations de base en {}. Comprend des contextes formels et informels.".format(LANG_NAMES[target_code]),
        "de": "Lerne zu grüßen, dich vorzustellen und Basisgespräche auf {} zu führen. Umfasst formelle und informelle Kontexte.".format(LANG_NAMES[target_code]),
        "it": "Impara a salutare, presentarti e mantenere conversazioni di base in {}. Include contesti formali e informali.".format(LANG_NAMES[target_code]),
    }

    LessonLocalization.objects.get_or_create(
        lesson=lesson,
        native_language=Language.objects.get(code=native_code),
        target_language=Language.objects.get(code=target_code),
        defaults=dict(
            title=title_translations.get(native_code, "Greetings and Introductions"),
            content=content_translations.get(native_code, ""),
            hero_image="",
            resources={"topic": "greetings", "cefr": "A1"}
        )
    )

    seq = 10
    
    # ===== BLOQUE 1: RECONOCIMIENTO (ejercicios 1-6) =====
    
    # Ejercicio 1: Saludo general
    seq += 10
    ex1, _ = Exercise.objects.get_or_create(
        lesson=lesson, sequence=seq, exercise_type="multiple_choice",
        defaults=dict(instructions_key="mc")
    )
    create_mc_improved(
        ex1, native_code, target_code,
        question_text=p(native_code, "mc_context", context="una reunión de negocios por la mañana", target_name=LANG_NAMES[target_code].capitalize()),
        correct=("Good morning", "Es el saludo formal apropiado antes del mediodía en contextos profesionales."),
        distractors_with_reasons=[
            ("Good night", "Este se usa para despedirse al irse a dormir, no para saludar."),
            ("Good afternoon", "Se usa después del mediodía, no en la mañana."),
            ("Hello", "Aunque correcto, 'Good morning' es más formal y apropiado en negocios.")
        ]
    )
    
    # Ejercicio 2: Respuesta a saludo
    seq += 10
    ex2, _ = Exercise.objects.get_or_create(
        lesson=lesson, sequence=seq, exercise_type="multiple_choice",
        defaults=dict(instructions_key="mc")
    )
    create_mc_improved(
        ex2, native_code, target_code,
        question_text=p(native_code, "mc_best_response", phrase="How are you?"),
        correct=("I'm fine, thank you", "Es la respuesta estándar y cortés a esta pregunta."),
        distractors_with_reasons=[
            ("Yes, please", "Esta respuesta es para ofrecimientos, no para '¿Cómo estás?'."),
            ("My name is John", "Esto responde a '¿Cómo te llamas?', no a '¿Cómo estás?'."),
            ("Nice to meet you", "Esto se dice al conocer a alguien por primera vez, no como respuesta a '¿Cómo estás?'.")
        ]
    )
    
    # Ejercicio 3: Presentación
    seq += 10
    ex3, _ = Exercise.objects.get_or_create(
        lesson=lesson, sequence=seq, exercise_type="multiple_choice",
        defaults=dict(instructions_key="mc")
    )
    create_mc_improved(
        ex3, native_code, target_code,
        question_text=p(native_code, "mc_how_say", phrase="me llamo", target_name=LANG_NAMES[target_code].capitalize()),
        correct=("My name is", "Es la forma estándar para presentar tu nombre."),
        distractors_with_reasons=[
            ("I am", "Incompleto. Se necesita 'My name is' para presentarse correctamente."),
            ("You are", "Esto habla de la otra persona, no de ti."),
            ("My friend is", "Esto presenta a otra persona, no a ti mismo.")
        ]
    )
    
    # Ejercicio 4: Encuentro formal
    seq += 10
    ex4, _ = Exercise.objects.get_or_create(
        lesson=lesson, sequence=seq, exercise_type="multiple_choice",
        defaults=dict(instructions_key="mc")
    )
    create_mc_improved(
        ex4, native_code, target_code,
        question_text=p(native_code, "mc_context", context="conoces a alguien por primera vez en una conferencia", target_name=LANG_NAMES[target_code].capitalize()),
        correct=("Nice to meet you", "Expresión estándar al conocer a alguien formalmente."),
        distractors_with_reasons=[
            ("See you later", "Esto es una despedida, no un saludo inicial."),
            ("How are you?", "Aunque apropiado, primero se dice 'Nice to meet you' al conocerse."),
            ("Thank you", "Es un agradecimiento, no un saludo para conocer a alguien.")
        ]
    )
    
    # Ejercicio 5: Saludo vespertino
    seq += 10
    ex5, _ = Exercise.objects.get_or_create(
        lesson=lesson, sequence=seq, exercise_type="multiple_choice",
        defaults=dict(instructions_key="mc")
    )
    create_mc_improved(
        ex5, native_code, target_code,
        question_text=p(native_code, "mc_context", context="llegas a una cena formal a las 8 PM", target_name=LANG_NAMES[target_code].capitalize()),
        correct=("Good evening", "Saludo formal apropiado para la noche."),
        distractors_with_reasons=[
            ("Good morning", "Se usa solo en la mañana, no en la noche."),
            ("Good afternoon", "Se usa en la tarde, no después de las 6 PM."),
            ("Good night", "Se usa para despedirse al ir a dormir, no para saludar al llegar.")
        ]
    )
    
    # Ejercicio 6: Contexto informal
    seq += 10
    ex6, _ = Exercise.objects.get_or_create(
        lesson=lesson, sequence=seq, exercise_type="multiple_choice",
        defaults=dict(instructions_key="mc")
    )
    create_mc_improved(
        ex6, native_code, target_code,
        question_text=p(native_code, "mc_context", context="encuentras a un amigo en la calle", target_name=LANG_NAMES[target_code].capitalize()),
        correct=("Hi!", "Saludo informal y amistoso, perfecto entre amigos."),
        distractors_with_reasons=[
            ("Good evening, sir", "Demasiado formal para un amigo."),
            ("Dear Mr. Smith", "Esto es para cartas formales, no para conversación oral."),
            ("To whom it may concern", "Frase de cartas formales, completamente inapropiada aquí.")
        ]
    )
    
    # ===== BLOQUE 2: PRODUCCIÓN (ejercicios 7-12) =====
    
    # Ejercicio 7
    seq += 10
    ex7, _ = Exercise.objects.get_or_create(
        lesson=lesson, sequence=seq, exercise_type="fill_blank",
        defaults=dict(instructions_key="fill")
    )
    create_fill_improved(
        ex7, native_code, target_code,
        gap_text="_____ morning, everyone!",
        answer="Good",
        context="saludo matutino formal",
        alternatives=[
            ("Hello", "'Hello morning' no es correcto. La expresión correcta es 'Good morning'."),
            ("Nice", "'Nice morning' no es un saludo estándar."),
            ("Happy", "'Happy morning' no es la forma idiomática en inglés.")
        ]
    )
    
    # Ejercicio 8
    seq += 10
    ex8, _ = Exercise.objects.get_or_create(
        lesson=lesson, sequence=seq, exercise_type="fill_blank",
        defaults=dict(instructions_key="fill")
    )
    create_fill_improved(
        ex8, native_code, target_code,
        gap_text="My _____ is Sarah.",
        answer="name",
        context="presentación personal",
        alternatives=[
            ("call", "'My call is' no es correcto. Se dice 'My name is'."),
            ("am", "'My am is' no tiene sentido gramatical."),
            ("friend", "Cambiaría el significado a 'mi amigo/a es Sarah'.")
        ]
    )
    
    # Ejercicio 9
    seq += 10
    ex9, _ = Exercise.objects.get_or_create(
        lesson=lesson, sequence=seq, exercise_type="fill_blank",
        defaults=dict(instructions_key="fill")
    )
    create_fill_improved(
        ex9, native_code, target_code,
        gap_text="Nice to _____ you!",
        answer="meet",
        context="al conocer a alguien",
        alternatives=[
            ("see", "'Nice to see you' se usa para alguien que ya conoces, no al conocer por primera vez."),
            ("know", "'Nice to know you' no es la expresión idiomática correcta."),
            ("greet", "'Nice to greet you' es poco natural en inglés.")
        ]
    )
    
    # Ejercicio 10
    seq += 10
    ex10, _ = Exercise.objects.get_or_create(
        lesson=lesson, sequence=seq, exercise_type="fill_blank",
        defaults=dict(instructions_key="fill")
    )
    create_fill_improved(
        ex10, native_code, target_code,
        gap_text="How _____ you?",
        answer="are",
        context="pregunta de cortesía sobre el estado de alguien",
        alternatives=[
            ("is", "Sería 'How is you?' que es gramaticalmente incorrecto. El correcto es 'How are you?'."),
            ("do", "'How do you?' está incompleto, faltaría un verbo después."),
            ("am", "'How am you?' no existe en inglés.")
        ]
    )
    
    # Ejercicio 11
    seq += 10
    ex11, _ = Exercise.objects.get_or_create(
        lesson=lesson, sequence=seq, exercise_type="fill_blank",
        defaults=dict(instructions_key="fill")
    )
    create_fill_improved(
        ex11, native_code, target_code,
        gap_text="Good _____, Mr. Johnson. (3:00 PM)",
        answer="afternoon",
        context="saludo formal en la tarde",
        alternatives=[
            ("morning", "A las 3 PM ya no es mañana."),
            ("evening", "Evening comienza después de las 6 PM."),
            ("night", "'Good night' es despedida, no saludo.")
        ]
    )
    
    # Ejercicio 12
    seq += 10
    ex12, _ = Exercise.objects.get_or_create(
        lesson=lesson, sequence=seq, exercise_type="fill_blank",
        defaults=dict(instructions_key="fill")
    )
    create_fill_improved(
        ex12, native_code, target_code,
        gap_text="I'm _____, thank you.",
        answer="fine",
        context="respuesta estándar a 'How are you?'",
        alternatives=[
            ("good", "Aunque común, 'fine' es más apropiado gramaticalmente."),
            ("happy", "Demasiado específico. 'Fine' es más neutral y apropiado."),
            ("nice", "'I'm nice' significa 'soy amable', no describe cómo te sientes.")
        ]
    )
    
    # ===== BLOQUE 3: PRONUNCIACIÓN (ejercicios 13-16) =====
    
    pron_exercises = [
        ("Good morning!", "saludo matutino", "Enfatiza 'mor' en 'morning'"),
        ("Nice to meet you.", "frase de presentación", "Conecta 'to' y 'meet' fluidamente: 'to-meet'"),
        ("How are you doing?", "pregunta de cortesía extendida", "La 'r' en 'are' es suave"),
        ("My name is Michael.", "presentación con nombre", "Pronuncia claramente cada sílaba de 'Michael': Mai-kəl"),
    ]
    
    for text, context, tip in pron_exercises:
        seq += 10
        ex, _ = Exercise.objects.get_or_create(
            lesson=lesson, sequence=seq, exercise_type="shadowing",
            defaults=dict(instructions_key="pron")
        )
        create_pron_improved(ex, native_code, target_code, text, context, tip)
    
    # ===== BLOQUE 4: INTEGRACIÓN (ejercicios 17-20) =====
    
    matching_sets = [
        {
            "pairs": [
                ("Hello", GREETING_DATA["hello"]["translations"][native_code]),
                ("Good morning", GREETING_DATA["good_morning"]["translations"][native_code]),
                ("Good evening", GREETING_DATA["good_evening"]["translations"][native_code]),
                ("Good afternoon", GREETING_DATA["good_afternoon"]["translations"][native_code]),
                ("How are you?", GREETING_DATA["how_are_you"]["translations"][native_code]),
            ],
            "context": "Saludos básicos según el momento del día y nivel de formalidad."
        },
        {
            "pairs": [
                ("My name is", GREETING_DATA["my_name_is"]["translations"][native_code]),
                ("Nice to meet you", GREETING_DATA["nice_to_meet_you"]["translations"][native_code]),
                ("How are you?", GREETING_DATA["how_are_you"]["translations"][native_code]),
                ("Hello", GREETING_DATA["hello"]["translations"][native_code]),
                ("Good morning", GREETING_DATA["good_morning"]["translations"][native_code]),
            ],
            "context": "Frases esenciales para presentarse y conocer a alguien."
        },
        {
            "pairs": [
                ("Good morning", GREETING_DATA["good_morning"]["translations"][native_code]),
                ("Good afternoon", GREETING_DATA["good_afternoon"]["translations"][native_code]),
                ("Good evening", GREETING_DATA["good_evening"]["translations"][native_code]),
                ("Nice to meet you", GREETING_DATA["nice_to_meet_you"]["translations"][native_code]),
                ("My name is", GREETING_DATA["my_name_is"]["translations"][native_code]),
            ],
            "context": "Expresiones formales para entornos profesionales y académicos."
        },
        {
            "pairs": [
                ("Hello", GREETING_DATA["hello"]["translations"][native_code]),
                ("How are you?", GREETING_DATA["how_are_you"]["translations"][native_code]),
                ("Nice to meet you", GREETING_DATA["nice_to_meet_you"]["translations"][native_code]),
                ("My name is", GREETING_DATA["my_name_is"]["translations"][native_code]),
                ("Good evening", GREETING_DATA["good_evening"]["translations"][native_code]),
            ],
            "context": "Repaso integrado de saludos y presentaciones esenciales."
        }
    ]
    
    for match_set in matching_sets:
        seq += 10
        ex, _ = Exercise.objects.get_or_create(
            lesson=lesson, sequence=seq, exercise_type="matching",
            defaults=dict(instructions_key="match")
        )
        create_matching_improved(
            ex, native_code, target_code,
            pairs=match_set["pairs"],
            context_note=match_set["context"]
        )


class Command(BaseCommand):
    help = "Crea la lección A1 'Saludos y Presentaciones' con 20 ejercicios pedagógicamente optimizados."

    def add_arguments(self, parser):
        parser.add_argument(
            "--target",
            type=str,
            default=DEFAULT_TARGET,
            help="Código del idioma objetivo (default: {}).".format(DEFAULT_TARGET)
        )
        parser.add_argument(
            "--natives",
            nargs="*",
            default=NATIVE_CODES,
            help="Lista de códigos de idiomas nativos (default: {}).".format(' '.join(NATIVE_CODES))
        )
        parser.add_argument(
            "--seed",
            type=int,
            default=None,
            help="Semilla para aleatorización (útil para testing reproducible)."
        )

    def handle(self, *args, **options):
        target = (options.get("target") or DEFAULT_TARGET).lower()
        natives = [c.lower() for c in (options.get("natives") or NATIVE_CODES)]
        seed_value = options.get("seed")
        
        # Configurar semilla si se proporciona
        if seed_value is not None:
            random.seed(seed_value)
            self.stdout.write(self.style.WARNING("Usando semilla aleatoria: {}".format(seed_value)))

        self.stdout.write(self.style.MIGRATE_HEADING("=" * 60))
        self.stdout.write(self.style.MIGRATE_HEADING("CREACIÓN DE LECCIÓN: Saludos y Presentaciones (A1)"))
        self.stdout.write(self.style.MIGRATE_HEADING("=" * 60))
        
        # Validar idiomas
        self.stdout.write("\n1. Validando idiomas en la base de datos...")
        created = ensure_languages()
        if created:
            self.stdout.write(self.style.SUCCESS("   ✓ Idiomas creados: {}".format(', '.join(created))))
        else:
            self.stdout.write("   ✓ Todos los idiomas ya existían")

        # Crear lecciones
        self.stdout.write("\n2. Creando lección para idioma objetivo: {}".format(target.upper()))
        self.stdout.write("   Idiomas nativos: {}\n".format(', '.join([n.upper() for n in natives])))
        
        for i, native in enumerate(natives, 1):
            self.stdout.write("   [{}/{}] Procesando par: {} → {}".format(
                i, len(natives), native.upper(), target.upper()
            ))
            try:
                seed_greetings_for_pair(native, target)
                self.stdout.write(self.style.SUCCESS("       ✓ Completado con 20 ejercicios aleatorizados"))
            except Exception as e:
                self.stdout.write(self.style.ERROR("       ✗ Error: {}".format(str(e))))
                raise

        self.stdout.write("\n" + "=" * 60)
        self.stdout.write(self.style.SUCCESS("✓ LECCIÓN CREADA EXITOSAMENTE"))
        self.stdout.write("=" * 60)
        self.stdout.write("\nCaracterísticas implementadas:")
        self.stdout.write("  • Opciones de respuesta aleatorizadas (no siempre en inciso A)")
        self.stdout.write("  • Feedback detallado para respuestas correctas e incorrectas")
        self.stdout.write("  • Ejercicios con contexto y progresión pedagógica")
        self.stdout.write("  • 4 tipos de ejercicios: MC, Fill, Pronunciación, Matching")
        self.stdout.write("  • Explicaciones que incluyen el 'por qué' de cada respuesta")
        self.stdout.write("\nEstructura de la lección:")
        self.stdout.write("  • Ejercicios 1-6:   Reconocimiento (Multiple Choice)")
        self.stdout.write("  • Ejercicios 7-12:  Producción (Fill in the Blank)")
        self.stdout.write("  • Ejercicios 13-16: Pronunciación (Shadowing)")
        self.stdout.write("  • Ejercicios 17-20: Integración (Matching)")
        self.stdout.write("\n" + "=" * 60 + "\n")