import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planit_mobile/core/design_system/tokens.dart';
import 'package:planit_mobile/features/purchases/application/media_controller.dart';
import 'package:planit_mobile/features/purchases/application/providers.dart';
import 'package:planit_mobile/features/purchases/domain/purchase_catalog.dart';
import 'package:planit_mobile/features/purchases/presentation/image_source_sheet.dart';
import 'package:uuid/uuid.dart';

class MerchantsScreen extends ConsumerStatefulWidget {
  const MerchantsScreen({super.key});
  @override
  ConsumerState<MerchantsScreen> createState() => _MerchantsScreenState();
}

class _MerchantsScreenState extends ConsumerState<MerchantsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(purchaseCatalogControllerProvider.notifier).refresh(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final values = ref.watch(merchantsProvider);
    final action = ref.watch(purchaseCatalogControllerProvider);
    final media = ref.watch(mediaUploadControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shops & branches'),
        actions: <Widget>[
          IconButton(
            onPressed: action.isLoading
                ? null
                : () => ref
                      .read(purchaseCatalogControllerProvider.notifier)
                      .refresh(),
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: action.isLoading ? null : () => _newMerchant(context),
        icon: const Icon(Icons.add),
        label: const Text('Add shop'),
      ),
      body: values.when(
        data: (items) => items.isEmpty
            ? const Center(child: Text('Add the shops you buy from.'))
            : ListView.builder(
                padding: const EdgeInsets.all(PlanItSpacing.md),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final count = item.locations.length;
                  return Card(
                    child: ExpansionTile(
                      leading: const Icon(Icons.storefront_outlined),
                      title: Text(item.name),
                      subtitle: Text(
                        count == 0
                            ? 'Brand or independent shop'
                            : '$count branch${count == 1 ? '' : 'es'}',
                      ),
                      children: <Widget>[
                        for (final location in item.locations)
                          ListTile(
                            leading: const Icon(Icons.location_on_outlined),
                            title: Text(location.name),
                            subtitle: location.locationText == null
                                ? null
                                : Text(location.locationText!),
                          ),
                        ListTile(
                          leading: const Icon(Icons.add_a_photo_outlined),
                          title: const Text('Add shop image'),
                          enabled: !media.isLoading,
                          onTap: () => _addImage(context, item),
                        ),
                        ListTile(
                          leading: const Icon(Icons.add_location_alt_outlined),
                          title: const Text('Add branch'),
                          onTap: () => _newLocation(context, item),
                        ),
                      ],
                    ),
                  );
                },
              ),
        error: (error, _) => Center(child: Text('$error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _newMerchant(BuildContext context) async {
    final name = await _textDialog(context, 'Add shop', 'Shop or brand name');
    if (name == null) return;
    await ref.read(purchaseCatalogControllerProvider.notifier).createMerchant(
      <String, Object?>{'id': const Uuid().v4(), 'name': name},
      const Uuid().v4(),
    );
  }

  Future<void> _newLocation(BuildContext context, Merchant merchant) async {
    final name = await _textDialog(context, 'Add branch', 'Branch name');
    if (name == null) return;
    await ref.read(purchaseCatalogControllerProvider.notifier).createLocation(
      merchant.id,
      <String, Object?>{'id': const Uuid().v4(), 'name': name},
      const Uuid().v4(),
    );
  }

  Future<void> _addImage(BuildContext context, Merchant merchant) async {
    final source = await showImageSourceSheet(context);
    if (source == null || !context.mounted) return;
    final saved = await ref
        .read(mediaUploadControllerProvider.notifier)
        .addImage(
          entityType: 'MERCHANT',
          entityId: merchant.id,
          source: source,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved ? 'Shop image uploaded privately.' : 'Image upload failed.',
        ),
      ),
    );
  }
}

Future<String?> _textDialog(
  BuildContext context,
  String title,
  String label,
) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 160,
        decoration: InputDecoration(labelText: label),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final value = controller.text.trim();
            if (value.isNotEmpty) Navigator.pop(context, value);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}
