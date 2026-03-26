/// 通用按压反馈包裹器
///
/// 为任意子组件添加按压态视觉反馈（opacity / scale / 两者组合）。
/// 通过 [GestureDetector] 监听 onTapDown/Up/Cancel 驱动动画。
///
/// 用法：
/// ```dart
/// TappableWrapper(
///   onTap: () => doSomething(),
///   feedbackType: TapFeedback.scale,
///   child: MyCustomButton(),
/// )
/// ```
library;

import 'package:flutter/widgets.dart';

/// 反馈类型
enum TapFeedback {
  /// 按压时降低透明度
  opacity,

  /// 按压时缩小
  scale,

  /// 同时降低透明度和缩小
  opacityAndScale,
}

/// 通用按压反馈包裹器
class TappableWrapper extends StatefulWidget {
  /// 子组件
  final Widget child;

  /// 点击回调（null 时禁用交互）
  final VoidCallback? onTap;

  /// 反馈类型
  final TapFeedback feedbackType;

  /// scale 模式下按压时的缩放比例（默认 0.92）
  final double scaleDown;

  /// opacity 模式下按压时的透明度（默认 0.5）
  final double pressedOpacity;

  /// 动画时长（默认 100ms）
  final Duration duration;

  const TappableWrapper({
    super.key,
    required this.child,
    this.onTap,
    this.feedbackType = TapFeedback.opacity,
    this.scaleDown = 0.92,
    this.pressedOpacity = 0.5,
    this.duration = const Duration(milliseconds: 100),
  });

  @override
  State<TappableWrapper> createState() => _TappableWrapperState();
}

class _TappableWrapperState extends State<TappableWrapper> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap == null) return;
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails _) {
    if (!_isPressed) return;
    setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    if (!_isPressed) return;
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final useScale =
        widget.feedbackType == TapFeedback.scale ||
        widget.feedbackType == TapFeedback.opacityAndScale;
    final useOpacity =
        widget.feedbackType == TapFeedback.opacity ||
        widget.feedbackType == TapFeedback.opacityAndScale;

    final targetScale = _isPressed ? widget.scaleDown : 1.0;
    final targetOpacity = _isPressed ? widget.pressedOpacity : 1.0;

    Widget child = widget.child;

    if (useScale) {
      child = AnimatedScale(
        scale: targetScale,
        duration: widget.duration,
        curve: Curves.easeOut,
        child: child,
      );
    }

    if (useOpacity) {
      child = AnimatedOpacity(
        opacity: targetOpacity,
        duration: widget.duration,
        child: child,
      );
    }

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}
