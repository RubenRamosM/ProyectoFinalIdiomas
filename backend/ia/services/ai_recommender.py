# ia/services/ai_recommender.py
from typing import List, Tuple, Optional
import numpy as np
from django.db import transaction

from ia.models import ExerciseEmbedding, ExerciseAttempt, UserWeakness, RecommendationQueue
from leccion.models import Exercise, ExerciseOption, Lesson

from ia.services.embeddings import encode_texts, to_bytes, from_bytes

# =======================
# Helpers de texto/contexto
# =======================

def _exercise_text(ex: Exercise) -> str:
    lesson: Optional[Lesson] = getattr(ex, "lesson", None)
    parts: List[str] = []
    if lesson:
        # Try to obtain a localized view (native/target codes, title, content)
        loc = None
        try:
            # Prefer exercise localization (more specific to this exercise)
            loc = getattr(ex, 'localizations', None)
            if loc is not None:
                loc = loc.first()
        except Exception:
            loc = None
        if not loc:
            try:
                locs = getattr(lesson, 'localizations', None)
                if locs is not None:
                    loc = locs.first()
            except Exception:
                loc = None

        # Build header with available lesson/meta/localization info
        lvl = getattr(lesson, 'level', None)
        ltype = getattr(lesson, 'lesson_type', None)
        tlang = None
        nlang = None
        if loc:
            try:
                tlang = getattr(loc.target_language, 'code', None)
            except Exception:
                tlang = None
            try:
                nlang = getattr(loc.native_language, 'code', None)
            except Exception:
                nlang = None

        header_parts = []
        if lvl:
            header_parts.append(f"LEVEL:{lvl}")
        if ltype:
            header_parts.append(f"TYPE:{ltype}")
        if tlang:
            header_parts.append(f"TL:{tlang}")
        if nlang:
            header_parts.append(f"NL:{nlang}")
        if header_parts:
            parts.append("[" + "] [".join(header_parts) + "]")

        # Localized title/content if available
        if loc and getattr(loc, 'title', None):
            parts.append(loc.title)
        else:
            # fallback to any lesson-level title/content fields if present
            if getattr(lesson, 'title', None):
                parts.append(getattr(lesson, 'title'))
        if loc and getattr(loc, 'content', None):
            parts.append(loc.content[:500])
        else:
            if getattr(lesson, 'content', None):
                parts.append(getattr(lesson, 'content')[:500])
    parts.append(f"[EX_TYPE:{ex.exercise_type}]")
    
    # Get question, instructions, and options from localizations (Exercise doesn't have these fields directly)
    try:
        first_loc = ex.localizations.first()
        if first_loc:
            if first_loc.question:
                parts.append(first_loc.question)
            if first_loc.instructions:
                parts.append(first_loc.instructions)
            # Get options from the localization
            opts = list(first_loc.options.all().values_list("text", flat=True))
            if opts:
                parts.append("OPCIONES: " + " | ".join(str(o) for o in opts[:16]))
    except Exception:
        pass
    
    return "\n".join([p for p in parts if p]).strip()

def _topic_of(ex: Exercise) -> str:
    les = getattr(ex, "lesson", None)
    return getattr(les, "lesson_type", "") or "general"

def _skill_of(ex: Exercise) -> str:
    t = ex.exercise_type
    if t in ("pronunciation", "shadowing", "speaking"):
        return "speaking"
    if t in ("translation", "fill_blank", "word_formation"):
        return "writing"
    if t in ("audio_listening",):
        return "listening"
    if t in ("multiple_choice", "true_false", "matching", "ordering", "drag_drop"):
        return "reading"
    return "general"

def _lesson_meta(ex: Exercise):
    les = getattr(ex, "lesson", None)
    # Try to find localization to extract language codes if the Lesson model
    # doesn't have native/target language attributes (they live in LessonLocalization).
    tlang = None
    nlang = None
    ltype = None
    seq = None
    level = None
    if les:
        level = getattr(les, 'level', None)
        ltype = getattr(les, 'lesson_type', None)
        seq = getattr(les, 'sequence', None)
        try:
            locs = getattr(les, 'localizations', None)
            if locs is not None:
                first = locs.first()
                if first is not None:
                    tlang = getattr(first.target_language, 'code', None)
                    nlang = getattr(first.native_language, 'code', None)
        except Exception:
            tlang = None
            nlang = None
    return {
        "level": level,
        "tlang": tlang,
        "nlang": nlang,
        "ltype": ltype,
        "seq": seq,
    }

def _human_reason(topic_code: str) -> str:
    MAP = {
        "vocabulary":    "Vocabulario de saludos/frases útiles",
        "grammar":       "Gramática del tema",
        "conversation":  "Conversación básica del tema",
        "pronunciation": "Pronunciación y entonación",
        "shadowing":     "Shadowing de diálogos",
        "general":       "Conceptos similares",
    }
    return MAP.get(topic_code or "general", "Conceptos similares")

# =======================
# Indexación
# =======================

def index_exercise(ex: Exercise) -> None:
    text = _exercise_text(ex)
    if not text:
        return
    emb = encode_texts([text])[0]
    ExerciseEmbedding.objects.update_or_create(
        exercise=ex,
        defaults={"vector": to_bytes(emb), "dim": int(emb.shape[0])},
    )

def bulk_index_all() -> int:
    qs = (Exercise.objects
          .select_related("lesson")
          .prefetch_related("localizations", "localizations__options")
          .all())
    ex_list = list(qs)
    total = 0
    BATCH = 128
    for i in range(0, len(ex_list), BATCH):
        batch = ex_list[i:i+BATCH]
        texts = [_exercise_text(e) for e in batch]
        mask = [bool(t) for t in texts]
        if not any(mask):
            continue
        embs = encode_texts([t for t, m in zip(texts, mask) if m])
        j = 0
        with transaction.atomic():
            for e, m in zip(batch, mask):
                if not m:
                    continue
                v = embs[j]; j += 1
                ExerciseEmbedding.objects.update_or_create(
                    exercise=e,
                    defaults={"vector": to_bytes(v), "dim": int(v.shape[0])},
                )
                total += 1
    return total

# =======================
# Similaridad + filtros + MMR
# =======================

def _candidate_queryset(base_ex: Exercise,
                        same_topic_only: bool,
                        same_type_only: bool):
    base = _lesson_meta(base_ex)
    qs = (Exercise.objects
          .exclude(id=base_ex.id)
          .select_related("lesson"))
    # filtros fuertes
    if base["level"]:
        qs = qs.filter(lesson__level=base["level"])
    # Languages are stored in LessonLocalization; filter via related localizations
    if base["tlang"]:
        qs = qs.filter(lesson__localizations__target_language__code=base["tlang"])
    if base["nlang"]:
        qs = qs.filter(lesson__localizations__native_language__code=base["nlang"])
    if same_topic_only and base["ltype"]:
        qs = qs.filter(lesson__lesson_type=base["ltype"])
    if same_type_only:
        qs = qs.filter(exercise_type=base_ex.exercise_type)
    return qs

def _cos(a: np.ndarray, b: np.ndarray) -> float:
    denom = (np.linalg.norm(a) * np.linalg.norm(b)) or 1e-8
    return float(np.dot(a, b) / denom)

def _mmr_select(query_vec: np.ndarray,
                cand_vecs: List[np.ndarray],
                cand_objs: List[Exercise],
                k: int,
                lamb: float = 0.7) -> List[Tuple[Exercise, float]]:
    selected: List[Tuple[Exercise, float]] = []
    selected_vecs: List[np.ndarray] = []
    remaining = list(range(len(cand_vecs)))
    q_sims = [_cos(query_vec, v) for v in cand_vecs]
    while remaining and len(selected) < k:
        best_i, best_score = None, -1e9
        for i in remaining:
            max_sim_to_sel = max((_cos(cand_vecs[i], sv) for sv in selected_vecs), default=0.0)
            score = lamb * q_sims[i] - (1 - lamb) * max_sim_to_sel
            if score > best_score:
                best_score, best_i = score, i
        selected.append((cand_objs[best_i], q_sims[best_i]))
        selected_vecs.append(cand_vecs[best_i])
        remaining.remove(best_i)
    selected.sort(key=lambda x: x[1], reverse=True)
    return selected

def _similar_core(base_ex: Exercise,
                  top_k: int,
                  same_topic_only: bool,
                  same_type_only: bool,
                  min_sim: float,
                  mmr_lambda: float,
                  query_text: Optional[str] = None) -> List[Tuple[Exercise, float]]:
    # vector base
    # If a query_text is provided (for example the user's wrong answer), encode it
    # and use it as the query vector. Otherwise use the exercise's embedding.
    if query_text:
        try:
            q = encode_texts([query_text])[0]
        except Exception:
            # fallback to exercise embedding
            try:
                ee = ExerciseEmbedding.objects.get(exercise=base_ex)
            except ExerciseEmbedding.DoesNotExist:
                # Refetch with localizations if needed
                base_ex = Exercise.objects.prefetch_related('localizations', 'localizations__options').get(id=base_ex.id)
                index_exercise(base_ex)
                try:
                    ee = ExerciseEmbedding.objects.get(exercise=base_ex)
                except ExerciseEmbedding.DoesNotExist:
                    return []
            q = from_bytes(ee.vector, ee.dim)
    else:
        try:
            ee = ExerciseEmbedding.objects.get(exercise=base_ex)
        except ExerciseEmbedding.DoesNotExist:
            # Refetch with localizations if needed
            base_ex = Exercise.objects.prefetch_related('localizations', 'localizations__options').get(id=base_ex.id)
            index_exercise(base_ex)
            try:
                ee = ExerciseEmbedding.objects.get(exercise=base_ex)
            except ExerciseEmbedding.DoesNotExist:
                return []
        q = from_bytes(ee.vector, ee.dim)

    # candidatos
    cand_qs = _candidate_queryset(base_ex, same_topic_only=same_topic_only, same_type_only=same_type_only)
    emb_map = {
        e.exercise_id: e
        for e in ExerciseEmbedding.objects.filter(
            exercise__in=cand_qs.values_list("id", flat=True)
        ).select_related("exercise__lesson")
    }
    if not emb_map:
        return []

    cand_vecs, cand_objs = [], []
    for emb in emb_map.values():
        v = from_bytes(emb.vector, emb.dim)
        sim = _cos(q, v)
        if sim >= min_sim:
            cand_vecs.append(v)
            cand_objs.append(emb.exercise)
    if not cand_vecs:
        return []

    return _mmr_select(q, cand_vecs, cand_objs, k=min(top_k, len(cand_vecs)), lamb=mmr_lambda)

def similar_exercises(base_ex: Exercise,
                      top_k: int = 20,
                      min_sim: float = 0.50,
                      mmr_lambda: float = 0.7,
                      query_text: Optional[str] = None) -> List[Tuple[Exercise, float]]:
    """
    Estrategia en tres pasos:
      1) mismo tipo + mismo tema
      2) mismo tema (relaja tipo)
      3) mixto (relaja tema y tipo) — último recurso
    """
    # 1) mismo tipo + mismo tema
    sel = _similar_core(base_ex, top_k, same_topic_only=True,  same_type_only=True,  min_sim=min_sim, mmr_lambda=mmr_lambda, query_text=query_text)
    if sel:
        return sel[:top_k]
    # 2) mismo tema, distinto tipo permitido
    sel = _similar_core(base_ex, top_k, same_topic_only=True,  same_type_only=False, min_sim=min_sim, mmr_lambda=mmr_lambda, query_text=query_text)
    if sel:
        return sel[:top_k]
    # 3) mixto
    sel = _similar_core(base_ex, top_k, same_topic_only=False, same_type_only=False, min_sim=min_sim, mmr_lambda=mmr_lambda, query_text=query_text)
    return sel[:top_k]

# =======================
# Debilidades + cola
# =======================

def _update_weakness(user, ex: Exercise, is_correct: bool) -> UserWeakness:
    uw, _ = UserWeakness.objects.get_or_create(
        user=user,
        topic=_topic_of(ex),
        skill=_skill_of(ex),
    )
    uw.attempts += 1
    if not is_correct:
        uw.errors += 1
    uw.error_rate = uw.errors / max(1, uw.attempts)
    uw.priority = min(1.0, max(0.0, uw.priority + (0.5 if not is_correct else -0.1)))
    uw.save(update_fields=["attempts", "errors", "error_rate", "priority"])
    return uw

def record_attempt(user, exercise: Exercise, is_correct: bool, score=None, topic=None, skill=None, user_answer=None) -> None:
    ExerciseAttempt.objects.create(
        user=user,
        exercise=exercise,
        is_correct=is_correct,
        score=score if isinstance(score, (int, float)) else None,
        user_answer=user_answer,
        topic=topic or _topic_of(exercise),
        skill=skill or _skill_of(exercise),
    )
    uw = _update_weakness(user, exercise, is_correct)

    if not is_correct:
        seen_ids = set(ExerciseAttempt.objects.filter(user=user)
                       .values_list("exercise_id", flat=True))

        # Use the user's wrong answer as query_text when available to bias similar
        # exercises toward the concepts present in the user's response.
        sims = similar_exercises(
            exercise,
            top_k=30,
            min_sim=0.50,
            mmr_lambda=0.7,
            query_text=(user_answer.strip() if isinstance(user_answer, str) and user_answer.strip() else None),
        )

        created = 0
        reason = _human_reason(_topic_of(exercise))
        base_meta = _lesson_meta(exercise)
        for ex2, sim in sims:
            if ex2.id in seen_ids:
                continue
                # Exercise model stores question text in related localizations.
                def _loc_question(e: Exercise) -> str:
                    try:
                        loc = getattr(e, 'localizations', None)
                        if loc is None:
                            return ''
                        first = loc.first()
                        if not first:
                            return ''
                        return (getattr(first, 'question', '') or '').strip()
                    except Exception:
                        return ''

                q_ex2 = _loc_question(ex2)
                q_base = _loc_question(exercise)
                if q_ex2 and q_base and q_ex2.lower() == q_base.lower():
                    continue
            if RecommendationQueue.objects.filter(user=user, exercise=ex2, served=False).exists():
                continue

            meta = _lesson_meta(ex2)
            seq_boost = 0.1 if (base_meta["seq"] and meta["seq"] and abs(int(base_meta["seq"]) - int(meta["seq"])) <= 10) else 0.0
            final_score = 0.72 * sim + 0.25 * uw.priority + seq_boost

            RecommendationQueue.objects.create(
                user=user,
                exercise=ex2,
                reason=reason,
                score=float(final_score),
            )
            created += 1
            if created >= 10:
                break

# =======================
# Entregables (pendientes)
# =======================

def due_srs_for(user, limit: int = 10):
    # 1) Cola existente
    recs = list(RecommendationQueue.objects
                .filter(user=user, served=False)
                .select_related("exercise__lesson")
                .order_by("-score")[:limit])
    if recs:
        return [r.exercise for r in recs]

    # 2) Último fallo → similares (mismo tipo si se puede)
    last_fail = (ExerciseAttempt.objects
                 .filter(user=user, is_correct=False)
                 .select_related("exercise__lesson")
                 .order_by("-created_at").first())
    if last_fail:
        sims = similar_exercises(last_fail.exercise, top_k=limit, min_sim=0.50, mmr_lambda=0.65)
        if sims:
            return [e for e, _ in sims]

    # 3) Topic más débil del usuario, mismo nivel
    weak = (UserWeakness.objects.filter(user=user)
            .order_by("-priority", "-error_rate").first())
    if weak:
        lvl = getattr(getattr(getattr(last_fail, "exercise", None), "lesson", None), "level", None)
        qs = Exercise.objects.filter(
            lesson__lesson_type=weak.topic,
            **({"lesson__level": lvl} if lvl else {})
        ).order_by("lesson__sequence", "id")[:limit]
        if qs:
            return list(qs)

    # 4) Fallback final: primeros N
    return list(Exercise.objects.order_by("lesson__sequence", "id")[:limit])


# =======================
# Paraphrase / synthetic question helpers
# =======================
def generate_paraphrases(text: str, n: int = 3) -> List[str]:
    """
    Intenta generar paráfrasis del texto usando un modelo T5 si está disponible.
    Si no está disponible, devuelve lista vacía para que el sistema siga funcionando.
    """
    if not text:
        return []
    try:
        # Import lazily to avoid hard dependency
        from transformers import AutoModelForSeq2SeqLM, AutoTokenizer
        name = "ramsrigouthamg/t5_paraphraser"
        tok = AutoTokenizer.from_pretrained(name)
        mod = AutoModelForSeq2SeqLM.from_pretrained(name)
        inpt = "paraphrase: " + text
        inputs = tok.encode(inpt, return_tensors="pt", truncation=True)
        outs = mod.generate(inputs, max_length=256, num_return_sequences=min(6, max(1, n)), do_sample=True, top_p=0.95)
        paraphrases = [tok.decode(o, skip_special_tokens=True).strip() for o in outs]
        # Deduplicate and limit
        seen = set()
        res = []
        for p in paraphrases:
            if p and p not in seen:
                seen.add(p)
                res.append(p)
            if len(res) >= n:
                break
        return res
    except Exception:
        # No paraphraser available or failure: return empty to be safe
        return []


def generate_similar_questions(ex: Exercise, n: int = 3) -> List[dict]:
    """Genera preguntas sintéticas relacionadas a un ejercicio.

    Devuelve una lista de dicts con la forma:
      { 'type': 'synthetic', 'text': ..., 'source_exercise_id': ... }
    No persiste nada en la BD.
    """
    base = _exercise_text(ex)
    paras = generate_paraphrases(base, n=n)
    results = []
    for p in paras:
        results.append({
            "type": "synthetic",
            "text": p,
            "source_exercise_id": ex.id,
        })
    return results


def recommend_for_user(user, limit: int = 10) -> dict:
    """Devuelve recomendaciones para el usuario.

    Resultado: { 'exercises': [Exercise,...], 'synthetic': [dict,...] }
    Primero usa la cola (`RecommendationQueue`). Si no hay suficientes, usa `due_srs_for`.
    Añade además preguntas sintéticas generadas desde los ejercicios principales.
    """
    recs = list(RecommendationQueue.objects.filter(user=user, served=False).order_by('-score')[:limit])
    exercises = [r.exercise for r in recs]

    if len(exercises) < limit:
        needed = limit - len(exercises)
        more = due_srs_for(user, limit=needed)
        for e in more:
            if e.id not in [ex.id for ex in exercises]:
                exercises.append(e)
                if len(exercises) >= limit:
                    break

    # Generate some synthetic questions based on top exercises to reinforce weaknesses
    synthetic = []
    for e in exercises[:min(5, len(exercises))]:
        synthetic.extend(generate_similar_questions(e, n=2))
        if len(synthetic) >= limit:
            break

    # Truncate to requested limits
    return {
        'exercises': exercises[:limit],
        'synthetic': synthetic[:limit]
    }
