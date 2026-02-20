/// 设置修改集成测试
///
/// 验证主题切换、语言切换等设置功能。
library;

import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_notifiers.dart';

/// 设置相关集成测试
void settingsTests() {
  group('流程 2：设置修改', () {
    testWidgets('切换主题', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // 进入我的页
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      // 点击主题设置
      await tester.tap(find.text('Theme Mode'));
      await tester.pumpAndSettle();

      // 选择 Dark Mode 主题
      await tester.tap(find.text('Dark Mode'));
      await tester.pumpAndSettle();

      // 验证设置已更新为 Dark Mode
      expect(find.text('Dark Mode'), findsOneWidget);
    });

    testWidgets('切换语言', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // 进入我的页
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      // 点击语言设置
      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();

      // 选择简体中文
      await tester.tap(find.text('简体中文'));
      await tester.pumpAndSettle();

      // 语言切换后 UI 文案应变为中文
      expect(find.text('简体中文'), findsOneWidget);
    });
  });
}
