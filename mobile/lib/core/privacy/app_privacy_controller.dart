import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final Provider<AppPrivacyStore> appPrivacyStoreProvider =
    Provider<AppPrivacyStore>((ref) => SecureAppPrivacyStore());

final Provider<DeviceAuthenticator> deviceAuthenticatorProvider =
    Provider<DeviceAuthenticator>((ref) => MethodChannelDeviceAuthenticator());

final NotifierProvider<AppPrivacyController, AppPrivacyState>
appPrivacyControllerProvider =
    NotifierProvider<AppPrivacyController, AppPrivacyState>(
      AppPrivacyController.new,
    );

final class AppPrivacyState {
  const AppPrivacyState({
    required this.ready,
    required this.enabled,
    required this.locked,
    required this.available,
    this.errorMessage,
  });

  const AppPrivacyState.loading()
    : ready = false,
      enabled = false,
      locked = false,
      available = false,
      errorMessage = null;

  final bool ready;
  final bool enabled;
  final bool locked;
  final bool available;
  final String? errorMessage;

  AppPrivacyState copyWith({
    bool? ready,
    bool? enabled,
    bool? locked,
    bool? available,
    String? errorMessage,
    bool clearError = false,
  }) => AppPrivacyState(
    ready: ready ?? this.ready,
    enabled: enabled ?? this.enabled,
    locked: locked ?? this.locked,
    available: available ?? this.available,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
  );
}

abstract interface class AppPrivacyStore {
  Future<bool> readLockEnabled();
  Future<void> writeLockEnabled(bool enabled);
}

final class SecureAppPrivacyStore implements AppPrivacyStore {
  SecureAppPrivacyStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'planit.privacy.app_lock.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<bool> readLockEnabled() async {
    try {
      return await _storage.read(key: _key) == 'true';
    } on Object {
      return false;
    }
  }

  @override
  Future<void> writeLockEnabled(bool enabled) async {
    await _storage.write(key: _key, value: enabled ? 'true' : 'false');
  }
}

abstract interface class DeviceAuthenticator {
  Future<bool> isAvailable();
  Future<bool> authenticate();
}

final class MethodChannelDeviceAuthenticator implements DeviceAuthenticator {
  static const _channel = MethodChannel('com.abrghaze.planit/privacy_lock');

  @override
  Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('canAuthenticate') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> authenticate() async {
    try {
      return await _channel.invokeMethod<bool>('authenticate') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

final class AppPrivacyController extends Notifier<AppPrivacyState> {
  @override
  AppPrivacyState build() {
    unawaited(_load());
    return const AppPrivacyState.loading();
  }

  Future<void> _load() async {
    final available = await ref.read(deviceAuthenticatorProvider).isAvailable();
    final enabled = available && await ref.read(appPrivacyStoreProvider).readLockEnabled();
    state = AppPrivacyState(
      ready: true,
      enabled: enabled,
      locked: enabled,
      available: available,
    );
  }

  Future<bool> enable() async {
    if (!state.available) {
      state = state.copyWith(
        errorMessage: 'Set up a screen lock or fingerprint on this phone first.',
      );
      return false;
    }
    final unlocked = await ref.read(deviceAuthenticatorProvider).authenticate();
    if (!unlocked) {
      state = state.copyWith(
        errorMessage: 'PlanIT could not confirm your device unlock.',
      );
      return false;
    }
    await ref.read(appPrivacyStoreProvider).writeLockEnabled(true);
    state = state.copyWith(enabled: true, locked: false, clearError: true);
    return true;
  }

  Future<bool> disable() async {
    if (!state.enabled) return true;
    final unlocked = await ref.read(deviceAuthenticatorProvider).authenticate();
    if (!unlocked) {
      state = state.copyWith(
        errorMessage: 'Unlock PlanIT before turning off the app lock.',
      );
      return false;
    }
    await ref.read(appPrivacyStoreProvider).writeLockEnabled(false);
    state = state.copyWith(enabled: false, locked: false, clearError: true);
    return true;
  }

  Future<bool> unlock() async {
    if (!state.enabled) return true;
    final unlocked = await ref.read(deviceAuthenticatorProvider).authenticate();
    if (!unlocked) {
      state = state.copyWith(
        errorMessage: 'PlanIT stays locked until your phone unlock is confirmed.',
      );
      return false;
    }
    state = state.copyWith(locked: false, clearError: true);
    return true;
  }

  void lockForBackground() {
    if (state.enabled) {
      state = state.copyWith(locked: true, clearError: true);
    }
  }
}
