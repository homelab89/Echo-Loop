import 'package:drift/drift.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../database/app_database.dart' as db;
import '../../../database/providers.dart';
import '../../../services/app_logger.dart';
import '../models/catalog.dart';
import 'official_catalog_service.dart';

part 'official_sync_service.g.dart';

/// 同步结果，供日志/测试断言用。
class OfficialSyncStats {
  final CatalogRefreshOutcome outcome;
  final int collectionsScanned;
  final int collectionsDeprecated; // 本次新增标记为下架
  final int collectionsUndeprecated; // 本次从下架恢复（catalog 重新出现）
  final int audiosAdded; // 新增音频元信息占位行
  final int audiosRemoved; // 远端移除且本地未下载的已删
  final int audiosKeptAsOrphan; // 远端移除但本地已下载，按不变性保留

  const OfficialSyncStats({
    required this.outcome,
    this.collectionsScanned = 0,
    this.collectionsDeprecated = 0,
    this.collectionsUndeprecated = 0,
    this.audiosAdded = 0,
    this.audiosRemoved = 0,
    this.audiosKeptAsOrphan = 0,
  });

  /// catalog 无变化 / 节流 / 失败时返回的"零操作"统计。
  factory OfficialSyncStats.noop(CatalogRefreshOutcome outcome) =>
      OfficialSyncStats(outcome: outcome);

  @override
  String toString() =>
      'OfficialSync(${outcome.runtimeType}, scanned=$collectionsScanned, '
      'deprecated=$collectionsDeprecated, undeprecated=$collectionsUndeprecated, '
      'added=$audiosAdded, removed=$audiosRemoved, orphanKept=$audiosKeptAsOrphan)';
}

/// 全局唯一同步入口。
///
/// 策略（见 plan §Stage 6.1 + v2.1）：
/// 1. 调 `OfficialCatalogService.refresh(force)` —— 内部 inflight + 10min 节流 + sha256 比对
/// 2. 仅 [CatalogUpdated] 才走后续 diff（unchanged / throttled / failed 全部跳过）
/// 3. 对所有"已加入且未软删"的官方合集做 diff（含 deprecated 的，可能要 undeprecate）
/// 4. catalog 含某 collection → 比对 detail 应用差异；catalog 不含 → markDeprecated
/// 5. 已 deprecated 的本地合集若 catalog 中重新出现 → undeprecate（可逆）
///
/// 本服务仅修改本地 DB；不通知 UI provider，调用方自己决定怎么 invalidate。
class OfficialSyncService {
  final db.AppDatabase _db;
  final OfficialCatalogService _catalog;

  /// 防重入：并发 syncAll 复用同一个 future。
  ///
  /// 底层 `OfficialCatalogService.refresh` 已有自己的 inflight，但若两个
  /// `syncAll` 并发 `await refresh` 拿到同一个 `CatalogUpdated`，两人会各自
  /// 进入 `_applyCatalog` 并发执行 diff。`_applyDetail` 的本地快照在事务外
  /// 构建，两条 Future 的 `localByRemoteId` 都是旧快照，就会把"新发布的
  /// 音频"各 insert 一次，产生重复。这里在 syncAll 层再加一层 inflight
  /// 去重，保证 `_applyCatalog` 同一时间只会有一份实际在跑。
  Future<OfficialSyncStats>? _inflight;

  OfficialSyncService({
    required db.AppDatabase database,
    required OfficialCatalogService catalog,
  }) : _db = database,
       _catalog = catalog;

  /// 全局唯一同步入口。详情见 class doc。
  Future<OfficialSyncStats> syncAll({bool force = false}) {
    final existing = _inflight;
    if (existing != null) {
      AppLogger.log(
        'OfficialSync',
        'syncAll reusing inflight (force=$force)',
      );
      return existing;
    }
    final future = _runSyncAll(force: force);
    _inflight = future;
    return future.whenComplete(() => _inflight = null);
  }

  Future<OfficialSyncStats> _runSyncAll({required bool force}) async {
    final outcome = await _catalog.refresh(force: force);
    if (outcome is! CatalogUpdated) {
      // 关键：catalog 无变化 / 节流 / 失败 → 整链路全跳过
      AppLogger.log(
        'OfficialSync',
        'syncAll skipped: outcome=${outcome.runtimeType}',
      );
      return OfficialSyncStats.noop(outcome);
    }

    // catalog 内容更新了，对所有已加入合集做 diff
    return _applyCatalog(outcome.snapshot);
  }

  Future<OfficialSyncStats> _applyCatalog(CatalogSnapshot snapshot) async {
    // 拿出所有已加入的官方合集（含 deprecated 的，因为可能需要 undeprecate）
    final locals = await (_db.select(_db.collections)
          ..where(
            (t) => t.source.equals('official') & t.deletedAt.isNull(),
          ))
        .get();

    final catalogById = {for (final c in snapshot.collections) c.id: c};

    var deprecated = 0;
    var undeprecated = 0;
    var added = 0;
    var removed = 0;
    var orphan = 0;

    for (final local in locals) {
      final remoteId = local.remoteId;
      if (remoteId == null) {
        // 数据异常防御：source='official' 却无 remoteId
        if (local.deprecatedAt == null) {
          await _markDeprecated(local.id);
          deprecated++;
        }
        continue;
      }

      final fromCatalog = catalogById[remoteId];

      if (fromCatalog == null) {
        // catalog 不含 → 标记下架（幂等：已经 deprecated 不重复标）
        if (local.deprecatedAt == null) {
          await _markDeprecated(local.id);
          deprecated++;
        }
        continue;
      }

      // catalog 中存在 → 若本地是 deprecated 则恢复（可逆）
      if (local.deprecatedAt != null) {
        await _undeprecate(local.id);
        undeprecated++;
      }

      // diff 该合集的 audios + 元信息
      try {
        final result = await _applyCatalogCollection(local, fromCatalog);
        added += result.added;
        removed += result.removed;
        orphan += result.orphan;
      } catch (e, st) {
        AppLogger.log(
          'OfficialSync',
          'apply catalog collection failed localId=${local.id}: $e',
        );
        AppLogger.log('OfficialSync', st.toString());
      }
    }

    return OfficialSyncStats(
      outcome: CatalogUpdated(snapshot),
      collectionsScanned: locals.length,
      collectionsDeprecated: deprecated,
      collectionsUndeprecated: undeprecated,
      audiosAdded: added,
      audiosRemoved: removed,
      audiosKeptAsOrphan: orphan,
    );
  }

  Future<void> _markDeprecated(String localCollectionId) async {
    final now = DateTime.now();
    await (_db.update(_db.collections)
          ..where((t) => t.id.equals(localCollectionId)))
        .write(
          db.CollectionsCompanion(
            deprecatedAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  /// 把已 deprecated 的合集恢复（catalog 中重新出现时调用）。
  Future<void> _undeprecate(String localCollectionId) async {
    final now = DateTime.now();
    await (_db.update(_db.collections)
          ..where((t) => t.id.equals(localCollectionId)))
        .write(
          db.CollectionsCompanion(
            deprecatedAt: const Value(null),
            updatedAt: Value(now),
          ),
        );
  }

  /// 用一份 [CatalogCollection] 给一个本地合集做 diff（音频增删 + 元信息）。
  Future<_SingleSyncResult> _applyCatalogCollection(
    db.Collection local,
    CatalogCollection catalogColl,
  ) async {
    return _applyDetail(local, catalogColl);
  }

  /// 给一个本地合集做 diff（音频增删 + 元信息更新）；不动已下载内容。
  ///
  /// 输入是 [CatalogCollection]（catalog 子结构），不再依赖老的
  /// `OfficialCollectionDetail` API DTO —— catalog 已是唯一信息来源。
  Future<_SingleSyncResult> _applyDetail(
    db.Collection local,
    CatalogCollection detail,
  ) async {
    // 本地 junction 行
    final localJunctions =
        await (_db.select(_db.collectionAudioItems)
              ..where((t) => t.collectionId.equals(local.id))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();
    final localAudioIdsInJunction =
        localJunctions.map((j) => j.audioItemId).toList();

    // 取每条本地 audio_items（用于 remoteAudioId 反查）
    final localAudios = <String, db.AudioItem>{};
    for (final id in localAudioIdsInJunction) {
      final row = await _db.audioItemDao.getById(id);
      if (row != null) localAudios[id] = row;
    }
    final localByRemoteId = <String, db.AudioItem>{};
    for (final row in localAudios.values) {
      final rid = row.remoteAudioId;
      if (rid != null) localByRemoteId[rid] = row;
    }

    final remoteRemoteIds = detail.audios.map((a) => a.id).toSet();

    var added = 0;
    var removed = 0;
    var orphan = 0;

    await _db.transaction(() async {
      // 1) 远端新增音频：本地没有对应 remoteAudioId → 插 audio_items + junction
      for (final a in detail.audios) {
        if (localByRemoteId.containsKey(a.id)) {
          // 已存在 → 检查 sortOrder 和 originalDate 是否要更新（不动 path 等已下载字段）
          final existing = localByRemoteId[a.id]!;
          final junction = localJunctions
              .firstWhere((j) => j.audioItemId == existing.id);
          if (junction.sortOrder != a.sortOrder) {
            await (_db.update(_db.collectionAudioItems)
                  ..where(
                    (t) =>
                        t.collectionId.equals(local.id) &
                        t.audioItemId.equals(existing.id),
                  ))
                .write(
                  db.CollectionAudioItemsCompanion(
                    sortOrder: Value(a.sortOrder),
                  ),
                );
          }
          final changedName = existing.name != a.title;
          final changedOriginalDate = existing.originalDate != a.originalDate;
          if (changedName || changedOriginalDate) {
            await (_db.update(_db.audioItems)
                  ..where((t) => t.id.equals(existing.id)))
                .write(
                  db.AudioItemsCompanion(
                    name: changedName ? Value(a.title) : const Value.absent(),
                    originalDate: changedOriginalDate
                        ? Value(a.originalDate)
                        : const Value.absent(),
                    updatedAt: Value(DateTime.now()),
                  ),
                );
          }
          continue;
        }
        final newAudioId = const Uuid().v4();
        final now = DateTime.now();
        await _db.audioItemDao.upsert(
          db.AudioItemsCompanion(
            id: Value(newAudioId),
            name: Value(a.title),
            // audioPath / transcriptPath 保持 NULL，下载成功时再写入
            addedDate: Value(now),
            totalDuration: Value(a.durationSec),
            sentenceCount: const Value(0),
            wordCount: const Value(0),
            isPinned: const Value(false),
            remoteAudioId: Value(a.id),
            audioSha256: Value(a.sha256),
            originalDate: Value(a.originalDate),
            updatedAt: Value(now),
          ),
        );
        await _db.into(_db.collectionAudioItems).insertOnConflictUpdate(
          db.CollectionAudioItemsCompanion(
            collectionId: Value(local.id),
            audioItemId: Value(newAudioId),
            sortOrder: Value(a.sortOrder),
            addedAt: Value(now),
          ),
        );
        added++;
      }

      // 2) 远端已移除：本地未下载 → 删 audio_items + junction；本地已下载 → 保留
      for (final row in localByRemoteId.values) {
        if (remoteRemoteIds.contains(row.remoteAudioId)) continue;

        if (row.audioPath == null) {
          await (_db.delete(_db.collectionAudioItems)
                ..where(
                  (t) =>
                      t.collectionId.equals(local.id) &
                      t.audioItemId.equals(row.id),
                ))
              .go();
          await _db.audioItemDao.hardDelete(row.id);
          removed++;
        } else {
          orphan++;
        }
      }

      // 3) 合集元信息变化（catalog 子结构直接是顶级字段）
      final changedName = local.name != detail.name;
      final changedDesc = local.description != detail.description;
      final changedCover = local.coverUrl != detail.coverUrl;
      if (changedName || changedDesc || changedCover) {
        await (_db.update(_db.collections)
              ..where((t) => t.id.equals(local.id)))
            .write(
              db.CollectionsCompanion(
                name: Value(detail.name),
                description: Value(detail.description),
                coverUrl: Value(detail.coverUrl),
                updatedAt: Value(DateTime.now()),
              ),
            );
      }
    });

    return _SingleSyncResult(
      added: added,
      removed: removed,
      orphan: orphan,
    );
  }

}

class _SingleSyncResult {
  final int added;
  final int removed;
  final int orphan;

  _SingleSyncResult({
    this.added = 0,
    this.removed = 0,
    this.orphan = 0,
  });
}

@Riverpod(keepAlive: true)
OfficialSyncService officialSyncService(Ref ref) {
  return OfficialSyncService(
    database: ref.watch(appDatabaseProvider),
    catalog: ref.watch(officialCatalogServiceProvider),
  );
}
