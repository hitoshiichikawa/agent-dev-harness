import 'package:go_router/go_router.dart';
import 'package:my_app/core/auth/auth_notifier.dart';
import 'package:my_app/features/example/example_page.dart';
import 'package:my_app/features/login/login_page.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

/// ルート定義はこのファイルだけ。認証ガードもここ。
@riverpod
GoRouter router(Ref ref) {
  final auth = ref.watch(authNotifierProvider);
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final loggedIn = auth.valueOrNull != null;
      final onLogin = state.matchedLocation == '/login';
      if (!loggedIn && !onLogin) return '/login';
      if (loggedIn && onLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/', builder: (_, __) => const ExamplePage()),
    ],
  );
}
