import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/core/privacy/app_privacy_controller.dart';

void main() {
  test('enabled app lock requires device authentication after backgrounding', () async {
    final store = _MemoryPrivacyStore();
    final authenticator = _FakeDeviceAuthenticator();
    final container = ProviderContainer(
      overrides: [
        appPrivacyStoreProvider.overrideWithValue(store),
        deviceAuthenticatorProvider.overrideWithValue(authenticator),
      ],
    );
    addTearDown(container.dispose);

    container.read(appPrivacyControllerProvider);
    await pumpEventQueue();
    final controller = container.read(appPrivacyControllerProvider.notifier);

    expect(container.read(appPrivacyControllerProvider).available, isTrue);
    expect(await controller.enable(), isTrue);
    expect(container.read(appPrivacyControllerProvider).locked, isFalse);

    controller.lockForBackground();
    expect(container.read(appPrivacyControllerProvider).locked, isTrue);

    expect(await controller.unlock(), isTrue);
    expect(container.read(appPrivacyControllerProvider).locked, isFalse);
    expect(authenticator.authenticationRequests, 2);
    expect(store.enabled, isTrue);
  });

  test('unavailable device authentication cannot enable an app lock', () async {
    final container = ProviderContainer(
      overrides: [
        appPrivacyStoreProvider.overrideWithValue(_MemoryPrivacyStore()),
        deviceAuthenticatorProvider.overrideWithValue(
          _FakeDeviceAuthenticator(available: false),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(appPrivacyControllerProvider);
    await pumpEventQueue();

    expect(
      await container.read(appPrivacyControllerProvider.notifier).enable(),
      isFalse,
    );
    expect(
      container.read(appPrivacyControllerProvider).errorMessage,
      contains('screen lock'),
    );
  });
}

final class _MemoryPrivacyStore implements AppPrivacyStore {
  bool enabled = false;

  @override
  Future<bool> readLockEnabled() async => enabled;

  @override
  Future<void> writeLockEnabled(bool value) async {
    enabled = value;
  }
}

final class _FakeDeviceAuthenticator implements DeviceAuthenticator {
  _FakeDeviceAuthenticator({this.available = true, this.authenticationSucceeds = true});

  final bool available;
  final bool authenticationSucceeds;
  int authenticationRequests = 0;

  @override
  Future<bool> authenticate() async {
    authenticationRequests += 1;
    return authenticationSucceeds;
  }

  @override
  Future<bool> isAvailable() async => available;
}
