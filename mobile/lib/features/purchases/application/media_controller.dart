import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:planit_mobile/core/auth/application/auth_controller.dart';
import 'package:planit_mobile/core/auth/application/providers.dart';
import 'package:planit_mobile/features/purchases/data/media_api.dart';
import 'package:uuid/uuid.dart';

final mediaApiProvider = Provider<MediaApi>(
  (ref) => MediaApi(ref.watch(apiClientProvider)),
);
final mediaUploadControllerProvider =
    NotifierProvider<MediaUploadController, AsyncValue<void>>(
      MediaUploadController.new,
    );

final class MediaUploadController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> addImage({
    required String entityType,
    required String entityId,
    required ImageSource source,
  }) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return false;
    final image = await ImagePicker().pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 2200,
    );
    if (image == null) return false;
    state = const AsyncLoading();
    try {
      final bytes = await image.readAsBytes();
      final mime = switch (image.mimeType?.toLowerCase()) {
        'image/png' => 'image/png',
        'image/webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      await ref
          .read(mediaApiProvider)
          .uploadImage(
            token: session.accessToken,
            operationId: const Uuid().v4(),
            mediaId: const Uuid().v4(),
            entityType: entityType,
            entityId: entityId,
            mimeType: mime,
            bytes: bytes,
          );
      state = const AsyncData(null);
      return true;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      return false;
    }
  }

  Future<bool> addReceipt(String transactionId, ImageSource source) => addImage(
    entityType: 'TRANSACTION',
    entityId: transactionId,
    source: source,
  );
}
