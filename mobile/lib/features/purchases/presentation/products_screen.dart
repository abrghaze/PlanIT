import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planit_mobile/core/design_system/tokens.dart';
import 'package:planit_mobile/core/money/exact_decimal.dart';
import 'package:planit_mobile/features/purchases/application/media_controller.dart';
import 'package:planit_mobile/features/purchases/application/providers.dart';
import 'package:planit_mobile/features/purchases/domain/purchase_catalog.dart';
import 'package:planit_mobile/features/purchases/presentation/image_source_sheet.dart';
import 'package:uuid/uuid.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});
  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(purchaseCatalogControllerProvider.notifier).refresh(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final action = ref.watch(purchaseCatalogControllerProvider);
    final media = ref.watch(mediaUploadControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Products & variants')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: action.isLoading ? null : () => _add(context),
        icon: const Icon(Icons.add),
        label: const Text('Add product'),
      ),
      body: products.when(
        data: (items) => items.isEmpty
            ? const Center(
                child: Text('Add reusable products and package variants.'),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(PlanItSpacing.md),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: Text(item.displayName),
                      subtitle: Text(
                        [
                          if (item.sizeValue != null)
                            '${item.sizeValue} ${item.sizeUnit}',
                          if (item.barcode != null) 'Barcode ${item.barcode}',
                        ].join(' · '),
                      ),
                      trailing: IconButton(
                        tooltip: 'Add product image',
                        onPressed: media.isLoading
                            ? null
                            : () => _addImage(context, item),
                        icon: const Icon(Icons.add_a_photo_outlined),
                      ),
                    ),
                  );
                },
              ),
        error: (error, _) => Center(child: Text('$error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final name = TextEditingController();
    final brand = TextEditingController();
    final variant = TextEditingController();
    final size = TextEditingController();
    final barcode = TextEditingController();
    var sizeUnit = 'COUNT';
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Product name'),
                ),
                TextField(
                  controller: brand,
                  decoration: const InputDecoration(
                    labelText: 'Brand (optional)',
                  ),
                ),
                TextField(
                  controller: variant,
                  decoration: const InputDecoration(
                    labelText: 'Variant / size (optional)',
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: size,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Package size (optional)',
                        ),
                      ),
                    ),
                    const SizedBox(width: PlanItSpacing.sm),
                    DropdownButton<String>(
                      value: sizeUnit,
                      items: const <String>['COUNT', 'G', 'KG', 'ML', 'L']
                          .map(
                            (unit) => DropdownMenuItem<String>(
                              value: unit,
                              child: Text(unit),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => sizeUnit = value);
                        }
                      },
                    ),
                  ],
                ),
                TextField(
                  controller: barcode,
                  decoration: const InputDecoration(
                    labelText: 'Barcode (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (save == true && name.text.trim().isNotEmpty) {
      final sizeValue = size.text.trim().isEmpty
          ? null
          : ExactDecimal.tryParse(size.text, scale: 6, maximumDigits: 19);
      if (size.text.trim().isNotEmpty &&
          (sizeValue == null || !sizeValue.isPositive)) {
        if (mounted) {
          ScaffoldMessenger.of(this.context).showSnackBar(
            const SnackBar(content: Text('Package size must be positive.')),
          );
        }
        _disposeProductControllers(name, brand, variant, size, barcode);
        return;
      }
      await ref
          .read(purchaseCatalogControllerProvider.notifier)
          .createProduct(<String, Object?>{
            'id': const Uuid().v4(),
            'name': name.text.trim(),
            'brand': brand.text.trim().isEmpty ? null : brand.text.trim(),
            'variant_label': variant.text.trim().isEmpty
                ? null
                : variant.text.trim(),
            'size_value': sizeValue?.toFixedString(),
            'size_unit': sizeValue == null ? null : sizeUnit,
            'barcode': barcode.text.trim().isEmpty ? null : barcode.text.trim(),
          }, const Uuid().v4());
    }
    _disposeProductControllers(name, brand, variant, size, barcode);
  }

  Future<void> _addImage(BuildContext context, Product product) async {
    final source = await showImageSourceSheet(context);
    if (source == null || !context.mounted) return;
    final saved = await ref
        .read(mediaUploadControllerProvider.notifier)
        .addImage(entityType: 'PRODUCT', entityId: product.id, source: source);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved ? 'Product image uploaded privately.' : 'Image upload failed.',
        ),
      ),
    );
  }
}

void _disposeProductControllers(
  TextEditingController name,
  TextEditingController brand,
  TextEditingController variant,
  TextEditingController size,
  TextEditingController barcode,
) {
  name.dispose();
  brand.dispose();
  variant.dispose();
  size.dispose();
  barcode.dispose();
}
