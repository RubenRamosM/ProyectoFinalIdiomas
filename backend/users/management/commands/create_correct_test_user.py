from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from users.models import LearningStats

User = get_user_model()

class Command(BaseCommand):
    help = 'Crea un usuario de prueba con el patrón de correo/username correcto'

    def add_arguments(self, parser):
        parser.add_argument('--username', type=str, default='testuser', help='Nombre de usuario')
        parser.add_argument('--email', type=str, default='testuser@example.com', help='Email del usuario')
        parser.add_argument('--password', type=str, default='TestPassword123!', help='Contraseña del usuario')
        parser.add_argument('--first-name', type=str, default='Test', help='Nombre del usuario')
        parser.add_argument('--last-name', type=str, default='User', help='Apellido del usuario')

    def handle(self, *args, **options):
        username = options['username']
        email = options['email']
        password = options['password']
        first_name = options['first_name']
        last_name = options['last_name']
        
        # Extraer el nombre de usuario del email
        expected_username = email.split('@')[0]
        
        if username != expected_username:
            self.stdout.write(
                self.style.WARNING(
                    f'Advertencia: El username "{username}" no coincide con la parte del email "{expected_username}".\n'
                    f'La app intentará autenticar con "{expected_username}" si introduces "{email}" en el campo de correo.'
                )
            )
        
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
            first_name=first_name,
            last_name=last_name,
            native_language='es',
            target_language='en',
            age=25,
            level='A1'
        )
        
        # Crear estadísticas de aprendizaje
        LearningStats.objects.create(user=user)
        
        self.stdout.write(
            self.style.SUCCESS(
                f'Usuario de prueba creado exitosamente!\n'
                f'Username: {username}\n'
                f'Email: {email}\n'
                f'Contraseña: {password}\n'
                f'Para iniciar sesión en la app:\n'
                f'  - Campo correo: {email}\n'
                f'  - Campo contraseña: {password}'
            )
        )