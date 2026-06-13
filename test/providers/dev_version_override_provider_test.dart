import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/providers/dev_version_override_provider.dart';

void main() {
  group('DevVersionOverride', () {
    test('初始为 null（未覆盖）', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(devVersionOverrideProvider), isNull);
    });

    test('设置覆盖版本号', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(devVersionOverrideProvider.notifier).setOverride('1.0.0');

      expect(container.read(devVersionOverrideProvider), '1.0.0');
    });

    test('设置时去除首尾空白', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(devVersionOverrideProvider.notifier)
          .setOverride('  1.2.3  ');

      expect(container.read(devVersionOverrideProvider), '1.2.3');
    });

    test('空串清除覆盖', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(devVersionOverrideProvider.notifier);
      notifier.setOverride('1.0.0');
      notifier.setOverride('');

      expect(container.read(devVersionOverrideProvider), isNull);
    });

    test('null 清除覆盖', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(devVersionOverrideProvider.notifier);
      notifier.setOverride('1.0.0');
      notifier.setOverride(null);

      expect(container.read(devVersionOverrideProvider), isNull);
    });

    test('不持久化：新建 container 后恢复为 null（模拟重启）', () {
      final container1 = ProviderContainer();
      container1.read(devVersionOverrideProvider.notifier).setOverride('1.0.0');
      expect(container1.read(devVersionOverrideProvider), '1.0.0');
      container1.dispose();

      // 重启相当于全新的 ProviderContainer，覆盖值不应残留
      final container2 = ProviderContainer();
      addTearDown(container2.dispose);
      expect(container2.read(devVersionOverrideProvider), isNull);
    });
  });
}
