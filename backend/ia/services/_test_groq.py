# Small smoke test for groq_translator.translate_text
if __name__ == '__main__':
    from ia.services.groq_translator import translate_text
    print('Translating hello->es (fallback or groq):')
    out = translate_text('Hello, how are you?', source='auto', target='es')
    print(out)
