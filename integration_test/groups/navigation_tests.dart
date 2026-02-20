/// 导航流程集成测试
///
/// 验证 App 启动默认页面、各 Tab 切换是否正常。
library;

import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_notifiers.dart';

/// 导航相关集成测试
void navigationTests() {
  group('流程 1：App 启动与导航', () {
    testWidgets('App 正常启动，显示学习页', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // 默认显示学习页面
      expect(find.text('Study feature coming soon'), findsOneWidget);
    });

    testWidgets('点击各导航切换页面', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // 默认在学习页
      expect(find.text('Study feature coming soon'), findsOneWidget);

      // 切换到收藏页
      await tester.tap(find.text('Favorites'));
      await tester.pumpAndSettle();
      expect(find.text('Favorites feature coming soon'), findsOneWidget);

      // 切换到我的页
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Appearance'), findsOneWidget);

      // 切换回合集页
      await tester.tap(find.text('Collections'));
      await tester.pumpAndSettle();
      expect(find.text('No collections yet'), findsOneWidget);
    });
  });
}
