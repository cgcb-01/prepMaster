"""
Root router for every admin-authoring endpoint. Mounted at /api/admin/ in
config/urls.py. A native Flutter admin UI (screens/admin/) talks to these;
Django's own /admin/ site (apps/adminpanel/admin.py) is a second, independent
front-end for the same underlying models — staff can use whichever is handy.
"""
from rest_framework.routers import DefaultRouter
from apps.content.admin_api import (
    AdminQuestionViewSet, QuestionCategoryViewSet, SubjectAdminViewSet,
    ChapterAdminViewSet, ModuleAdminViewSet,
)
from apps.exams.admin_api import AdminExamPaperViewSet

router = DefaultRouter()
router.register('questions', AdminQuestionViewSet, basename='admin-question')
router.register('categories', QuestionCategoryViewSet, basename='admin-category')
router.register('subjects', SubjectAdminViewSet, basename='admin-subject')
router.register('chapters', ChapterAdminViewSet, basename='admin-chapter')
router.register('modules', ModuleAdminViewSet, basename='admin-module')
router.register('papers', AdminExamPaperViewSet, basename='admin-paper')

urlpatterns = router.urls
