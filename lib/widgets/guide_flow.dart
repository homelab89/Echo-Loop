import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:showcaseview/showcaseview.dart';

import '../l10n/app_localizations.dart';
import '../providers/new_user_guide_provider.dart';
import '../services/app_logger.dart';

/// 引导步骤推进方式。
enum GuideAdvanceMode {
  /// 说明型步骤：用户点击 tooltip 的“下一步/完成”推进。
  tooltipAction,

  /// 操作型步骤：用户点击被高亮目标后执行业务动作并推进。
  targetAction,
}

/// 单个页面级引导步骤。
class GuideStep {
  final String targetId;
  final String title;
  final String description;
  final GuideAdvanceMode advanceMode;

  /// 当前步骤虽然会完成独立 flow，但视觉上仍应提示用户继续下一段引导。
  final bool preferNextAction;

  const GuideStep({
    required this.targetId,
    required this.title,
    required this.description,
    this.advanceMode = GuideAdvanceMode.tooltipAction,
    this.preferNextAction = false,
  });
}

/// 在 screen 内声明并启动一个页面级 flow。
///
/// 该组件不关心其它 screen 的引导，只在 [shouldRun] 为 true 且当前
/// widget 树存在 [ShowCaseWidget] 时尝试启动当前 flow。
class GuideFlowHost extends ConsumerStatefulWidget {
  final String flowId;
  final bool shouldRun;
  final List<GuideStep> steps;
  final Widget child;

  const GuideFlowHost({
    super.key,
    required this.flowId,
    required this.shouldRun,
    required this.steps,
    required this.child,
  });

  @override
  ConsumerState<GuideFlowHost> createState() => _GuideFlowHostState();
}

class _GuideFlowHostState extends ConsumerState<GuideFlowHost> {
  ProviderSubscription<GuideControllerState>? _guideSubscription;
  bool _startScheduled = false;
  int _lastResetGeneration = 0;

  @override
  void initState() {
    super.initState();
    _guideSubscription = ref.listenManual<GuideControllerState>(
      guideControllerProvider,
      (_, next) {
        if (!mounted || next.isActive) return;
        _startScheduled = false;
        _scheduleStart();
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) _scheduleStart();
    });
  }

  @override
  void didUpdateWidget(covariant GuideFlowHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flowId != widget.flowId ||
        oldWidget.shouldRun != widget.shouldRun ||
        oldWidget.steps.map((s) => s.targetId).join('|') !=
            widget.steps.map((s) => s.targetId).join('|')) {
      _startScheduled = false;
      _scheduleStart();
    }
  }

  @override
  void dispose() {
    _guideSubscription?.close();
    super.dispose();
  }

  void _scheduleStart() {
    if (_startScheduled ||
        !widget.shouldRun ||
        widget.steps.isEmpty ||
        !TickerMode.valuesOf(context).enabled) {
      AppLogger.log(
        'Guide',
        'host start not scheduled flow=${widget.flowId} '
            'alreadyScheduled=$_startScheduled shouldRun=${widget.shouldRun} '
            'steps=${widget.steps.length} ticker=${TickerMode.valuesOf(context).enabled}',
      );
      return;
    }
    _startScheduled = true;
    AppLogger.log(
      'Guide',
      'host scheduleStart flow=${widget.flowId} '
          'targets=${widget.steps.map((s) => s.targetId).join(",")}',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        AppLogger.log(
          'Guide',
          'host start aborted flow=${widget.flowId} reason=unmounted',
        );
        return;
      }
      if (!TickerMode.valuesOf(context).enabled) {
        _startScheduled = false;
        AppLogger.log(
          'Guide',
          'host start aborted flow=${widget.flowId} reason=inactiveTicker',
        );
        return;
      }
      final showcase = context.findAncestorStateOfType<ShowCaseWidgetState>();
      if (showcase == null) {
        _startScheduled = false;
        AppLogger.log(
          'Guide',
          'host start aborted flow=${widget.flowId} reason=noShowCaseWidget',
        );
        return;
      }

      final started = await ref
          .read(guideControllerProvider.notifier)
          .startFlow(
            flowId: widget.flowId,
            targetIds: widget.steps.map((s) => s.targetId).toList(),
          );
      if (!mounted) return;
      if (!started) {
        _startScheduled = false;
        AppLogger.log(
          'Guide',
          'host start released flow=${widget.flowId} reason=startRejected',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final resetGeneration = ref.watch(
      guideControllerProvider.select((state) => state.resetGeneration),
    );
    if (_lastResetGeneration != resetGeneration) {
      AppLogger.log(
        'Guide',
        'host reset observed flow=${widget.flowId} '
            'from=$_lastResetGeneration to=$resetGeneration',
      );
      _lastResetGeneration = resetGeneration;
      _startScheduled = false;
    }
    if (TickerMode.valuesOf(context).enabled) {
      _scheduleStart();
    }
    return widget.child;
  }
}

/// 可复用的 showcase target 包装器。
///
/// screen 只需要用该组件包住目标控件，并传入对应 flow/target 信息。
class GuideTarget extends ConsumerStatefulWidget {
  final String flowId;
  final GuideStep step;
  final Widget child;
  final bool advanceOnTargetTap;
  final FutureOr<void> Function()? onTargetAction;

  const GuideTarget({
    super.key,
    required this.flowId,
    required this.step,
    required this.child,
    this.advanceOnTargetTap = false,
    this.onTargetAction,
  });

  @override
  ConsumerState<GuideTarget> createState() => _GuideTargetState();
}

class _GuideTargetState extends ConsumerState<GuideTarget> {
  final GlobalKey _showcaseKey = GlobalKey();
  ProviderSubscription<GuideControllerState>? _guideSubscription;
  int? _startedSessionId;

  @override
  void initState() {
    super.initState();
    _guideSubscription = ref.listenManual<GuideControllerState>(
      guideControllerProvider,
      (_, next) {
        if (_isCurrentTarget(next)) {
          _startShowcase(next.sessionId);
        }
      },
      fireImmediately: true,
    );
  }

  @override
  void didUpdateWidget(covariant GuideTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final state = ref.read(guideControllerProvider);
    if (_isCurrentTarget(state)) {
      _startShowcase(state.sessionId);
    }
  }

  @override
  void dispose() {
    _guideSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(guideControllerProvider);
    final isCurrent = _isCurrentTarget(state);
    final requiresTargetAction =
        widget.advanceOnTargetTap ||
        widget.step.advanceMode == GuideAdvanceMode.targetAction;

    return Showcase(
      key: _showcaseKey,
      title: widget.step.title,
      description: widget.step.description,
      targetPadding: const EdgeInsets.all(6),
      tooltipActionConfig: const TooltipActionConfig(
        alignment: MainAxisAlignment.end,
      ),
      tooltipActions: requiresTargetAction
          ? const []
          : [
              _nextAction(
                context,
                l10n,
                state.isLastStep && !widget.step.preferNextAction,
              ),
            ],
      onBarrierClick: requiresTargetAction ? null : _advanceFromPassiveTap,
      disableBarrierInteraction: requiresTargetAction,
      onTargetClick: requiresTargetAction
          ? () => unawaited(_handleTargetClick())
          : _ignoreTargetClick,
      disposeOnTap: requiresTargetAction,
      child: isCurrent
          ? Semantics(label: widget.step.title, child: widget.child)
          : widget.child,
    );
  }

  bool _isCurrentTarget(GuideControllerState state) {
    return state.activeFlowId == widget.flowId &&
        state.activeTargetId == widget.step.targetId;
  }

  void _startShowcase(int sessionId) {
    if (_startedSessionId == sessionId) {
      AppLogger.log(
        'Guide',
        'target start skipped flow=${widget.flowId} '
            'target=${widget.step.targetId} reason=sameSession '
            'session=$sessionId',
      );
      return;
    }
    _startedSessionId = sessionId;
    _scheduleShowcaseStart(sessionId, 0);
  }

  void _scheduleShowcaseStart(int sessionId, int attempt) {
    AppLogger.log(
      'Guide',
      'target scheduleShowcase flow=${widget.flowId} '
          'target=${widget.step.targetId} session=$sessionId attempt=$attempt',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        AppLogger.log(
          'Guide',
          'target start aborted flow=${widget.flowId} '
              'target=${widget.step.targetId} reason=unmounted',
        );
        return;
      }
      final state = ref.read(guideControllerProvider);
      if (!_isCurrentTarget(state)) {
        AppLogger.log(
          'Guide',
          'target start aborted flow=${widget.flowId} '
              'target=${widget.step.targetId} reason=notCurrent '
              'activeFlow=${state.activeFlowId} '
              'activeTarget=${state.activeTargetId}',
        );
        return;
      }
      final showcase = context.findAncestorStateOfType<ShowCaseWidgetState>();
      if (showcase == null) {
        _retryShowcaseStart(sessionId, attempt, 'noShowCaseWidget');
        return;
      }
      AppLogger.log(
        'Guide',
        'target startShowcase flow=${widget.flowId} '
            'target=${widget.step.targetId} session=$sessionId',
      );
      // ignore: deprecated_member_use
      showcase.startShowCase([_showcaseKey]);
    });
  }

  void _retryShowcaseStart(int sessionId, int attempt, String reason) {
    if (attempt >= 3) {
      AppLogger.log(
        'Guide',
        'target start aborted flow=${widget.flowId} '
            'target=${widget.step.targetId} reason=$reason '
            'session=$sessionId attempts=$attempt',
      );
      return;
    }
    AppLogger.log(
      'Guide',
      'target start retry flow=${widget.flowId} '
          'target=${widget.step.targetId} reason=$reason '
          'session=$sessionId nextAttempt=${attempt + 1}',
    );
    Future.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      _scheduleShowcaseStart(sessionId, attempt + 1);
    });
  }

  TooltipActionButton _nextAction(
    BuildContext context,
    AppLocalizations l10n,
    bool showDone,
  ) {
    return TooltipActionButton(
      type: TooltipDefaultActionType.next,
      name: showDone ? l10n.guideDone : l10n.guideNext,
      onTap: () {
        AppLogger.log(
          'Guide',
          'tooltip action flow=${widget.flowId} '
              'target=${widget.step.targetId} showDone=$showDone',
        );
        final showcase = context.findAncestorStateOfType<ShowCaseWidgetState>();
        // ignore: deprecated_member_use
        showcase?.dismiss();
        unawaited(
          ref.read(guideControllerProvider.notifier).advanceActiveFlow(),
        );
      },
    );
  }

  void _ignoreTargetClick() {
    AppLogger.log(
      'Guide',
      'target click ignored flow=${widget.flowId} '
          'target=${widget.step.targetId} reason=passiveStep',
    );
  }

  void _advanceFromPassiveTap() {
    AppLogger.log(
      'Guide',
      'barrier advance flow=${widget.flowId} target=${widget.step.targetId}',
    );
    final showcase = context.findAncestorStateOfType<ShowCaseWidgetState>();
    // ignore: deprecated_member_use
    showcase?.dismiss();
    unawaited(ref.read(guideControllerProvider.notifier).advanceActiveFlow());
  }

  Future<void> _handleTargetClick() async {
    AppLogger.log(
      'Guide',
      'target click flow=${widget.flowId} target=${widget.step.targetId}',
    );
    if (widget.onTargetAction != null) {
      await widget.onTargetAction!();
    }
    await ref.read(guideControllerProvider.notifier).advanceActiveFlow();
  }
}
