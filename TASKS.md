# Fluency 任务清单

> 最后更新：2026-02-20
> 当前焦点：Milestone 2 - 学习流程引擎

---

## 导航重构

- [x] 将四个 Tab 从 Library | Collections | Player | Account 改为 合集 | 学习 | 收藏 | 我的，默认是学习

**完成时间**: 2026-02-20
**变更点**:
- 新建 `lib/screens/study_screen.dart` — 学习页 placeholder
- 新建 `lib/screens/favorites_screen.dart` — 收藏页 placeholder
- 修改 `lib/main.dart` — 更新导航栏（NavigationBar + NavigationRail）和 `_getSelectedScreen()`
- 更新 `lib/l10n/app_en.arb` 和 `lib/l10n/app_zh.arb` — 新增 study/favorites/profile/comingSoon 翻译
- 更新 `integration_test/app_test.dart` 和 `test/widget_test.dart` — 适配新导航结构

---

## Milestone 2: 学习流程引擎

- [ ] 设计学习进度数据模型（阶段、小阶段、完成状态、难度）
- [ ] 实现首学流程 — 全文盲听模式
- [ ] 实现首学流程 — 逐句精听+标注模式
- [ ] 实现首学流程 — 难句跟读模式
- [ ] 实现首学流程 — 段级复述模式
- [ ] 实现复习调度引擎（R1-R28 间隔计算与提醒）
- [ ] 实现学习进度记录与断点续学
- [ ] 实现难度评估（简单/中等/困难）及其对遍数、间隔的影响

## Milestone 3: 收藏与标注体系

- [ ] 实现难句收藏（精听/复习中标记）
- [ ] 实现生词+意群高亮（附属于句子）
- [ ] 实现独立单词本（汇总所有标记的单词和意群）
- [ ] 实现收藏句子的复习与取消收藏逻辑

## Milestone 4: 体验优化与生产就绪

- [ ] 性能优化（大量音频、长列表场景）
- [ ] 错误处理与边界情况完善
- [ ] 多平台适配优化
- [ ] 新材料推荐控制（每周 2-3 篇，超限提醒）

---

## 任务完成记录模板

<!--
完成任务后，按以下格式在任务下方添加记录：

**完成时间**: 2026-XX-XX
**变更点**:
- 修改了 X 文件，实现 Y 功能
- 添加了 Z 测试，覆盖 A 场景
-->
