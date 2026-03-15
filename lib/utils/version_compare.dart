/// 版本号比较工具
///
/// 提供 semver 风格的版本号比较，支持容错处理：
/// - null / "" → [0, 0, 0]
/// - "1.0" → [1, 0, 0]（自动补零）
/// - "1.0.0-beta" → [1, 0, 0]（去除后缀）
/// - "abc" / "1.x.0" → 对应段解析为 0
/// - 任何输入都不抛异常
library;

/// 将版本号字符串解析为整数列表
///
/// 容错处理：去除后缀、自动补零、非法段解析为 0。
List<int> parseVersion(String? version) {
  if (version == null || version.isEmpty) return [0, 0, 0];

  // 去除 "v" 前缀（如 "v1.0.0"）
  final cleaned = version.startsWith('v') || version.startsWith('V')
      ? version.substring(1)
      : version;

  // 取第一个 "-" 或 "+" 前的部分（去除 pre-release 后缀）
  final core = cleaned.split(RegExp(r'[-+]')).first;

  final parts = core.split('.');
  final result = <int>[];
  for (var i = 0; i < 3; i++) {
    if (i < parts.length) {
      result.add(int.tryParse(parts[i]) ?? 0);
    } else {
      result.add(0);
    }
  }
  return result;
}

/// 比较两个版本号
///
/// 返回值：
/// - 负数：a < b
/// - 0：a == b
/// - 正数：a > b
int compareVersions(String? a, String? b) {
  final va = parseVersion(a);
  final vb = parseVersion(b);
  for (var i = 0; i < 3; i++) {
    if (va[i] != vb[i]) return va[i] - vb[i];
  }
  return 0;
}

/// 判断远程版本是否比本地版本更新
bool isNewerVersion({
  required String? localVersion,
  required String? remoteVersion,
}) {
  return compareVersions(remoteVersion, localVersion) > 0;
}
