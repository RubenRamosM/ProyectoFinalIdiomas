import subprocess
import sys

def check_ffmpeg():
    """Verifica si ffmpeg está disponible en el sistema"""
    try:
        result = subprocess.run(
            ['ffmpeg', '-version'],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            version_line = result.stdout.split('\n')[0]
            print(f"✓ FFmpeg encontrado: {version_line}")
            return True
        else:
            print("✗ FFmpeg no respondió correctamente")
            return False
    except FileNotFoundError:
        print("✗ FFmpeg NO está instalado")
        print("\nPara instalar FFmpeg:")
        print("  Windows: choco install ffmpeg (con Chocolatey)")
        print("          o descarga desde https://ffmpeg.org/download.html")
        print("  Linux: sudo apt install ffmpeg")
        print("  macOS: brew install ffmpeg")
        return False
    except Exception as e:
        print(f"✗ Error al verificar FFmpeg: {e}")
        return False

if __name__ == "__main__":
    print("=== Verificación de FFmpeg ===\n")
    if check_ffmpeg():
        print("\n✓ El sistema está listo para procesar audio")
        sys.exit(0)
    else:
        print("\n⚠ Instala FFmpeg para habilitar transcripción de audio")
        sys.exit(1)
