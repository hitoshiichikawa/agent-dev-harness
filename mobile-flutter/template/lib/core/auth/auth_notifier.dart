import 'package:api_client/api_client.dart';
import 'package:my_app/core/api_client.dart';
import 'package:my_app/core/auth/token_store.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_notifier.g.dart';

/// ログイン状態。state が null なら未ログイン。
@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  Future<String?> build() async => ref.watch(tokenStoreProvider).readAccess();

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final res = await ref.read(apiClientProvider).getAuthApi().issueToken(
            tokenRequest: TokenRequest(email: email, password: password),
          );
      final pair = res.data!;
      await ref.read(tokenStoreProvider).write(access: pair.accessToken, refresh: pair.refreshToken);
      return pair.accessToken;
    });
  }

  Future<void> logout() async {
    await ref.read(tokenStoreProvider).clear();
    state = const AsyncData(null);
  }
}
