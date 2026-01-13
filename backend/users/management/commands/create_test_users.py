from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from users.models import LearningStats

User = get_user_model()


class Command(BaseCommand):
    help = 'Crea usuarios de prueba para desarrollo'

    def handle(self, *args, **options):
        # Lista de usuarios de prueba
        test_users = [
            {
                'username': 'juan',
                'email': 'juan@test.com',
                'password': 'Test1234',
                'first_name': 'Juan',
                'last_name': 'Pérez',
                'native_language': 'es',
                'target_language': 'en',
                'age': 25,
                'level': 'A1'
            },
            {
                'username': 'maria',
                'email': 'maria@test.com',
                'password': 'Test1234',
                'first_name': 'María',
                'last_name': 'González',
                'native_language': 'es',
                'target_language': 'en',
                'age': 30,
                'level': 'A2'
            },
            {
                'username': 'pedro',
                'email': 'pedro@test.com',
                'password': 'Test1234',
                'first_name': 'Pedro',
                'last_name': 'Martínez',
                'native_language': 'es',
                'target_language': 'en',
                'age': 22,
                'level': 'B1'
            },
            {
                'username': 'ana',
                'email': 'ana@test.com',
                'password': 'Test1234',
                'first_name': 'Ana',
                'last_name': 'López',
                'native_language': 'es',
                'target_language': 'en',
                'age': 28,
                'level': 'B2'
            },
            {
                'username': 'carlos',
                'email': 'carlos@test.com',
                'password': 'Test1234',
                'first_name': 'Carlos',
                'last_name': 'Rodríguez',
                'native_language': 'es',
                'target_language': 'en',
                'age': 35,
                'level': 'C1'
            },
        ]

        created_count = 0
        updated_count = 0

        for user_data in test_users:
            username = user_data['username']
            email = user_data['email']
            password = user_data.pop('password')

            # Verificar si el usuario ya existe
            user, created = User.objects.get_or_create(
                username=username,
                defaults=user_data
            )

            if created:
                user.set_password(password)
                user.save()
                # Crear LearningStats para el usuario
                LearningStats.objects.get_or_create(user=user)
                created_count += 1
                self.stdout.write(
                    self.style.SUCCESS(f'[OK] Usuario creado: {username} (email: {email}, password: Test1234)')
                )
            else:
                # Actualizar la contraseña del usuario existente
                user.set_password(password)
                for key, value in user_data.items():
                    setattr(user, key, value)
                user.save()
                # Asegurar que tenga LearningStats
                LearningStats.objects.get_or_create(user=user)
                updated_count += 1
                self.stdout.write(
                    self.style.WARNING(f'[ACTUALIZADO] Usuario ya existia y fue actualizado: {username} (email: {email}, password: Test1234)')
                )

        self.stdout.write('')
        self.stdout.write(self.style.SUCCESS(f'=== Resumen ==='))
        self.stdout.write(self.style.SUCCESS(f'Usuarios creados: {created_count}'))
        self.stdout.write(self.style.SUCCESS(f'Usuarios actualizados: {updated_count}'))
        self.stdout.write(self.style.SUCCESS(f'Total: {created_count + updated_count}'))
        self.stdout.write('')
        self.stdout.write(self.style.SUCCESS('Todos los usuarios tienen la contraseña: Test1234'))
        self.stdout.write('')
        self.stdout.write('Puedes iniciar sesión con:')
        for user_data in test_users:
            self.stdout.write(f'  - Usuario: {user_data["username"]} / Email: {user_data["email"]}')
