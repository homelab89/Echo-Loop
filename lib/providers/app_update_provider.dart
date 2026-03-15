/// App 版本更新状态管理
///
/// 使用 Riverpod 管理版本更新检查流程：
/// - 冷启动时自动检查（同一自然日只检查一次）
/// - 支持手动检查（绕过节流和忽略逻辑）
/// - 用户忽略后记录版本号，同版本不再弹窗
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_update_info.dart';
import '../services/app_update_checker.dart';
import '../utils/version_compare.dart';
import 'package_info_provider.dart';

part 'app_update_provider.g.dart';

/// SharedPreferences key: 上次自动检查日期（yyyy-MM-dd 格式）
const _keyLastCheckDate = 'app_update_last_check_date';

/// SharedPreferences key: 用户已忽略的版本号
const _keyDismissedVersion = 'app_update_dismissed_version';

/// App 版本更新 Provider
@Riverpod(keepAlive: true)
class AppUpdate extends _$AppUpdate {
  AppUpdateChecker? _checker;

  @override
  AppUpdateState build() {
    _checker = AppUpdateChecker();
    ref.onDispose(() => _checker?.dispose());
    _scheduleCheck();
    return const AppUpdateInitial();
  }

  /// 冷启动自动检查（节流：同一自然日只检查一次）
  Future<void> _scheduleCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString();
    final lastCheck = prefs.getString(_keyLastCheckDate);

    if (lastCheck == today) return;

    await _performAutoCheck(prefs);
  }

  /// 手动检查（绕过节流和忽略逻辑）
  ///
  /// 返回检查结果，不更新 provider state，
  /// 避免 MainShell listener 重复弹窗。
  Future<AppUpdateResult> manualCheck() async {
    state = const AppUpdateChecking();

    final prefs = await SharedPreferences.getInstance();
    final info = await _checker?.check();
    await prefs.setString(_keyLastCheckDate, _todayString());

    final result = _buildResult(info: info, isManual: true);

    // 手动检查结束后恢复为初始状态，不触发 MainShell listener
    state = const AppUpdateInitial();
    return result;
  }

  /// 冷启动自动检查的内部实现
  Future<void> _performAutoCheck(SharedPreferences prefs) async {
    state = const AppUpdateChecking();

    final info = await _checker?.check();
    await prefs.setString(_keyLastCheckDate, _todayString());

    state = _buildResult(info: info, isManual: false, prefs: prefs);
  }

  /// 根据远程信息构建检查结果
  AppUpdateResult _buildResult({
    required AppUpdateInfo? info,
    required bool isManual,
    SharedPreferences? prefs,
  }) {
    if (info == null) {
      return const AppUpdateResult(type: AppUpdateType.none);
    }

    final localVersion = ref.read(packageInfoProvider).version;
    final updateType = determineUpdateType(localVersion, info);

    // 非手动检查时，检查是否已忽略此版本
    if (!isManual && updateType == AppUpdateType.softUpdate && prefs != null) {
      final dismissed = prefs.getString(_keyDismissedVersion);
      if (dismissed == info.latestVersion) {
        return const AppUpdateResult(type: AppUpdateType.none);
      }
    }

    return AppUpdateResult(type: updateType, info: info);
  }

  /// 用户点击"稍后提醒"，记录忽略版本
  Future<void> dismiss() async {
    final current = state;
    if (current is AppUpdateResult && current.info != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _keyDismissedVersion,
        current.info!.latestVersion,
      );
    }
    state = const AppUpdateDismissed();
  }

  /// 判断更新类型（static 公开方法，方便测试）
  static AppUpdateType determineUpdateType(
    String localVersion,
    AppUpdateInfo info,
  ) {
    if (compareVersions(localVersion, info.minimumVersion) < 0) {
      return AppUpdateType.forceUpdate;
    }
    if (compareVersions(localVersion, info.latestVersion) < 0) {
      return AppUpdateType.softUpdate;
    }
    return AppUpdateType.none;
  }

  /// 获取当前平台的下载链接
  static String? getDownloadUrl(AppUpdateInfo info) {
    if (kIsWeb) return info.downloadUrl['fallback'];
    final platformKey = _platformKey();
    return info.downloadUrl[platformKey] ?? info.downloadUrl['fallback'];
  }

  static String _platformKey() {
    if (kIsWeb) return 'fallback';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isAndroid) return 'android';
    return 'fallback';
  }

  static String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
