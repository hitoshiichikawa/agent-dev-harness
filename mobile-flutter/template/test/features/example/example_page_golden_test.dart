import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/app/theme.dart';
import 'package:my_app/features/example/example_page.dart';
import 'package:my_app/features/example/example_repository.dart';

import 'example_notifier_test.dart' show FakeExampleRepository;

/// golden はエージェントの「見た目の確認」手段。UI を変えたら `make golden` で更新して差分を報告する。
void main() {
  testWidgets('ExamplePage golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final repo = FakeExampleRepository();
    await repo.create('first');
    await repo.create('second');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [exampleRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(theme: appTheme, home: const ExamplePage()),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(find.byType(ExamplePage), matchesGoldenFile('../../goldens/example_page.png'));
  });
}
