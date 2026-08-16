import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/secure_credential_store.dart';
import '../../../data/remote/kairos_api.dart';
import '../../../data/remote/remote_models.dart';
import '../../../domain/repositories/settings_repository.dart';

enum AuthPhase { initializing, unconfigured, signedOut, authenticated, error }

class AuthState {
  const AuthState({
    required this.phase,
    this.session,
    this.message,
    this.retryable = false,
  });

  const AuthState.initializing() : this(phase: AuthPhase.initializing);

  final AuthPhase phase;
  final RemoteSession? session;
  final String? message;
  final bool retryable;
}

abstract interface class AccessTokenProvider {
  Future<String?> accessToken();
}

class AuthController extends StateNotifier<AuthState>
    implements AccessTokenProvider {
  AuthController({
    required SettingsRepository settings,
    required CredentialStore credentials,
    required KairosApi api,
  }) : _settings = settings,
       _credentials = credentials,
       _api = api,
       super(const AuthState.initializing()) {
    unawaited(initialize());
  }

  static const String _refreshTokenKey = 'refresh_token';

  final SettingsRepository _settings;
  final CredentialStore _credentials;
  final KairosApi _api;

  Future<void> initialize() async {
    final endpoint = await _endpoint();
    if (endpoint == null) {
      state = const AuthState(phase: AuthPhase.unconfigured);
      return;
    }
    final refreshToken = await _credentials.read(_refreshTokenKey);
    if (refreshToken == null) {
      state = const AuthState(phase: AuthPhase.signedOut);
      return;
    }
    await _refresh(endpoint, refreshToken, preserveOnNetworkFailure: true);
  }

  Future<void> login({
    required String username,
    required String password,
    required String deviceId,
    required String deviceName,
  }) async {
    final endpoint = await _endpoint();
    if (endpoint == null) {
      state = const AuthState(
        phase: AuthPhase.unconfigured,
        message: '请先保存同步服务地址',
      );
      return;
    }
    try {
      final session = await _api.login(
        endpoint: endpoint,
        username: username.trim(),
        password: password,
        deviceId: deviceId,
        deviceName: deviceName,
        platform: defaultTargetPlatform.name,
      );
      await _saveSession(session);
    } on ApiFailure catch (error) {
      state = AuthState(
        phase: AuthPhase.error,
        message: error.message,
        retryable: error.retryable,
      );
      rethrow;
    }
  }

  @override
  Future<String?> accessToken() async {
    final session = state.session;
    if (session != null &&
        session.expiresAtUtc.isAfter(
          DateTime.now().toUtc().add(const Duration(minutes: 1)),
        )) {
      return session.accessToken;
    }
    final endpoint = await _endpoint();
    final refreshToken = await _credentials.read(_refreshTokenKey);
    if (endpoint == null || refreshToken == null) {
      return null;
    }
    await _refresh(endpoint, refreshToken, preserveOnNetworkFailure: true);
    return state.session?.accessToken;
  }

  Future<void> logout() async {
    final endpoint = await _endpoint();
    final refreshToken = await _credentials.read(_refreshTokenKey);
    if (endpoint != null && refreshToken != null) {
      try {
        await _api.logout(endpoint: endpoint, refreshToken: refreshToken);
      } on ApiFailure {
        // Local revocation is still required when the server is unavailable.
      }
    }
    await _credentials.delete(_refreshTokenKey);
    state = const AuthState(phase: AuthPhase.signedOut);
  }

  Future<void> endpointChanged() => initialize();

  Future<void> _refresh(
    Uri endpoint,
    String refreshToken, {
    required bool preserveOnNetworkFailure,
  }) async {
    try {
      final session = await _api.refresh(
        endpoint: endpoint,
        refreshToken: refreshToken,
      );
      await _saveSession(session);
    } on ApiFailure catch (error) {
      if (error.statusCode == 401) {
        await _credentials.delete(_refreshTokenKey);
        state = AuthState(phase: AuthPhase.signedOut, message: error.message);
      } else {
        state = AuthState(
          phase: AuthPhase.error,
          session: preserveOnNetworkFailure ? state.session : null,
          message: error.message,
          retryable: error.retryable,
        );
      }
    }
  }

  Future<void> _saveSession(RemoteSession session) async {
    await _credentials.write(_refreshTokenKey, session.refreshToken);
    state = AuthState(phase: AuthPhase.authenticated, session: session);
  }

  Future<Uri?> _endpoint() async {
    final raw = await _settings.readServiceEndpoint();
    return raw == null ? null : Uri.tryParse(raw);
  }
}
