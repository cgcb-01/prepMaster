from django.urls import path
from . import views

urlpatterns = [
    path('me/', views.MyProfileView.as_view(), name='user-me'),
    path('me/class/', views.SwitchClassView.as_view(), name='user-switch-class'),
    path('friends/', views.FriendsListView.as_view(), name='user-friends'),
    path('friends/request/', views.SendFriendRequestView.as_view(), name='user-friend-request'),
    path('friends/request/<int:request_id>/respond/', views.RespondFriendRequestView.as_view(), name='user-friend-respond'),
    path('<int:pk>/', views.PublicProfileView.as_view(), name='user-public-profile'),
]
