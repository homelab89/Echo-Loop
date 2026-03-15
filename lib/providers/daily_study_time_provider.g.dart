// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_study_time_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$dailyStudyTimeHash() => r'7008f1036f97a628b5d9bedae706f44f6ade3964';

/// 今日学习时长 Provider（秒）
///
/// 从 SQLite 读取今日累计学习秒数。
/// 每次进入/退出学习模式后刷新。
///
/// Copied from [DailyStudyTime].
@ProviderFor(DailyStudyTime)
final dailyStudyTimeProvider =
    AutoDisposeAsyncNotifierProvider<DailyStudyTime, int>.internal(
      DailyStudyTime.new,
      name: r'dailyStudyTimeProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$dailyStudyTimeHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$DailyStudyTime = AutoDisposeAsyncNotifier<int>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
