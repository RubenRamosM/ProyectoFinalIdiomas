# ia/tasks.py
from celery import shared_task

@shared_task
def task_reindex_all_exercises():
    from ia.services.ai_recommender import bulk_index_all  # lazy import
    return bulk_index_all()
