// lib/services/navigation_service.dart
import 'package:flutter/material.dart';

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  // The current screen name
  String _currentScreen = 'Home';
  String get currentScreen => _currentScreen;

  // List of listeners that get notified when screen changes
  final List<VoidCallback> _listeners = [];

  // Function to navigate to a screen
  void navigateTo(String screen) {
    if (_currentScreen != screen) {
      _currentScreen = screen;
      _notifyListeners();
    }
  }

  // Add a listener (called by main.dart)
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  // Remove a listener
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (var listener in _listeners) {
      listener();
    }
  }
}