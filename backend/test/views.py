# test/views.py
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny, IsAuthenticated
import logging

from .models import TestQuestion
from .serializers import TestQuestionSerializer

logger = logging.getLogger(__name__)

# ---- Import traductor: NO silenciar fallos ----
try:
    from ia.services.groq_translator import translate_text, translate_batch
except Exception as e:
    logger.exception("Fallo importando groq_translator (se usará NO-OP): %s", e)
    def translate_text(text, source, target, **kwargs):
        logger.warning("translate_text NO-OP por fallo de import")
        return text
    def translate_batch(texts, source, target, **kwargs):
        logger.warning("translate_batch NO-OP por fallo de import")
        return texts

# ---- Utils ----
def _norm_lang(lang):
    """
    Normaliza códigos tipo es, es-ES, pt_BR -> es/pt en minúsculas.
    Devuelve None si viene vacío o 'auto'.
    """
    if not lang:
        return None
    l = str(lang).strip().lower()
    if l == "auto":
        return None
    for sep in ("-", "_"):
        if sep in l:
            l = l.split(sep, 1)[0]
            break
    return l

class PlacementQuestionsView(APIView):
    permission_classes = (AllowAny,)

    def get(self, request):
        qs = TestQuestion.objects.prefetch_related('options').all().order_by('order')
        ser = TestQuestionSerializer(qs, many=True)
        data = ser.data

        # Idiomas preferidos
        user = getattr(request, 'user', None)
        native = getattr(user, 'native_language', None) if (user and user.is_authenticated) else None
        target = getattr(user, 'target_language', None) if (user and user.is_authenticated) else None

        # Override por query params
        qp_native = request.query_params.get('native')
        qp_target = request.query_params.get('target')
        if qp_native is not None:
            native = qp_native
        if qp_target is not None:
            target = qp_target

        def _norm_lang(lang):
            if not lang:
                return None
            l = str(lang).strip().lower()
            if l == "auto":
                return None
            for sep in ("-", "_"):
                if sep in l:
                    l = l.split(sep, 1)[0]
                    break
            return l

        n_norm = _norm_lang(native)
        t_norm = _norm_lang(target)

        logger.debug("PlacementQuestionsView params: native=%r->%r target=%r->%r",
                     native, n_norm, target, t_norm)

        # Optimización: evitar llamadas a Groq cuando la pareja de idiomas
        # es nativa 'es' y destino 'en' (traducción innecesaria en nuestro flujo)
        if n_norm == 'es' and t_norm == 'en':
            out = []
            for idx, q in enumerate(data):
                qcopy = dict(q)
                # No traducimos preguntas ni opciones: devolvemos tal cual
                qcopy['question'] = q.get('question')
                out.append(qcopy)
            return Response(out)

        # Nada que traducir
        if not n_norm and not t_norm:
            return Response(data)

        # 1) Enunciados -> idioma nativo (traducir si viene n_norm, incluso si coincide con t_norm)
        if n_norm:
            question_texts = [q['question'] for q in data]
            try:
                q_tr = translate_batch(question_texts, 'auto', n_norm)
            except Exception as e:
                logger.exception("Batch translate questions failed: %s", e)
                q_tr = question_texts
        else:
            q_tr = [q['question'] for q in data]

        # 2) Opciones -> idioma objetivo (traducir si viene t_norm)
        out = []

        # Si no hay traducción objetivo, devolvemos con texto de preguntas ya traducido
        if not t_norm:
            for idx, q in enumerate(data):
                qcopy = dict(q)
                qcopy['question'] = q_tr[idx]
                out.append(qcopy)
            return Response(out)

        # Recolectar todas las opciones en una sola lista para traducir en un único batch
        all_option_texts = []
        option_counts = []  # para reconstruir por pregunta
        for q in data:
            opts = q.get('options') or []
            texts = [o.get('text', '') for o in opts] if isinstance(opts, list) else []
            option_counts.append(len(texts))
            all_option_texts.extend(texts)

        try:
            translated_all = translate_batch(all_option_texts, 'auto', t_norm)
        except Exception as e:
            logger.exception("Batch translate all options failed: %s", e)
            translated_all = all_option_texts

        # Reconstruir las opciones traducidas por pregunta
        idx_offset = 0
        for qidx, q in enumerate(data):
            qcopy = dict(q)
            qcopy['question'] = q_tr[qidx]
            opts = qcopy.get('options') or []
            if isinstance(opts, list) and opts:
                cnt = option_counts[qidx]
                newopts = []
                for i in range(cnt):
                    orig = opts[i]
                    tr_text = translated_all[idx_offset + i] if (idx_offset + i) < len(translated_all) else (orig.get('text') if isinstance(orig, dict) else '')
                    newopts.append({
                        'id': orig.get('id') if isinstance(orig, dict) else None,
                        'text': tr_text,
                        # comenta la línea siguiente en producción si no quieres exponer la solución:
                        'is_correct': orig.get('is_correct', False) if isinstance(orig, dict) else False,
                        'order': orig.get('order') if isinstance(orig, dict) and orig.get('order') is not None else i,
                    })
                qcopy['options'] = newopts
                idx_offset += cnt
            out.append(qcopy)

        return Response(out)



class PlacementSubmitView(APIView):
    """
    Recibe las respuestas del usuario, calcula nivel, guarda en user.level y devuelve el resultado.

    Payload: {
      "answers": [
        { "question_id": int, "selected_index": int } |
        { "question_id": int, "spoken_text": str }
      ]
    }
    """
    permission_classes = (IsAuthenticated,)

    def post(self, request):
        import difflib, re

        def _norm(s: str) -> str:
            s = (s or "").strip().lower()
            s = re.sub(r"[^\w\sáéíóúüñçàèìòùâêîôûäëïöü-]", "", s)
            return " ".join(s.split())

        user = request.user
        data = request.data or {}
        answers = data.get('answers', [])
        if not isinstance(answers, list):
            return Response({'detail': 'Invalid answers'}, status=400)

        # Idioma objetivo para SPEAK
        try:
            target = getattr(user, 'target_language', None) or request.query_params.get('target')
        except Exception:
            target = None
        t_norm = _norm_lang(target)

        total = 0
        correct = 0

        for a in answers:
            try:
                qid = int(a.get('question_id'))
            except Exception:
                continue
            try:
                q = TestQuestion.objects.prefetch_related('options').get(id=qid)
            except TestQuestion.DoesNotExist:
                continue

            total += 1

            if q.qtype == 'choice':
                sel = a.get('selected_index')
                try:
                    sel = int(sel)
                except Exception:
                    sel = None
                opts = list(q.options.all())
                if sel is not None and 0 <= sel < len(opts):
                    if opts[sel].is_correct:
                        correct += 1

            elif q.qtype == 'speak':
                # spoken debe venir en el IDIOMA OBJETIVO
                spoken = _norm(a.get('spoken_text'))

                # Comparamos con las opciones (frase base). Si hay target, traducimos al target antes de comparar.
                matched = False
                opts = q.options.all()
                for opt in opts:
                    expected = opt.text
                    if t_norm:
                        try:
                            expected = translate_text(expected, 'auto', t_norm)
                        except Exception:
                            pass
                    if difflib.SequenceMatcher(None, _norm(expected), spoken).ratio() >= 0.92:
                        matched = True
                        break
                if matched:
                    correct += 1

        if total == 0:
            return Response({'detail': 'No valid answers provided'}, status=400)

        raw = correct
        # Map a nivel
        if total == 5:
            level = 'A1' if raw <= 1 else 'A2' if raw == 2 else 'B1' if raw == 3 else 'B2' if raw == 4 else 'C1'
        else:
            pct = (correct / total) * 100.0
            level = 'A1' if pct <= 20 else 'A2' if pct <= 40 else 'B1' if pct <= 60 else 'B2' if pct <= 80 else 'C1'

        # Guardar nivel en usuario (best effort)
        try:
            user.level = level
            user.save(update_fields=['level'])
        except Exception:
            pass

        return Response({'level': level, 'score': raw, 'total': total})
