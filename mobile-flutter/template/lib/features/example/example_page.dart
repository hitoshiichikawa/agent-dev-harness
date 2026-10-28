import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_app/core/auth/auth_notifier.dart';
import 'package:my_app/features/example/example_notifier.dart';
import 'package:my_app/features/example/widgets/example_add_field.dart';

/// Page は ref.watch と UI だけ。
class ExamplePage extends ConsumerWidget {
  const ExamplePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examples = ref.watch(exampleNotifierProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Examples'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
          ),
        ],
      ),
      body: Column(
        children: [
          ExampleAddField(onSubmit: (name) => ref.read(exampleNotifierProvider.notifier).add(name)),
          Expanded(
            child: examples.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('読み込みに失敗しました: $e')),
              data: (items) => ListView.builder(
                itemCount: items.length,
                itemBuilder: (_, i) => ListTile(title: Text(items[i].name)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
