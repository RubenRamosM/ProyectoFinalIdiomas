from django.core.management.base import BaseCommand

from test.models import TestQuestion, TestOption


class Command(BaseCommand):
    help = 'Seed placement test questions (15 questions: 5 multiple choice, 5 fill-in-the-blank, 5 pronunciation)'

    def handle(self, *args, **options):
        # Clear existing
        TestOption.objects.all().delete()
        TestQuestion.objects.all().delete()

        # ============================================
        # SECCIÓN 1: PREGUNTAS DE SELECCIÓN MÚLTIPLE
        # ============================================
        
        # Q1 - Vocabulario muy básico (respuesta en posición 3)
        q1 = TestQuestion.objects.create(
            question="¿Qué significa 'cat' en español?",
            qtype='choice',
            order=1
        )
        TestOption.objects.create(question=q1, text='Perro', is_correct=False, order=1)
        TestOption.objects.create(question=q1, text='Pájaro', is_correct=False, order=2)
        TestOption.objects.create(question=q1, text='Gato', is_correct=True, order=3)
        TestOption.objects.create(question=q1, text='Ratón', is_correct=False, order=4)

        # Q2 - Colores básicos (respuesta en posición 1)
        q2 = TestQuestion.objects.create(
            question="¿De qué color es el cielo en un día soleado? 'The sky is ___'",
            qtype='choice',
            order=2
        )
        TestOption.objects.create(question=q2, text='blue', is_correct=True, order=1)
        TestOption.objects.create(question=q2, text='red', is_correct=False, order=2)
        TestOption.objects.create(question=q2, text='green', is_correct=False, order=3)
        TestOption.objects.create(question=q2, text='yellow', is_correct=False, order=4)

        # Q3 - Números simples (respuesta en posición 4)
        q3 = TestQuestion.objects.create(
            question="¿Cómo se dice el número '2' en inglés?",
            qtype='choice',
            order=3
        )
        TestOption.objects.create(question=q3, text='one', is_correct=False, order=1)
        TestOption.objects.create(question=q3, text='three', is_correct=False, order=2)
        TestOption.objects.create(question=q3, text='four', is_correct=False, order=3)
        TestOption.objects.create(question=q3, text='two', is_correct=True, order=4)

        # Q4 - Saludos básicos (respuesta en posición 2)
        q4 = TestQuestion.objects.create(
            question="¿Cuál es la forma correcta de decir 'buenos días' en inglés?",
            qtype='choice',
            order=4
        )
        TestOption.objects.create(question=q4, text='Good night', is_correct=False, order=1)
        TestOption.objects.create(question=q4, text='Good morning', is_correct=True, order=2)
        TestOption.objects.create(question=q4, text='Good afternoon', is_correct=False, order=3)
        TestOption.objects.create(question=q4, text='Good bye', is_correct=False, order=4)

        # Q5 - Verbo to be simple (respuesta en posición 3)
        q5 = TestQuestion.objects.create(
            question="Completa la frase: 'I ___ happy' (Yo estoy feliz)",
            qtype='choice',
            order=5
        )
        TestOption.objects.create(question=q5, text='is', is_correct=False, order=1)
        TestOption.objects.create(question=q5, text='are', is_correct=False, order=2)
        TestOption.objects.create(question=q5, text='am', is_correct=True, order=3)
        TestOption.objects.create(question=q5, text='be', is_correct=False, order=4)

        # ============================================
        # SECCIÓN 2: COMPLETAR LA FRASE
        # ============================================
        
        # Q6 - Artículo simple
        q6 = TestQuestion.objects.create(
            question="Completa: 'I have ___ dog' (Escribe 'a' o 'an')",
            qtype='fill',
            order=6
        )
        TestOption.objects.create(question=q6, text='a', is_correct=True, order=1)

        # Q7 - Verbo to be plural
        q7 = TestQuestion.objects.create(
            question="Completa: 'We ___ students' (Nosotros somos estudiantes. Escribe el verbo 'to be' correcto)",
            qtype='fill',
            order=7
        )
        TestOption.objects.create(question=q7, text='are', is_correct=True, order=1)

        # Q8 - Pronombre simple
        q8 = TestQuestion.objects.create(
            question="Completa: '___ name is Maria' (Mi nombre es María. Escribe el pronombre posesivo para 'mi')",
            qtype='fill',
            order=8
        )
        TestOption.objects.create(question=q8, text='my', is_correct=True, order=1)

        # Q9 - Verbo simple presente
        q9 = TestQuestion.objects.create(
            question="Completa: 'I ___ English' (Yo hablo inglés. Usa el verbo 'speak')",
            qtype='fill',
            order=9
        )
        TestOption.objects.create(question=q9, text='speak', is_correct=True, order=1)

        # Q10 - Preposición básica
        q10 = TestQuestion.objects.create(
            question="Completa: 'I live ___ Mexico' (Yo vivo en México. Escribe la preposición correcta)",
            qtype='fill',
            order=10
        )
        TestOption.objects.create(question=q10, text='in', is_correct=True, order=1)

        # ============================================
        # SECCIÓN 3: PRONUNCIACIÓN
        # ============================================
        
        # Q11 - Palabra muy simple
        q11 = TestQuestion.objects.create(
            question="Pronuncia esta palabra: 'yes' (Significa 'sí')",
            qtype='speak',
            order=11
        )
        TestOption.objects.create(question=q11, text='yes', is_correct=True, order=1)

        # Q12 - Saludo básico
        q12 = TestQuestion.objects.create(
            question="Pronuncia este saludo: 'hello' (Hola)",
            qtype='speak',
            order=12
        )
        TestOption.objects.create(question=q12, text='hello', is_correct=True, order=1)

        # Q13 - Despedida simple
        q13 = TestQuestion.objects.create(
            question="Pronuncia esta despedida: 'goodbye' (Adiós)",
            qtype='speak',
            order=13
        )
        TestOption.objects.create(question=q13, text='goodbye', is_correct=True, order=1)

        # Q14 - Palabra común
        q14 = TestQuestion.objects.create(
            question="Pronuncia esta palabra: 'thank you' (Gracias)",
            qtype='speak',
            order=14
        )
        TestOption.objects.create(question=q14, text='thank you', is_correct=True, order=1)

        # Q15 - Número simple
        q15 = TestQuestion.objects.create(
            question="Pronuncia este número: 'ten' (El número 10)",
            qtype='speak',
            order=15
        )
        TestOption.objects.create(question=q15, text='ten', is_correct=True, order=1)

        self.stdout.write(self.style.SUCCESS('✓ Seeded 15 placement questions successfully!'))
        self.stdout.write(self.style.SUCCESS('  - 5 multiple choice questions'))
        self.stdout.write(self.style.SUCCESS('  - 5 fill-in-the-blank questions'))
        self.stdout.write(self.style.SUCCESS('  - 5 pronunciation questions'))