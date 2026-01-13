from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model

User = get_user_model()


class Command(BaseCommand):
    help = 'Crea un superusuario para el panel de administracion de Django'

    def handle(self, *args, **options):
        username = 'admin'
        email = 'admin@idiomasapp.com'
        password = 'Admin1234'

        # Verificar si el superusuario ya existe
        if User.objects.filter(username=username).exists():
            user = User.objects.get(username=username)
            user.set_password(password)
            user.is_staff = True
            user.is_superuser = True
            user.save()
            self.stdout.write(
                self.style.WARNING(f'[ACTUALIZADO] Superusuario ya existia y fue actualizado')
            )
        else:
            User.objects.create_superuser(
                username=username,
                email=email,
                password=password
            )
            self.stdout.write(
                self.style.SUCCESS(f'[OK] Superusuario creado exitosamente')
            )

        self.stdout.write('')
        self.stdout.write(self.style.SUCCESS('=== Credenciales del Superusuario ==='))
        self.stdout.write(f'Username: {username}')
        self.stdout.write(f'Email: {email}')
        self.stdout.write(f'Password: {password}')
        self.stdout.write('')
        self.stdout.write('Puedes acceder al panel de admin en: http://localhost:8000/admin/')
