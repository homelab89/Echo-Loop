/// AI 单词解析 Provider
///
/// 三级缓存查找：L1 内存 → L2 SQLite → L3 API。
/// 支持并发请求去重，避免同一单词重复发起 API 调用。
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/daos/sentence_ai_cache_dao.dart';
import '../database/providers.dart';
import '../models/word_analysis.dart';
import '../services/sentence_ai_api_client.dart';
import '../utils/text_normalize.dart';

/// AI 单词解析服务
///
/// 通过三级缓存（内存 → SQLite → API）获取单词的深度解析结果。
/// 使用 pending 请求 Map 实现并发去重。
class WordAiNotifier {
  final SentenceAiCacheDao _cacheDao;
  final SentenceAiApiClient _apiClient;

  /// L1 内存缓存
  final Map<String, WordAnalysis> _cache = {};

  /// 正在进行的请求（用于去重）
  final Map<String, Future<WordAnalysis>> _pending = {};

  WordAiNotifier({
    required SentenceAiCacheDao cacheDao,
    required SentenceAiApiClient apiClient,
  }) : _cacheDao = cacheDao,
       _apiClient = apiClient;

  /// 获取单词解析（三级缓存查找）
  ///
  /// L1 内存 → L2 SQLite → L3 API。
  /// 并发请求同一单词会复用同一个 Future。
  /// [sentence] 为可选上下文句子，帮助 AI 确定语境含义。
  Future<WordAnalysis> getWordAnalysis(
    String word, {
    String? sentence,
    CancelToken? cancelToken,
  }) async {
    final hash = hashText(word);

    // L1: 内存缓存
    final cached = _cache[hash];
    if (cached != null) return cached;

    // 去重：复用正在进行的请求
    if (_pending.containsKey(hash)) {
      return _pending[hash]!;
    }

    final future = _fetch(
      hash,
      word,
      sentence: sentence,
      cancelToken: cancelToken,
    );
    _pending[hash] = future;
    try {
      return await future;
    } finally {
      _pending.remove(hash);
    }
  }

  /// 同步查找 L1 缓存（仅内存）
  WordAnalysis? getCachedWordAnalysis(String word) {
    return _cache[hashText(word)];
  }

  /// 清除内存缓存
  void clearMemoryCache() {
    _cache.clear();
  }

  /// L2 + L3 查找
  Future<WordAnalysis> _fetch(
    String hash,
    String word, {
    String? sentence,
    CancelToken? cancelToken,
  }) async {
    // L2: SQLite 缓存（JSON 损坏时跳过，fallthrough 到 L3）
    final dbResult = await _cacheDao.getByHash(hash, 'word_analysis');
    if (dbResult != null) {
      try {
        final analysis = WordAnalysis.fromJson(
          jsonDecode(dbResult) as Map<String, dynamic>,
        );
        _cache[hash] = analysis;
        return analysis;
      } catch (_) {
        // L2 数据损坏，继续到 L3 API 调用
      }
    }

    // L3: API 调用
    final analysis = await _apiClient.analyzeWord(
      word,
      sentence: sentence,
      cancelToken: cancelToken,
    );
    // 写入 L1 + L2
    _cache[hash] = analysis;
    await _cacheDao.upsert(
      hash,
      'word_analysis',
      jsonEncode(analysis.toJson()),
    );
    return analysis;
  }
}

/// WordAiNotifier Provider（手动，非 code-gen）
final wordAiNotifierProvider = Provider<WordAiNotifier>((ref) {
  return WordAiNotifier(
    cacheDao: ref.watch(sentenceAiCacheDaoProvider),
    apiClient: ref.watch(sentenceAiApiClientProvider),
  );
});
