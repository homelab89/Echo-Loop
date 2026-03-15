import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/utils/version_compare.dart';

void main() {
  group('parseVersion', () {
    test('解析标准版本号', () {
      expect(parseVersion('1.2.3'), [1, 2, 3]);
    });

    test('null 返回 [0, 0, 0]', () {
      expect(parseVersion(null), [0, 0, 0]);
    });

    test('空字符串返回 [0, 0, 0]', () {
      expect(parseVersion(''), [0, 0, 0]);
    });

    test('两段版本号自动补零', () {
      expect(parseVersion('1.0'), [1, 0, 0]);
    });

    test('单段版本号自动补零', () {
      expect(parseVersion('3'), [3, 0, 0]);
    });

    test('去除 pre-release 后缀', () {
      expect(parseVersion('1.0.0-beta'), [1, 0, 0]);
    });

    test('去除 build 后缀', () {
      expect(parseVersion('2.1.0+42'), [2, 1, 0]);
    });

    test('去除 v 前缀', () {
      expect(parseVersion('v1.2.3'), [1, 2, 3]);
    });

    test('非法段解析为 0', () {
      expect(parseVersion('1.x.0'), [1, 0, 0]);
    });

    test('完全非法字符串', () {
      expect(parseVersion('abc'), [0, 0, 0]);
    });
  });

  group('compareVersions', () {
    test('相同版本返回 0', () {
      expect(compareVersions('1.0.0', '1.0.0'), 0);
    });

    test('a > b 返回正数', () {
      expect(compareVersions('1.1.0', '1.0.0'), greaterThan(0));
    });

    test('a < b 返回负数', () {
      expect(compareVersions('1.0.0', '1.1.0'), lessThan(0));
    });

    test('patch 版本比较', () {
      expect(compareVersions('1.0.1', '1.0.0'), greaterThan(0));
    });

    test('major 版本比较', () {
      expect(compareVersions('2.0.0', '1.9.9'), greaterThan(0));
    });

    test('null 与 null 相等', () {
      expect(compareVersions(null, null), 0);
    });

    test('null 小于任何版本', () {
      expect(compareVersions(null, '1.0.0'), lessThan(0));
    });
  });

  group('isNewerVersion', () {
    test('远程版本更新时返回 true', () {
      expect(
        isNewerVersion(localVersion: '1.0.0', remoteVersion: '1.1.0'),
        isTrue,
      );
    });

    test('远程版本相同时返回 false', () {
      expect(
        isNewerVersion(localVersion: '1.0.0', remoteVersion: '1.0.0'),
        isFalse,
      );
    });

    test('远程版本更旧时返回 false', () {
      expect(
        isNewerVersion(localVersion: '1.1.0', remoteVersion: '1.0.0'),
        isFalse,
      );
    });
  });
}
