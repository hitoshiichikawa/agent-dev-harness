import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_app/main.dart' as app;

/// smoke 1 本だけ。重いので増やさない。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('app boots to login', (tester) async {
    app.main();
    await tester.pumpAndSettle();
    expect(find.text('Login'), findsWidgets);
  });
}
