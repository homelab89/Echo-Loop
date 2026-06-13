/// 开发者版本号覆盖 Provider
///
/// 仅用于开发者测试版本更新流程：设置一个虚拟的本地版本号，
/// 让 [AppUpdate] 在比较远程版本时使用此值而非真实的 [PackageInfo.version]，
/// 从而无需重新打包即可触发 soft / force update 弹窗。
///
/// - 值为 null 或空串：不覆盖，使用真实版本号
/// - **仅保存在内存中，不持久化**：热重启 / 重启 App 后自动重置为 null，
///   避免冷启动自动检查时卡在强制更新弹窗里出不来。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 开发者版本号覆盖 Provider。
///
/// state 为被覆盖的版本号字符串；null 表示未覆盖（使用真实版本号）。
final devVersionOverrideProvider =
    NotifierProvider<DevVersionOverride, String?>(DevVersionOverride.new);

/// 开发者版本号覆盖状态管理。
class DevVersionOverride extends Notifier<String?> {
  @override
  String? build() => null;

  /// 设置覆盖版本号（仅内存，重启即失效）。
  ///
  /// [version] 为空串或 null 时清除覆盖。
  void setOverride(String? version) {
    final normalized = (version == null || version.trim().isEmpty)
        ? null
        : version.trim();
    state = normalized;
  }
}
