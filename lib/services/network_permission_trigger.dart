/// iOS 网络权限触发器。
///
/// Flutter 的 `dart:io` HttpClient 绕过 iOS 原生网络栈，
/// 不会触发系统网络权限弹窗。本类通过 method channel 调用
/// 原生 URLSession 发起一次请求，确保系统弹窗呈现。
///
/// 同时把"曾经成功过"持久化到 SP，供启动埋点 [PermissionSnapshot]
/// 推断网络授权状态。失败 / 超时不写 SP，避免飞行模式 / 弱网 /
/// 服务端故障被误判为 denied。
library;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../analytics/permission_snapshot.dart';

class NetworkPermissionTrigger {
  /// Method channel 名（与 iOS AppDelegate 保持一致）。
  @visibleForTesting
  static const channel = MethodChannel('top.echo-loop/network');

  /// 触发一次原生 dataTask；成功（响应 `{ok: true}`）写 SP，
  /// 失败 / 超时 / 异常静默忽略，不写 SP。
  static Future<void> trigger(SharedPreferences prefs, String url) async {
    try {
      final res = await channel.invokeMapMethod<String, Object?>(
        'triggerNetworkPermission',
        {'url': url},
      );
      if (res != null && res['ok'] == true) {
        await prefs.setBool(PermissionSnapshot.spKeyNetworkOk, true);
      }
    } catch (_) {
      // 静默：触发本身永远不阻塞启动
    }
  }
}
