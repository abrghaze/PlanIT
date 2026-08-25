import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planit_mobile/core/design_system/tokens.dart';
import 'package:planit_mobile/features/transactions/application/catalog_controller.dart';
import 'package:planit_mobile/features/transactions/application/providers.dart';
import 'package:planit_mobile/features/transactions/application/transaction_controller.dart';
import 'package:planit_mobile/features/transactions/domain/catalog.dart';
import 'package:uuid/uuid.dart';

class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(ledgerBootstrapProvider);
    final categories = ref.watch(transactionCategoriesProvider);
    final tags = ref.watch(transactionTagsProvider);
    final action = ref.watch(catalogControllerProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Categories & tags'),
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: 'Categories'),
              Tab(text: 'Tags'),
            ],
          ),
        ),
        body: Column(
          children: <Widget>[
            if (action.errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(PlanItSpacing.sm),
                child: _ErrorBanner(message: action.errorMessage!),
              ),
            Expanded(
              child: TabBarView(
                children: <Widget>[
                  _CategoryList(values: categories, busy: action.busy),
                  _TagList(values: tags, busy: action.busy),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton.extended(
            onPressed: action.busy
                ? null
                : () {
                    final index = DefaultTabController.of(context).index;
                    index == 0
                        ? _createCategory(context, ref)
                        : _createTag(context, ref);
                  },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add'),
          ),
        ),
      ),
    );
  }

  static Future<void> _createCategory(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final controller = TextEditingController();
    var kind = CategoryKind.expense;
    final draft = await showDialog<CategoryDraft>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: PlanItSpacing.sm),
              DropdownButtonFormField<CategoryKind>(
                initialValue: kind,
                decoration: const InputDecoration(labelText: 'Used for'),
                items: CategoryKind.values
                    .map(
                      (value) => DropdownMenuItem<CategoryKind>(
                        value: value,
                        child: Text(value.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) => setState(() => kind = value ?? kind),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  Navigator.of(context).pop(
                    CategoryDraft(
                      id: const Uuid().v4(),
                      name: name,
                      kind: kind,
                    ),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (draft != null) {
      await ref
          .read(catalogControllerProvider.notifier)
          .createCategory(draft: draft, operationId: const Uuid().v4());
    }
  }

  static Future<void> _createTag(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final colorController = TextEditingController(text: '#3366FF');
    final draft = await showDialog<TagDraft>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add tag'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: nameController,
              autofocus: true,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: colorController,
              maxLength: 7,
              decoration: const InputDecoration(
                labelText: 'Color',
                hintText: '#3366FF',
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final color = colorController.text.trim();
              if (name.isNotEmpty &&
                  RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color)) {
                Navigator.of(context).pop(
                  TagDraft(
                    id: const Uuid().v4(),
                    name: name,
                    color: color.toUpperCase(),
                  ),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    nameController.dispose();
    colorController.dispose();
    if (draft != null) {
      await ref
          .read(catalogControllerProvider.notifier)
          .createTag(draft: draft, operationId: const Uuid().v4());
    }
  }
}

class _CategoryList extends ConsumerWidget {
  const _CategoryList({required this.values, required this.busy});

  final AsyncValue<List<TransactionCategory>> values;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return values.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          const Center(child: Text('Categories could not be loaded.')),
      data: (categories) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          PlanItSpacing.lg,
          PlanItSpacing.md,
          PlanItSpacing.lg,
          96,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return Card(
            child: ListTile(
              leading: Icon(
                category.kind == CategoryKind.income
                    ? Icons.arrow_downward_rounded
                    : category.kind == CategoryKind.expense
                    ? Icons.arrow_upward_rounded
                    : Icons.swap_vert_rounded,
              ),
              title: Text(category.name),
              subtitle: Text(
                '${category.kind.label}${category.isSeeded ? ' · PlanIT default' : ''}',
              ),
              trailing: IconButton(
                tooltip: category.active ? 'Archive' : 'Restore',
                onPressed: busy
                    ? null
                    : () => ref
                          .read(catalogControllerProvider.notifier)
                          .setCategoryArchived(
                            category,
                            category.active,
                            const Uuid().v4(),
                          ),
                icon: Icon(
                  category.active
                      ? Icons.archive_outlined
                      : Icons.restore_rounded,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TagList extends ConsumerWidget {
  const _TagList({required this.values, required this.busy});

  final AsyncValue<List<TransactionTag>> values;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return values.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(child: Text('Tags could not be loaded.')),
      data: (tags) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          PlanItSpacing.lg,
          PlanItSpacing.md,
          PlanItSpacing.lg,
          96,
        ),
        itemCount: tags.length,
        itemBuilder: (context, index) {
          final tag = tags[index];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _parseColor(tag.color),
                child: const Icon(Icons.sell_outlined, color: Colors.white),
              ),
              title: Text(tag.name),
              subtitle: Text(tag.active ? 'Active' : 'Archived'),
              trailing: IconButton(
                tooltip: tag.active ? 'Archive' : 'Restore',
                onPressed: busy
                    ? null
                    : () => ref
                          .read(catalogControllerProvider.notifier)
                          .setTagArchived(tag, tag.active, const Uuid().v4()),
                icon: Icon(
                  tag.active ? Icons.archive_outlined : Icons.restore_rounded,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static Color _parseColor(String? value) {
    if (value == null || !RegExp(r'^#[0-9A-F]{6}$').hasMatch(value)) {
      return Colors.blueGrey;
    }
    return Color(int.parse(value.substring(1), radix: 16) | 0xFF000000);
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(PlanItRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(PlanItSpacing.sm),
        child: Text(message),
      ),
    );
  }
}
