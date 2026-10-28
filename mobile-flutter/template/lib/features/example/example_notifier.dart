import 'package:api_client/api_client.dart';
import 'package:my_app/features/example/example_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'example_notifier.g.dart';

/// ロジックはここ。状態は AsyncValue、例外は guard で state に乗せる。
@riverpod
class ExampleNotifier extends _$ExampleNotifier {
  @override
  Future<List<Example>> build() => ref.watch(exampleRepositoryProvider).list();

  Future<void> add(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final repo = ref.read(exampleRepositoryProvider);
    state = await AsyncValue.guard(() async {
      final created = await repo.create(trimmed);
      return [created, ...state.valueOrNull ?? []];
    });
  }
}
