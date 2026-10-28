import 'package:api_client/api_client.dart';
import 'package:dio/dio.dart';
import 'package:my_app/core/auth/token_store.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'api_client.g.dart';

const _baseUrl = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:8080');

/// dio + 生成クライアント。認証ヘッダと 401 時の refresh をインターセプタで一元化する。
@riverpod
ApiClient apiClient(Ref ref) {
  final tokens = ref.watch(tokenStoreProvider);
  final dio = Dio(BaseOptions(baseUrl: _baseUrl, connectTimeout: const Duration(seconds: 10)));
  dio.interceptors.add(
    QueuedInterceptorsWrapper(
      onRequest: (options, handler) async {
        final access = await tokens.readAccess();
        if (access != null) options.headers['Authorization'] = 'Bearer $access';
        handler.next(options);
      },
      onError: (err, handler) async {
        if (err.response?.statusCode != 401 || err.requestOptions.extra['retried'] == true) {
          return handler.next(err);
        }
        final refresh = await tokens.readRefresh();
        if (refresh == null) return handler.next(err);
        try {
          final res = await Dio(BaseOptions(baseUrl: _baseUrl))
              .post<Map<String, dynamic>>('/auth/refresh', data: {'refreshToken': refresh});
          final data = res.data!;
          await tokens.write(access: data['accessToken'] as String, refresh: data['refreshToken'] as String);
          final retry = err.requestOptions
            ..headers['Authorization'] = 'Bearer ${data['accessToken']}'
            ..extra['retried'] = true;
          handler.resolve(await dio.fetch(retry));
        } on DioException {
          await tokens.clear();
          handler.next(err);
        }
      },
    ),
  );
  return ApiClient(dio: dio);
}
