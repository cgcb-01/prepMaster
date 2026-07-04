from django.contrib import admin
from django.conf import settings
from django.urls import path, include
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

urlpatterns = [
    path('admin/', admin.site.urls),

    # Auth
    path('api/auth/token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('api/auth/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),

    # Feature apps
    path('api/users/', include('apps.users.urls')),
    path('api/content/', include('apps.content.urls')),
    path('api/exams/', include('apps.exams.urls')),
    path('api/proctoring/', include('apps.proctoring.urls')),
    path('api/sync/', include('apps.sync.urls')),
    path('api/todo/', include('apps.todo.urls')),
    path('api/leaderboard/', include('apps.leaderboard.urls')),
    path('api/rating/', include('apps.rating.urls')),
    path('api/library/', include('apps.library.urls')),

    # Admin authoring API (native admin UI target — separate from /admin/ site)
    path('api/admin/', include('apps.adminpanel.urls')),
]

if settings.DEBUG:
    from django.conf.urls.static import static
    urlpatterns += static(settings.MEDIA_URL, document_root=getattr(settings, 'MEDIA_ROOT', None))
