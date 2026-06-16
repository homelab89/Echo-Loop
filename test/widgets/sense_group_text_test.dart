import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/speech_practice_models.dart';
import 'package:echo_loop/widgets/practice/sense_group_text.dart';

import '../helpers/test_app.dart';

/// 跟读匹配单词的高亮绿色（与组件内常量保持一致）
const _matchedColor = Color(0xFF2E9B51);

void main() {
  /// 收集所有 RichText 里被染成绿色的单词文本
  List<String> matchedWords(WidgetTester tester) {
    final result = <String>[];
    for (final richText in tester.widgetList<RichText>(find.byType(RichText))) {
      final span = richText.text;
      if (span is TextSpan) {
        span.visitChildren((child) {
          if (child is TextSpan &&
              child.style?.color == _matchedColor &&
              (child.text ?? '').trim().isNotEmpty) {
            result.add(child.text!.trim());
          }
          return true;
        });
      }
    }
    return result;
  }

  /// 单词段（命中目标词）
  SpeechTranscriptSegment word(String text, {required bool matched}) =>
      SpeechTranscriptSegment(text: text, isMatched: matched);

  group('SenseGroupText — 意群模式单词高亮', () {
    testWidgets('匹配单词染绿，未匹配单词不染绿', (tester) async {
      // 原文 "Hello brave world" → 意群拆为 ["Hello brave", "world"]
      // 比对结果：Hello 匹配、brave 未匹配、world 匹配
      await tester.pumpWidget(
        createTestApp(
          SenseGroupText(
            chunks: const ['Hello brave', 'world'],
            timings: const [],
            onTapGroup: (_) {},
            highlightedSegments: [
              word('Hello', matched: true),
              const SpeechTranscriptSegment(text: ' ', isMatched: false),
              word('brave', matched: false),
              const SpeechTranscriptSegment(text: ' ', isMatched: false),
              word('world', matched: true),
            ],
          ),
        ),
      );

      final matched = matchedWords(tester);
      expect(matched, contains('Hello'));
      expect(matched, contains('world'));
      expect(matched, isNot(contains('brave')));
    });

    testWidgets('跨 badge 单词游标对齐（第二意群首词按整句状态上色）', (tester) async {
      // 原文 "one two three" → 意群 ["one two", "three"]
      // 仅 three 匹配；验证游标跨过第一意群两词后正确落到 three
      await tester.pumpWidget(
        createTestApp(
          SenseGroupText(
            chunks: const ['one two', 'three'],
            timings: const [],
            onTapGroup: (_) {},
            highlightedSegments: [
              word('one', matched: false),
              const SpeechTranscriptSegment(text: ' ', isMatched: false),
              word('two', matched: false),
              const SpeechTranscriptSegment(text: ' ', isMatched: false),
              word('three', matched: true),
            ],
          ),
        ),
      );

      expect(matchedWords(tester), equals(['three']));
    });

    testWidgets('粘连标点不染绿（与普通模式一致）', (tester) async {
      // "anymore," 中只有单词 anymore 染绿，逗号不染绿
      await tester.pumpWidget(
        createTestApp(
          SenseGroupText(
            chunks: const ['pay anymore,'],
            timings: const [],
            onTapGroup: (_) {},
            highlightedSegments: [
              word('pay', matched: false),
              const SpeechTranscriptSegment(text: ' ', isMatched: false),
              word('anymore', matched: true),
              const SpeechTranscriptSegment(text: ',', isMatched: false),
            ],
          ),
        ),
      );

      // 绿色片段是纯 "anymore"，不含逗号
      expect(matchedWords(tester), equals(['anymore']));
    });

    testWidgets('连字符词按两个单词计数，游标不错位', (tester) async {
      // "well-being world" → well/being 是两个单词，错算成一个会让 world 错位
      await tester.pumpWidget(
        createTestApp(
          SenseGroupText(
            chunks: const ['well-being world'],
            timings: const [],
            onTapGroup: (_) {},
            highlightedSegments: [
              word('well', matched: true),
              const SpeechTranscriptSegment(text: '-', isMatched: false),
              word('being', matched: false),
              const SpeechTranscriptSegment(text: ' ', isMatched: false),
              word('world', matched: true),
            ],
          ),
        ),
      );

      final matched = matchedWords(tester);
      expect(matched, contains('well'));
      expect(matched, contains('world'));
      expect(matched, isNot(contains('being')));
    });

    testWidgets('无高亮数据时回退为纯文本，不报错', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SenseGroupText(
            chunks: const ['Hello world'],
            timings: const [],
            onTapGroup: (_) {},
          ),
        ),
      );

      // 纯文本渲染：能找到原始文本，且无绿色高亮
      expect(find.text('Hello world'), findsOneWidget);
      expect(matchedWords(tester), isEmpty);
    });
  });
}
