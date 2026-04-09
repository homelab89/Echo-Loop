/// 离线 ASR 功能设置 Provider。
///
/// 管理本地语音识别的开关状态、模型下载、引擎初始化。
/// 独立于 [AppSettings]，遵循"Provider 按功能域拆分"原则。
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/asr/asr_model_manager.dart';
import '../services/asr/offline_asr_engine.dart';
import 'asr_engine_provider.dart';

const _enabledKey = 'offline_asr_enabled';
const _promptDismissedKey = 'offline_asr_prompt_dismissed';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// 离线 ASR 功能的完整 UI 状态。
class OfflineAsrSettingsState {
  /// 功能开关：null=未设置, true=开启, false=关闭。
  final bool? enabled;

  /// 模型下载状态。
  final AsrModelDownloadStatus downloadStatus;

  /// 下载进度 0.0~1.0。
  final double downloadProgress;

  /// 模型本地占用空间（字节）。
  final int localSizeBytes;

  /// 错误信息。
  final String? errorMessage;

  /// 是否已向用户展示过首次引导弹窗。
  final bool promptDismissed;

  /// 引擎是否已就绪（模型已加载到内存）。
  final bool engineReady;

  /// 推荐的模型信息。
  final AsrModelInfo recommendedModel;

  const OfflineAsrSettingsState({
    this.enabled,
    this.downloadStatus = AsrModelDownloadStatus.notDownloaded,
    this.downloadProgress = 0,
    this.localSizeBytes = 0,
    this.errorMessage,
    this.promptDismissed = false,
    this.engineReady = false,
    required this.recommendedModel,
  });

  /// 是否需要首次引导弹窗。
  bool get needsPrompt => enabled != true && !promptDismissed;

  /// 是否需要修复弹窗（已启用但模型不完整）。
  bool get needsRepairPrompt =>
      enabled == true && downloadStatus != AsrModelDownloadStatus.downloaded;

  /// 是否可以删除模型（关闭 + 已下载）。
  bool get canDelete =>
      enabled != true && downloadStatus == AsrModelDownloadStatus.downloaded;

  /// 是否正在下载。
  bool get isDownloading =>
      downloadStatus == AsrModelDownloadStatus.downloading;

  /// 功能是否完全就绪可用。
  bool get isFullyReady =>
      enabled == true &&
      downloadStatus == AsrModelDownloadStatus.downloaded &&
      engineReady;

  OfflineAsrSettingsState copyWith({
    bool? enabled,
    bool clearEnabled = false,
    AsrModelDownloadStatus? downloadStatus,
    double? downloadProgress,
    int? localSizeBytes,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? promptDismissed,
    bool? engineReady,
  }) {
    return OfflineAsrSettingsState(
      enabled: clearEnabled ? null : (enabled ?? this.enabled),
      downloadStatus: downloadStatus ?? this.downloadStatus,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      localSizeBytes: localSizeBytes ?? this.localSizeBytes,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      promptDismissed: promptDismissed ?? this.promptDismissed,
      engineReady: engineReady ?? this.engineReady,
      recommendedModel: recommendedModel,
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// 离线 ASR 功能设置 Provider（keepAlive，全局单例）。
final offlineAsrSettingsProvider =
    NotifierProvider<OfflineAsrSettingsNotifier, OfflineAsrSettingsState>(
      OfflineAsrSettingsNotifier.new,
    );

/// 当前设备是否需要本地 ASR（Android 无 GMS）。
///
/// 在 main() 中一次性检测并通过 override 注入，全局不变。
/// 默认 false（iOS/macOS/有 GMS 的 Android）。
final needsLocalAsrProvider = Provider<bool>((ref) => false);

/// 推荐的 ASR 模型（main() 中一次性计算并 override 注入）。
final recommendedAsrModelProvider = Provider<AsrModelInfo>(
  (ref) => throw UnimplementedError('Must be overridden in main()'),
);

/// 离线 ASR 设置 Notifier。
class OfflineAsrSettingsNotifier extends Notifier<OfflineAsrSettingsState> {
  CancelToken? _downloadCancelToken;

  @override
  OfflineAsrSettingsState build() {
    final recommended = ref.read(recommendedAsrModelProvider);

    ref.onDispose(() {
      _downloadCancelToken?.cancel();
    });

    // 异步加载持久化状态。
    _loadPersistedState(recommended.id);

    return OfflineAsrSettingsState(recommendedModel: recommended);
  }

  /// 从 SharedPreferences 加载 + 检查模型一致性。
  Future<void> _loadPersistedState(String modelId) async {
    final prefs = await SharedPreferences.getInstance();

    // enabled 三态：key 不存在=null, true, false。
    final bool? enabled;
    if (prefs.containsKey(_enabledKey)) {
      enabled = prefs.getBool(_enabledKey);
    } else {
      enabled = null;
    }

    final promptDismissed = prefs.getBool(_promptDismissedKey) ?? false;
    final modelManager = ref.read(asrModelManagerProvider);
    final downloaded = await modelManager.isModelDownloaded(modelId);
    final localSize = downloaded
        ? await modelManager.modelLocalSize(modelId)
        : 0;

    state = state.copyWith(
      enabled: enabled,
      promptDismissed: promptDismissed,
      downloadStatus: downloaded
          ? AsrModelDownloadStatus.downloaded
          : AsrModelDownloadStatus.notDownloaded,
      localSizeBytes: localSize,
    );

    // 引擎不在启动时加载，进入录音页面时按需加载、退出时卸载。
  }

  /// 开启功能。
  ///
  /// 模型已下载 → 直接初始化引擎。
  /// 模型未下载 → 自动触发下载。
  Future<void> enable() async {
    // 已在下载中，不重复触发。
    if (state.isDownloading) return;

    final modelId = state.recommendedModel.id;
    final modelManager = ref.read(asrModelManagerProvider);
    final downloaded = await modelManager.isModelDownloaded(modelId);

    if (downloaded) {
      final localSize = await modelManager.modelLocalSize(modelId);
      state = state.copyWith(
        enabled: true,
        downloadStatus: AsrModelDownloadStatus.downloaded,
        localSizeBytes: localSize,
        clearErrorMessage: true,
      );
      await _persistEnabled(true);
      // 引擎不在此处加载，进入录音页面时按需加载。
    } else {
      // 先标记 enabled，下载完成后引擎自动初始化。
      state = state.copyWith(enabled: true, clearErrorMessage: true);
      await _persistEnabled(true);
      await _downloadAndInitialize(modelId);
    }
  }

  /// 关闭功能（不删除模型文件）。
  Future<void> disable() async {
    await unloadEngine();
    state = state.copyWith(enabled: false, engineReady: false);
    await _persistEnabled(false);
  }

  /// 按需加载引擎（进入录音页面时调用，不阻塞 UI）。
  Future<void> loadEngine() async {
    if (state.engineReady) return;
    if (state.enabled != true) return;
    if (state.downloadStatus != AsrModelDownloadStatus.downloaded) return;
    await _initializeEngine(state.recommendedModel.id);
  }

  /// 卸载引擎释放内存（退出录音页面时调用）。
  Future<void> unloadEngine() async {
    if (!state.engineReady) return;
    final engine = ref.read(offlineAsrEngineProvider);
    await engine.dispose();
    state = state.copyWith(engineReady: false);
  }

  /// 关闭功能并删除模型。
  Future<void> disableAndDelete() async {
    await disable();
    await deleteModel();
  }

  /// 删除本地模型（仅关闭时可调用）。
  Future<void> deleteModel() async {
    if (state.enabled == true) return;
    final modelManager = ref.read(asrModelManagerProvider);
    await modelManager.deleteModel(state.recommendedModel.id);
    state = state.copyWith(
      downloadStatus: AsrModelDownloadStatus.notDownloaded,
      localSizeBytes: 0,
    );
  }

  /// 重试下载。
  Future<void> retryDownload() async {
    state = state.copyWith(clearErrorMessage: true);
    await _downloadAndInitialize(state.recommendedModel.id);
  }

  /// 标记首次弹窗已展示。
  Future<void> dismissPrompt() async {
    state = state.copyWith(promptDismissed: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_promptDismissedKey, true);
  }

  /// 取消正在进行的下载。
  void cancelDownload() {
    _downloadCancelToken?.cancel();
    _downloadCancelToken = null;
    state = state.copyWith(
      downloadStatus: AsrModelDownloadStatus.notDownloaded,
      downloadProgress: 0,
    );
  }

  // ---------------------------------------------------------------------------
  // 内部方法
  // ---------------------------------------------------------------------------

  Future<void> _downloadAndInitialize(String modelId) async {
    state = state.copyWith(
      downloadStatus: AsrModelDownloadStatus.downloading,
      downloadProgress: 0,
    );

    _downloadCancelToken = CancelToken();
    final modelManager = ref.read(asrModelManagerProvider);

    try {
      await modelManager.downloadModel(
        modelId,
        cancelToken: _downloadCancelToken,
        onProgress: (progress) {
          if (_downloadCancelToken?.isCancelled ?? true) return;
          state = state.copyWith(downloadProgress: progress.progress);
        },
      );

      _downloadCancelToken = null;
      final localSize = await modelManager.modelLocalSize(modelId);

      state = state.copyWith(
        downloadStatus: AsrModelDownloadStatus.downloaded,
        downloadProgress: 1.0,
        localSizeBytes: localSize,
      );

      await _initializeEngine(modelId);
    } on DioException catch (e) {
      _downloadCancelToken = null;
      if (e.type == DioExceptionType.cancel) {
        state = state.copyWith(
          downloadStatus: AsrModelDownloadStatus.notDownloaded,
          downloadProgress: 0,
        );
      } else {
        state = state.copyWith(
          downloadStatus: AsrModelDownloadStatus.failed,
          errorMessage: e.message ?? 'Download failed',
        );
      }
    } catch (e) {
      _downloadCancelToken = null;
      state = state.copyWith(
        downloadStatus: AsrModelDownloadStatus.failed,
        errorMessage: '$e',
      );
    }
  }

  Future<void> _initializeEngine(String modelId) async {
    final engine = ref.read(offlineAsrEngineProvider);
    final modelManager = ref.read(asrModelManagerProvider);
    final modelDir = await modelManager.modelDir(modelId);

    try {
      await engine.initialize(
        AsrModelConfig(model: state.recommendedModel, modelDir: modelDir),
      );
      state = state.copyWith(engineReady: true);
    } catch (e) {
      state = state.copyWith(
        engineReady: false,
        errorMessage: 'Engine initialization failed: $e',
      );
    }
  }

  Future<void> _persistEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }
}
