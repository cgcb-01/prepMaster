"""
Demo settings: SQLite + local filesystem media instead of Postgres/Redis/B2,
so the whole backend can be explored with zero external services. Run with:
    DJANGO_SETTINGS_MODULE=config.settings_demo python manage.py migrate
    DJANGO_SETTINGS_MODULE=config.settings_demo python manage.py seed_demo_data
    DJANGO_SETTINGS_MODULE=config.settings_demo python manage.py runserver
Do not use this in production — no B2, no signed URLs, no Celery/Redis.
"""
from .settings import *  # noqa

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'demo_db.sqlite3',
    }
}

STORAGES = {
    "default": {"BACKEND": "django.core.files.storage.FileSystemStorage"},
    "staticfiles": {"BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage"},
}
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

CELERY_TASK_ALWAYS_EAGER = True  # run "async" tasks synchronously, no worker needed
CHANNEL_LAYERS = {'default': {'BACKEND': 'channels.layers.InMemoryChannelLayer'}}

CORS_ALLOW_ALL_ORIGINS = True
DEBUG = True
