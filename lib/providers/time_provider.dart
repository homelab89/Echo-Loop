import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_provider.dart';

/// 当前时间读取函数类型。
typedef NowGetter = DateTime Function();

/// 统一的当前时间 Provider。
///
/// 正常模式使用系统时间；开启「解锁所有复习」后返回一年后的时间，
/// 使所有复习立即可用，方便开发测试。
/// 测试中可 override 为固定时间。
final nowProvider = Provider<NowGetter>((ref) {
  final unlockAllReviews = ref.watch(
    appSettingsProvider.select((s) => s.unlockAllReviews),
  );
  if (unlockAllReviews) {
    return () => DateTime.now().add(const Duration(days: 365));
  }
  return DateTime.now;
});
