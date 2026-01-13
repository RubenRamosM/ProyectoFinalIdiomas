from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model

User = get_user_model()

class Command(BaseCommand):
    help = 'Crea un superusuario para administración'

    def handle(self, *args, **options):
        username = 'admin'
        email = 'admin@example.com'
        password = 'AdminPassword123!'
        
        # Verificar si el superusuario ya existe
        if User.objects.filter(username=username).exists():
            self.stdout.write(
                self.style.WARNING(f'El superusuario {username} ya existe')
            )
            return
        
        # Crear el superusuario
        user = User.objects.create_superuser(
            username=username,
            email=email,
            password=password,
            first_name='Admin',
            last_name='User',
            native_language='es',
            target_language='en',
            age=30
        )
        
        self.stdout.write(
            self.style.SUCCESS(
                f'¡Superusuario creado exitosamente!\n'
                f'Usuario: {username}\n'
                f'Email: {email}\n'
                f'Contraseña: {password}\n'
                f'Puedes usar estas credenciales para acceder al panel de administración.'
            )
        )