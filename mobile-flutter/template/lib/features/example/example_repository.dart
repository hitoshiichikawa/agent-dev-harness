import 'package:api_client/api_client.dart';
import 'package:my_app/core/api_client.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'example_repository.g.dart';

/// Repository は abstract で宣言し、Provider で実装を注入する。テストでは overrideWith で差し替える。
abstract class ExampleRepository {
  Future<List<Example>> list({int limit = 20});
  Future<Example> create(String name);
}

class ApiExampleRepository implements ExampleRepository {
  ApiExampleRepository(this._api);
  final ExampleApi _api;

  @override
  Future<List<Example>> list({int limit = 20}) async {
    final res = await _api.listExamples(limit: limit);
    return res.data!.items;
  }

  @override
  Future<Example> create(String name) async {
    final res = await _api.createExample(exampleCreate: ExampleCreate(name: name));
    return res.data!;
  }
}

@riverpod
ExampleRepository exampleRepository(Ref ref) =>
    ApiExampleRepository(ref.watch(apiClientProvider).getExampleApi());
