// lib/providers/auth_provider.dart - UPDATED
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _user;
  bool _isLoading = false;
  bool _isLoggedIn = false;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;

  // Initialize - check if user is logged in
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    _isLoggedIn = await _authService.isLoggedIn();
    if (_isLoggedIn) {
      final result = await getProfile(); // Get fresh user data
      if (!result['success']) {
        // If token is invalid, logout
        await logout();
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  // Register - UPDATED: Don't auto-login
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    final result = await _authService.register(
      name: name,
      email: email,
      password: password,
    );

    // ⚠️ DON'T auto-login after registration
    // User must login with their credentials
    if (result['success']) {
      // Clear any existing login session
      await _authService.logout();
      _user = null;
      _isLoggedIn = false;
    }

    _isLoading = false;
    notifyListeners();

    return result;
  }

  // Login - UPDATED: Set user data
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    final result = await _authService.login(
      email: email,
      password: password,
    );

    if (result['success']) {
      _user = result['user'];
      _isLoggedIn = true;
    }

    _isLoading = false;
    notifyListeners();

    return result;
  }

  // Get user profile
  Future<Map<String, dynamic>> getProfile() async {
    _isLoading = true;
    notifyListeners();

    final result = await _authService.getProfile();

    if (result['success']) {
      _user = result['user'];
      _isLoggedIn = true;
    } else {
      _isLoggedIn = false;
      _user = null;
    }

    _isLoading = false;
    notifyListeners();

    return result;
  }

  // Logout
  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    _isLoggedIn = false;
    notifyListeners();
  }
}