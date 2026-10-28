import 'package:api_client/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/example/example_notifier.dart';
import 'package:my_app/features/example/example_repository.dart';

/// Repository を fake に差し替えて Notifier のロジックだけを検証する。
class FakeExampleRepository implements ExampleRepository {
  final _items = <Example>[];
  @override
  Future<List<Example>> list({int limit = 20}) async => List.of(_items);
  @override
  Future<Example> create(String name) async {
    final e = Example(id: 'id-${_items.length}', name: name, createdAt: DateTime.now());
    _items.add(e);
    return e;
  }
}

void main() {
  test('add trims and prepends', () async {
    final container = ProviderContainer(
      overrides: [exampleRepositoryProvider.overrideWithValue(FakeExampleRepository())],
    );
    addTearDown(container.dispose);

    await container.read(exampleNotifierProvider.future);
    await container.read(exampleNotifierProvider.notifier).add('  hello  ');

    final items = container.read(exampleNotifierProvider).requireValue;
    expect(items.single.name, 'hello');
  });

  test('add ignores blank', () async {
    final container = ProviderContainer(
      overrides: [exampleRepositoryProvider.overrideWithValue(FakeExampleRepository())],
    );
    addTearDown(container.dispose);
    await container.read(exampleNotifierProvider.future);
    await container.read(exampleNotifierProvider.notifier).add('   ');
    expect(container.read(exampleNotifierProvider).requireValue, isEmpty);
  });
}
