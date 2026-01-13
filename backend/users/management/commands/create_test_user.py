from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model

User = get_user_model()

class Command(BaseCommand):
    help = 'Crea un usuario de prueba para pruebas'

    def handle(self, *args, **options):
        username = 'testuser'
        email = 'test@example.com'
        password = 'TestPassword123!'
        
        # Verificar si el usuario ya existe
        if User.objects.filter(username=username).exists():
            self.stdout.write(
                self.style.WARNING(f'El usuario {username} ya existe')
            )
            return
        
        # Crear el usuario
        user = User.objects.create_user(
            username=username,
            email=email,
            password=password,
            first_name='Test',
            last_name='User',
            native_language='es',
            target_language='en',
            age=25,
            level='A1'
        )
        
        self.stdout.write(
            self.style.SUCCESS(
                f'Usuario de prueba creado exitosamente!\n'
                f'Usuario: {username}\n'
                f'Email: {email}\n'
                f'Contraseña: {password}\n'
                f'Puedes usar estas credenciales para iniciar sesión en la aplicación.'
            )
        )