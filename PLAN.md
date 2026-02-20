# Fluency 项目规划

> 最后更新：2026-02-21
> 当前阶段：Milestone 1 已完成 ✅，Milestone 2 计划中

## 项目概述

Fluency 是一款 Flutter 跨平台英语听说练习应用，通过结构化的学习流程（首学→间隔复习→毕业检验）帮助用户系统性地提升英语听说能力。

---

## 目录结构与关键文件索引

```
lib/
├── main.dart                        # 应用入口，配置主题/国际化/路由
├── l10n/                            # 国际化
│   ├── app_en.arb                   # 英文模板（新增 key 在此添加）
│   └── app_zh.arb                   # 中文翻译
├── models/                          # 纯数据模型（不含业务逻辑）
│   ├── audio_item.dart              #   音频文件元数据（相对路径）
│   ├── collection.dart              #   合集（包含多个 AudioItem）
│   ├── sentence.dart                #   字幕句子（时间轴 + 书签状态）
│   ├── playback_settings.dart       #   播放设置（循环、速度、间隔等）
│   ├── audio_engine_state.dart      #   音频引擎状态快照
│   └── listening_practice_state.dart#   学习会话完整状态
├── services/                        # 基础服务（无状态/单例）
│   ├── storage_service.dart         #   SharedPreferences 持久化封装
│   └── subtitle_parser.dart         #   SRT/VTT 字幕解析
├── providers/                       # Riverpod 状态管理（代码生成）
│   ├── audio_library_provider.dart  #   音频库管理（导入/删除/路径迁移）
│   ├── collection_provider.dart     #   合集 CRUD + 排序
│   ├── settings_provider.dart       #   全局设置（主题/语言）
│   ├── audio_engine/
│   │   └── audio_engine_provider.dart  # 底层音频控制（封装 just_audio）
│   └── listening_practice/
│       ├── listening_practice_provider.dart  # 核心业务：播放模式/句子导航/书签
│       ├── sentence_tracker.dart     #   二分查找定位当前句子
│       ├── bookmark_manager.dart     #   书签持久化 + 去重逻辑
│       └── playback_state_storage.dart #  播放状态断点恢复
├── screens/                         # 页面级 UI 组件
│   ├── collection_screen.dart       #   合集列表页
│   ├── collection_detail_screen.dart#   合集详情页
│   ├── study_screen.dart            #   学习页（当前占位）
│   ├── favorites_screen.dart        #   收藏页（当前占位）
│   ├── player_screen.dart           #   播放器页（核心交互）
│   ├── library_screen.dart          #   音频库管理页
│   └── settings_screen.dart         #   设置页
├── widgets/                         # 可复用 UI 组件
│   ├── playback_controls.dart       #   播放控制面板
│   ├── sentence_list_view.dart      #   句子列表（滚动 + 高亮）
│   ├── settings_dialog.dart         #   播放设置弹窗
│   └── player_hotkey_scope.dart     #   桌面端键盘快捷键
└── theme/
    └── app_theme.dart               # 主题系统（Material 3，蓝色主色调）

test/                                # 单元测试 + Widget 测试
├── helpers/                         #   测试辅助（mock_providers, test_app）
├── models/                          #   6 个模型测试
├── providers/                       #   Provider 测试（含 listening_practice/）
├── screens/                         #   4 个页面 Widget 测试
├── services/                        #   SubtitleParser 测试
└── widgets/                         #   3 个组件测试

integration_test/                    # 端到端集成测试
├── app_test.dart                    #   入口
├── groups/                          #   按功能分组（collection, navigation, settings）
└── helpers/                         #   测试用 Notifier
```

### 关键文件速查

| 文件 | 行数 | 说明 |
|------|------|------|
| `listening_practice_provider.dart` | ~780 | **最核心文件**：双播放模式、句子导航、书签、状态恢复 |
| `audio_engine_provider.dart` | ~160 | 底层音频引擎，封装 just_audio |
| `player_screen.dart` | — | 播放器 UI，用户交互最集中的页面 |
| `app_theme.dart` | ~236 | 全局主题定义，修改视觉从这里开始 |
| `storage_service.dart` | ~127 | 所有持久化逻辑的入口 |
| `METHOD.md` | — | 学习方法论完整设计，Milestone 2 的需求文档 |

---

## 架构设计

### 2 层播放器架构

```
┌─────────────────────────────────────────────┐
│         ListeningPractice（业务层）           │
│  句子追踪 · 书签管理 · 循环播放 · 播放模式    │
├─────────────────────────────────────────────┤
│           AudioEngine（底层）                 │
│  封装 just_audio · 播放/暂停/seek/速度控制    │
└─────────────────────────────────────────────┘
```

- **AudioEngine**（底层）：封装 just_audio，提供播放、暂停、seek、速度控制等原子操作，不包含业务逻辑
- **ListeningPractice**（业务层）：基于 AudioEngine，实现句子追踪（二分查找定位当前句子）、书签管理、循环播放、播放模式切换等业务功能

### 状态管理

使用 Riverpod + 代码生成模式（`riverpod_generator`）。Provider 文件包含 `part 'xxx.g.dart';`，修改后需运行 `dart run build_runner build`。

### 依赖关系图

```
FluencyApp (main.dart)
├── AppTheme (theme)
├── AppSettings Provider (主题/语言)
├── AudioLibrary Provider (音频文件管理)
├── CollectionList Provider (合集管理)
└── Screens
    └── PlayerScreen → ListeningPractice Provider
                        ├── AudioEngine Provider → just_audio
                        ├── SentenceTracker (二分查找)
                        ├── BookmarkManager (书签持久化)
                        ├── PlaybackStateStorage (断点恢复)
                        └── StorageService → SharedPreferences
```

### 数据持久化

全部使用 SharedPreferences，按 key 分区存储：

| Key 模式 | 内容 |
|----------|------|
| `audio_library` | 音频库元数据列表 |
| `collections` | 合集列表 |
| `playback_settings` | 播放设置 |
| `bookmarks_<audioId>` | 每个音频的书签索引 |
| `playback_state_<audioId>` | 每个音频的播放断点 |

### 国际化

- Flutter 内置 `flutter_localizations` + ARB 文件
- 翻译文件位置：`lib/l10n/`
- 模板文件：`app_en.arb`，当前支持 en / zh
- 配置文件：`l10n.yaml`

---

## 关键架构决策记录 (ADR)

### ADR-1: 相对路径存储

**决策**：AudioItem 的音频/字幕路径存储为相对于 documents 目录的相对路径，而非绝对路径。

**原因**：绝对路径在不同设备、沙盒环境变化时会失效。相对路径保证数据可移植性。

**影响**：AudioLibraryProvider 包含自动迁移逻辑，将旧版绝对路径转换为相对路径。

### ADR-2: 两层播放器分离

**决策**：将音频播放分为 AudioEngine（底层原子操作）和 ListeningPractice（业务层流程控制）两层。

**原因**：
- 底层引擎可独立测试，不依赖业务逻辑
- 业务层可在不修改引擎的前提下扩展新的播放流程（如 Milestone 2 的首学/复习流程）
- 避免单一 Provider 过于庞大

**影响**：新增播放流程只需在业务层添加，不需要修改 AudioEngine。

### ADR-3: Session ID 隔离机制

**决策**：每次 play() 调用分配唯一 sessionId，后台任务在写入状态前必须校验 sessionId 是否仍然有效。

**原因**：用户可能在句子循环播放过程中快速切换到其他句子，如果不校验 session，旧的异步回调会覆盖新状态，导致 UI 跳回旧句子。

**影响**：所有异步播放逻辑必须持有 sessionId 并在每次状态更新前检查 `isActiveSession(id)`。

### ADR-4: 书签去重归一化

**决策**：切换书签时，对句子文本进行归一化（小写 + 去尾部标点），相同文本的所有句子同时添加/移除书签。

**原因**：同一句话可能在字幕中重复出现（如复述、回顾），用户意图是标记"这句话"而非"这个位置"。

**影响**：BookmarkManager 中的 `_normalizeForBookmarkComparison()` 负责归一化逻辑。

### ADR-5: 双播放模式动态切换

**决策**：支持两种播放模式——连续模式（全文自动播放）和字幕驱动模式（逐句控制 + 循环），根据用户设置动态切换。

**原因**：
- 连续模式适合"全文盲听"场景（Milestone 2 首学第一步）
- 字幕驱动模式适合"逐句精听"和"难句跟读"场景
- 两种模式共享同一套句子导航和书签系统

**切换条件**：`autoPlayNextSentenceEnabled=true` 且 `loopEnabled=false` 时为连续模式，否则为字幕驱动模式。

### ADR-6: SharedPreferences 作为唯一持久化方案

**决策**：当前阶段所有数据使用 SharedPreferences 存储，不引入数据库。

**原因**：
- 数据量小（音频元数据、设置、书签索引），SharedPreferences 足够
- 减少依赖复杂度，加快开发速度
- Milestone 2 的学习进度数据量增大后，可能需要迁移到 SQLite/Drift

**风险**：如果单个音频的书签/进度数据量很大，SharedPreferences 的序列化性能可能成为瓶颈。Milestone 4 需评估是否迁移。

---

## 学习流程设计

> 完整设计文档见 [METHOD.md](./METHOD.md)

### 核心理念

每篇音频经历 **9 个大阶段**的间隔复习周期：

```
首学(Day 0) → 首轮复习(5-8h后) → R1(1天) → R3(3天) → R5(5天)
→ R8(8天) → R11(11天) → R14(14天) → R21(21天·磨耳朵) → R28(28天·毕业检验)
```

### 首学流程

1. **全文盲听** — 不看字幕完整听 1-2 遍，感受大意，选择难度
2. **逐句精听+标注** — 逐句盲听，听不懂显示字幕；标记难句、难意群和生词
3. **难句跟读** — 有字幕跟读难句，遍数根据难度调整（2-5 遍）
4. **段级复述** — 提供关键意群提示，用自己的话复述段落

### 复习流程（R1-R14）

1. 全文盲听 → 2. 难句补练（盲听+跟读） → 3. 段级复述

### 毕业检验（R28）

1. 全文盲听 → 2. 全文跟读（不看字幕） → 3. 总结复述

### 收藏体系

- **难句子**为主要收藏单位，生词+意群高亮附属于句子
- 独立「单词+意群」本汇总查阅
- R1 及之后听懂的句子可取消收藏

---

## 里程碑

### ✅ Milestone 1: 基础播放器（已完成）

音频导入、三种播放模式（全文/单句/收藏）、循环播放、收藏、字幕显示与同步。

### 📋 Milestone 2: 学习流程引擎

实现 METHOD.md 中的阶段系统，包括：
- 首学流程（全文盲听、逐句精听、难句跟读、段级复述）
- 间隔复习调度（R1-R28 自动提醒）
- 学习进度记录（小阶段级别，支持断点续学）
- 难度评估（简单/中等/困难，影响遍数和间隔）

### 📋 Milestone 3: 收藏与标注体系

- 难句收藏（精听/复习中标记）
- 生词+意群高亮（附属于句子）
- 独立单词本（汇总所有标记的单词和意群）
- 收藏句子的复习与取消收藏逻辑

### 📋 Milestone 4: 体验优化与生产就绪

- 性能优化（大量音频、长列表）
- 错误处理与边界情况完善
- 多平台适配优化（macOS / iOS / Android / Web）
- 新材料推荐控制（每周 2-3 篇，超限提醒）
