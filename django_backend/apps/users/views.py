from rest_framework import views, generics, permissions, status
from rest_framework.response import Response
from django.shortcuts import get_object_or_404

from .models import User, Friendship
from .serializers import (
    PublicProfileSerializer, PrivateProfileSerializer,
    ClassSwitchSerializer, FriendshipSerializer,
)


class MyProfileView(views.APIView):
    """GET /api/users/me/ — full private view for the logged-in user (point #4)."""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        return Response(PrivateProfileSerializer(request.user).data)


class PublicProfileView(generics.RetrieveAPIView):
    """GET /api/users/<id>/ — public view for viewing anyone's dashboard."""
    queryset = User.objects.all()
    serializer_class = PublicProfileSerializer
    permission_classes = [permissions.IsAuthenticated]


class SwitchClassView(views.APIView):
    """POST /api/users/me/class/ { student_class: '11' } — point #4."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = ClassSwitchSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        request.user.student_class = serializer.validated_data['student_class']
        request.user.save(update_fields=['student_class'])
        return Response({'ok': True, 'student_class': request.user.student_class})


class SendFriendRequestView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        to_user = get_object_or_404(User, id=request.data.get('to_user_id'))
        fr, created = Friendship.objects.get_or_create(from_user=request.user, to_user=to_user)
        return Response(FriendshipSerializer(fr).data, status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)


class RespondFriendRequestView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, request_id):
        fr = get_object_or_404(Friendship, id=request_id, to_user=request.user)
        action = request.data.get('action')  # 'accept' | 'decline'
        if action == 'accept':
            fr.status = 'ACCEPTED'
            fr.save(update_fields=['status'])
        elif action == 'decline':
            fr.delete()
            return Response({'ok': True})
        return Response(FriendshipSerializer(fr).data)


class FriendsListView(generics.ListAPIView):
    serializer_class = PublicProfileSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        u = self.request.user
        ids = list(Friendship.objects.filter(from_user=u, status='ACCEPTED').values_list('to_user_id', flat=True))
        ids += list(Friendship.objects.filter(to_user=u, status='ACCEPTED').values_list('from_user_id', flat=True))
        return User.objects.filter(id__in=ids)


class RegisterView(views.APIView):
    """POST /api/auth/register/ — creates the account and returns JWT
    tokens immediately (auto-login), same shape as /api/auth/token/."""
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        from rest_framework_simplejwt.tokens import RefreshToken
        from .serializers import RegisterSerializer

        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()

        refresh = RefreshToken.for_user(user)
        return Response({
            'access': str(refresh.access_token),
            'refresh': str(refresh),
        }, status=status.HTTP_201_CREATED)
