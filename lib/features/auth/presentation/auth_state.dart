import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/local_storage.dart';

enum AuthStatus { unauthenticated, otpSent, authenticating, authenticated, error }

class AuthState {
  final AuthStatus status;
  final String? email;
  final String? devOtp;
  final String? errorMessage;
  final Map<String, dynamic>? userProfile;

  AuthState({
    required this.status,
    this.email,
    this.devOtp,
    this.errorMessage,
    this.userProfile,
  });

  factory AuthState.initial() {
    final token = LocalStorage.getToken();
    final profile = LocalStorage.getUserProfile();
    if (token != null && profile != null) {
      return AuthState(
        status: AuthStatus.authenticated,
        userProfile: profile,
      );
    }
    return AuthState(status: AuthStatus.unauthenticated);
  }

  AuthState copyWith({
    AuthStatus? status,
    String? email,
    String? devOtp,
    String? errorMessage,
    Map<String, dynamic>? userProfile,
  }) {
    return AuthState(
      status: status ?? this.status,
      email: email ?? this.email,
      devOtp: devOtp ?? this.devOtp,
      errorMessage: errorMessage ?? this.errorMessage,
      userProfile: userProfile ?? this.userProfile,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;

  AuthNotifier(this._apiClient) : super(AuthState.initial()) {
    if (state.status == AuthStatus.authenticated) {
      refreshUserProfile();
    }
  }

  Future<bool> sendOtp(String email) async {
    state = state.copyWith(status: AuthStatus.authenticating);
    try {
      final response = await _apiClient.dio.post('/api/auth/send-otp', data: {
        'email': email.trim().toLowerCase(),
      });

      if (response.data['success'] == true) {
        final otpCode = (response.data['devOtp'] ?? response.data['otp'])?.toString();
        state = state.copyWith(
          status: AuthStatus.otpSent,
          email: email.trim().toLowerCase(),
          devOtp: otpCode,
          errorMessage: null,
        );
        return true;
      } else {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: response.data['message'] ?? 'Failed to send OTP',
        );
        return false;
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? e.response?.data?['message'] ?? 'Network request failed. Please check your connection.';
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: msg,
      );
      return false;
    }
  }

  Future<bool> verifyOtp(String otp) async {
    if (state.email == null) return false;
    state = state.copyWith(status: AuthStatus.authenticating);

    try {
      final response = await _apiClient.dio.post('/api/auth/verify-otp', data: {
        'email': state.email,
        'otp': otp.trim(),
      });

      if (response.data['success'] == true) {
        final data = response.data['data'];
        final token = data['token'];
        final user = data['user'];

        // Save session locally using Hive storage helper
        await LocalStorage.saveSession(token, user);

        state = state.copyWith(
          status: AuthStatus.authenticated,
          userProfile: user,
          errorMessage: null,
        );
        return true;
      } else {
        state = state.copyWith(
          status: AuthStatus.otpSent, // Rollback to otpSent to let user try again
          errorMessage: response.data['error'] ?? response.data['message'] ?? 'Invalid OTP code',
        );
        return false;
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? e.response?.data?['message'] ?? 'Invalid security code. Please try again.';
      state = state.copyWith(
        status: AuthStatus.otpSent,
        errorMessage: msg,
      );
      return false;
    }
  }

  Future<void> updateUserProfile(Map<String, dynamic> updatedFields) async {
    final currentProfile = state.userProfile ?? LocalStorage.getUserProfile() ?? {};
    final newProfile = Map<String, dynamic>.from(currentProfile)..addAll(updatedFields);

    final userEmail = state.email ?? newProfile['email'] ?? currentProfile['email'];
    if (userEmail != null) {
      updatedFields['email'] = userEmail;
    }

    final token = LocalStorage.getToken() ?? '';
    await LocalStorage.saveSession(token, newProfile);

    state = state.copyWith(userProfile: newProfile);

    try {
      await _apiClient.post('/api/auth/profile', data: updatedFields);
    } catch (e) {
      debugPrint('Online profile sync deferred: $e');
    }
  }

  Future<void> refreshUserProfile() async {
    try {
      final response = await _apiClient.dio.get('/api/auth/profile');
      if (response.data['success'] == true && response.data['data'] != null) {
        final freshUser = Map<String, dynamic>.from(response.data['data']);
        final token = LocalStorage.getToken() ?? '';
        await LocalStorage.saveSession(token, freshUser);
        state = state.copyWith(userProfile: freshUser);
      }
    } catch (e) {
      debugPrint('Failed to refresh fresh user profile: $e');
    }
  }

  Future<void> logout() async {
    await LocalStorage.clearSession();
    state = AuthState(status: AuthStatus.unauthenticated);
  }
}

// Riverpod Providers
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthNotifier(apiClient);
});
