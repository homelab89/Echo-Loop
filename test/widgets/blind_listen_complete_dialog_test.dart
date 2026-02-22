import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/database/enums.dart';
import 'package:fluency/widgets/blind_listen_complete_dialog.dart';

import '../helpers/test_app.dart';

void main() {
  group('BlindListenCompleteDialog', () {
    testWidgets('显示完成信息和 5 档难度选择', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showBlindListenCompleteDialog(context: context, passCount: 1);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // 验证标题和遍数
      expect(find.text('Listening Complete'), findsOneWidget);
      expect(find.text('Listened 1 time(s)'), findsOneWidget);
      expect(find.text('How did it feel?'), findsOneWidget);

      // 验证 5 个难度选项
      expect(find.text('Very Easy'), findsOneWidget);
      expect(find.text('Easy'), findsOneWidget);
      expect(find.text('Okay'), findsOneWidget);
      expect(find.text('Hard'), findsOneWidget);
      expect(find.text('Very Hard'), findsOneWidget);

      // 验证按钮
      expect(find.text('Listen Again'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('未选择难度时 — "下一步"按钮置灰', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showBlindListenCompleteDialog(context: context, passCount: 1);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // "下一步"按钮应该是置灰的（disabled）
      final nextButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Next'),
      );
      expect(nextButton.onPressed, isNull);
    });

    testWidgets('选择难度后 — "下一步"按钮可点击', (tester) async {
      DifficultyLevel? result;

      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showBlindListenCompleteDialog(
                  context: context,
                  passCount: 2,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // 选择"Hard"
      await tester.tap(find.text('Hard'));
      await tester.pumpAndSettle();

      // "下一步"按钮可点击
      final nextButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Next'),
      );
      expect(nextButton.onPressed, isNotNull);

      // 点击"下一步"
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(result, DifficultyLevel.hard);
    });

    testWidgets('"再听一遍"按钮返回 null', (tester) async {
      DifficultyLevel? result = DifficultyLevel.medium; // 初始值非 null 用于验证

      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showBlindListenCompleteDialog(
                  context: context,
                  passCount: 1,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // 点击"再听一遍"
      await tester.tap(find.text('Listen Again'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets('已听多遍时显示正确遍数', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showBlindListenCompleteDialog(context: context, passCount: 3);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Listened 3 time(s)'), findsOneWidget);
    });
  });
}
