import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/widgets/intensive_listen/sentence_annotation_card.dart';

import '../helpers/test_app.dart';

void main() {
  group('SentenceAnnotationCard', () {
    testWidgets('显示句子文本和难句标记', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Hello world',
            isDifficult: false,
            onToggle: () {},
          ),
        ),
      );

      // 句子文本通过 RichText 渲染，验证 RichText 存在
      expect(find.byType(RichText), findsWidgets);

      // 非难句状态
      expect(find.byIcon(Icons.star_border), findsOneWidget);

      // 翻译和解析区域标题存在
      expect(find.text('Translation'), findsOneWidget);
      expect(find.text('Analysis'), findsOneWidget);
    });

    testWidgets('难句标记状态正确显示', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Difficult sentence',
            isDifficult: true,
            onToggle: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('点击难句标记触发 onToggle', (tester) async {
      var toggled = false;
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
            isDifficult: false,
            onToggle: () => toggled = true,
          ),
        ),
      );

      // 点击星标区域
      await tester.tap(find.byIcon(Icons.star_border));
      expect(toggled, isTrue);
    });

    testWidgets('cachedTranslation 直接展示', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Hello',
            isDifficult: false,
            onToggle: () {},
            cachedTranslation: '你好',
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('你好'), findsOneWidget);
    });

    testWidgets('cachedAnalysis 直接展示', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Hello',
            isDifficult: false,
            onToggle: () {},
            cachedAnalysis: '语法分析\n词汇分析\n用法分析',
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('语法分析'), findsOneWidget);
      expect(find.text('词汇分析'), findsOneWidget);
      expect(find.text('用法分析'), findsOneWidget);
    });

    testWidgets('翻译和解析区域包含正确图标', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SentenceAnnotationCard(
            text: 'Test',
            isDifficult: false,
            onToggle: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.translate), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    });
  });
}
