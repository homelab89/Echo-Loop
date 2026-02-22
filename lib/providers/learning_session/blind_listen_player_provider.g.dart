// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'blind_listen_player_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$blindListenPlayerHash() => r'fa1ffeec41088fa9abf8a9922d52b98c075d4575';

/// 盲听专用播放器 Provider
///
/// 直接操作 AudioEngine，只提供盲听所需的最小控制集：
/// 播放、暂停、拖动进度条、完成检测、重播。
///
/// Copied from [BlindListenPlayer].
@ProviderFor(BlindListenPlayer)
final blindListenPlayerProvider =
    NotifierProvider<BlindListenPlayer, BlindListenPlayerState>.internal(
      BlindListenPlayer.new,
      name: r'blindListenPlayerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$blindListenPlayerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$BlindListenPlayer = Notifier<BlindListenPlayerState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
