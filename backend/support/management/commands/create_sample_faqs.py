from django.core.management.base import BaseCommand
from support.models import FAQ


class Command(BaseCommand):
    help = 'Crea FAQs de ejemplo para el sistema de soporte'

    def handle(self, *args, **kwargs):
        faqs_data = [
            # General
            {
                'question': '¿Qué es Idiomas App?',
                'answer': 'Idiomas App es una aplicación de aprendizaje de idiomas que utiliza inteligencia artificial para mejorar tu pronunciación y comprensión. Ofrecemos lecciones adaptativas, ejercicios interactivos y retroalimentación en tiempo real.',
                'category': 'general',
                'order': 1
            },
            {
                'question': '¿Qué idiomas puedo aprender?',
                'answer': 'Actualmente ofrecemos cursos de inglés con más idiomas en desarrollo. Nuestra metodología se enfoca en la práctica oral y la pronunciación correcta.',
                'category': 'general',
                'order': 2
            },
            {
                'question': '¿La aplicación funciona sin conexión a internet?',
                'answer': 'Algunas funciones básicas están disponibles sin conexión, pero para la retroalimentación de pronunciación y sincronización de progreso necesitas estar conectado a internet.',
                'category': 'general',
                'order': 3
            },

            # Cuenta y Perfil
            {
                'question': '¿Cómo creo una cuenta?',
                'answer': 'En la pantalla de inicio, selecciona "Registrarse". Completa el formulario con tu nombre de usuario, correo electrónico y contraseña. Luego verifica tu cuenta siguiendo las instrucciones en el correo de confirmación.',
                'category': 'account',
                'order': 1
            },
            {
                'question': '¿Cómo cambio mi contraseña?',
                'answer': 'Ve a tu Perfil > Configuración > Cambiar contraseña. Ingresa tu contraseña actual y luego la nueva contraseña dos veces para confirmar.',
                'category': 'account',
                'order': 2
            },
            {
                'question': '¿Puedo usar mi cuenta en múltiples dispositivos?',
                'answer': 'Sí, puedes iniciar sesión con tu cuenta en todos tus dispositivos. Tu progreso se sincroniza automáticamente cuando estás conectado a internet.',
                'category': 'account',
                'order': 3
            },

            # Lecciones
            {
                'question': '¿Cómo funcionan las lecciones adaptativas?',
                'answer': 'Nuestro sistema analiza tu desempeño en cada ejercicio y ajusta la dificultad automáticamente. Si tienes dificultades, te presenta ejercicios más simples. Si dominas un tema, avanza a contenido más desafiante.',
                'category': 'lessons',
                'order': 1
            },
            {
                'question': '¿Qué tipos de ejercicios hay disponibles?',
                'answer': 'Ofrecemos varios tipos: opción múltiple, traducción, pronunciación y shadowing (repetición). Cada tipo desarrolla diferentes habilidades lingüísticas.',
                'category': 'lessons',
                'order': 2
            },
            {
                'question': '¿Puedo repetir una lección?',
                'answer': 'Sí, puedes repetir cualquier lección las veces que quieras. Esto te ayuda a reforzar conceptos y mejorar tu puntuación.',
                'category': 'lessons',
                'order': 3
            },

            # Técnico
            {
                'question': 'La aplicación no reconoce mi voz correctamente',
                'answer': 'Asegúrate de estar en un lugar silencioso y habla claramente cerca del micrófono. Verifica que hayas dado permisos de micrófono a la aplicación en la configuración de tu dispositivo. Si el problema persiste, intenta reiniciar la aplicación.',
                'category': 'technical',
                'order': 1
            },
            {
                'question': '¿Por qué no se carga mi progreso?',
                'answer': 'Verifica tu conexión a internet. El progreso se sincroniza automáticamente cuando estás conectado. Si el problema persiste, intenta cerrar sesión y volver a iniciar sesión.',
                'category': 'technical',
                'order': 2
            },
            {
                'question': 'La aplicación se cierra inesperadamente',
                'answer': 'Intenta actualizar la aplicación a la última versión. Si el problema continúa, limpia el caché de la aplicación o reinstálala. Si nada funciona, contacta a soporte técnico con los detalles de tu dispositivo.',
                'category': 'technical',
                'order': 3
            },

            # Pagos
            {
                'question': '¿La aplicación es gratuita?',
                'answer': 'Ofrecemos una versión gratuita con acceso a lecciones básicas. Para acceder a todo el contenido y funciones premium, puedes suscribirte a nuestro plan mensual o anual.',
                'category': 'payment',
                'order': 1
            },
            {
                'question': '¿Cómo cancelo mi suscripción?',
                'answer': 'Ve a Perfil > Suscripción > Cancelar suscripción. Tu suscripción permanecerá activa hasta el final del período pagado.',
                'category': 'payment',
                'order': 2
            },
        ]

        created_count = 0
        updated_count = 0

        for faq_data in faqs_data:
            faq, created = FAQ.objects.update_or_create(
                question=faq_data['question'],
                defaults=faq_data
            )
            if created:
                created_count += 1
            else:
                updated_count += 1

        self.stdout.write(
            self.style.SUCCESS(
                f'FAQs creadas exitosamente: {created_count} nuevas, {updated_count} actualizadas'
            )
        )
