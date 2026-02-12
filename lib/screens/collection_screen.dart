import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/collection.dart';
import '../providers/collection_provider.dart';
import '../l10n/app_localizations.dart';
import 'collection_detail_screen.dart';

/// 合集列表页面
class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.collections),
        actions: [
          // 排序按钮
          _SortButton(),
          // 视图切换按钮
          Consumer<CollectionProvider>(
            builder: (context, provider, _) {
              final isGrid = provider.viewMode == CollectionViewMode.grid;
              return IconButton(
                icon: Icon(isGrid ? Icons.view_list : Icons.grid_view),
                tooltip: isGrid ? l10n.listView : l10n.gridView,
                onPressed: () => provider.toggleViewMode(),
              );
            },
          ),
          // 创建合集按钮
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.createCollection,
            onPressed: () => _showCreateDialog(context),
          ),
        ],
      ),
      body: Consumer<CollectionProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.collections_bookmark_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noCollectionsYet,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.tapToCreateCollection,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }

          final collections = provider.collections;
          final isCustomSort = provider.sortType == CollectionSortType.custom;

          if (provider.viewMode == CollectionViewMode.grid) {
            if (isCustomSort) {
              return _buildReorderableGridView(context, collections);
            }
            return _buildGridView(context, collections);
          } else if (isCustomSort) {
            return _buildReorderableListView(context, collections);
          } else {
            return _buildListView(context, collections);
          }
        },
      ),
    );
  }

  /// 网格/文件夹视图
  Widget _buildGridView(BuildContext context, List<Collection> collections) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: collections.length,
      itemBuilder: (context, index) {
        return _CollectionGridTile(collection: collections[index]);
      },
    );
  }

  /// 列表视图
  Widget _buildListView(BuildContext context, List<Collection> collections) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: collections.length,
      itemBuilder: (context, index) {
        return _CollectionListTile(collection: collections[index]);
      },
    );
  }

  /// 可拖拽排序列表视图（Custom Order 模式）
  Widget _buildReorderableListView(
      BuildContext context, List<Collection> collections) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(8),
      buildDefaultDragHandles: false,
      itemCount: collections.length,
      onReorder: (oldIndex, newIndex) {
        context.read<CollectionProvider>().reorderCollections(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        return _CollectionListTile(
          key: ValueKey(collections[index].id),
          collection: collections[index],
          showDragHandle: true,
          reorderIndex: index,
        );
      },
    );
  }

  /// 可拖拽排序网格视图（Custom Order + Grid 模式）
  Widget _buildReorderableGridView(
      BuildContext context, List<Collection> collections) {
    return _ReorderableCollectionGrid(collections: collections);
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _CreateCollectionDialog(),
    );
  }
}

/// 排序按钮
class _SortButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<CollectionSortType>(
      icon: const Icon(Icons.sort),
      tooltip: l10n.sortCollections,
      onSelected: (type) {
        context.read<CollectionProvider>().setSortType(type);
      },
      itemBuilder: (context) {
        final current = context.read<CollectionProvider>().sortType;
        return [
          _sortMenuItem(l10n.sortByNameAsc, CollectionSortType.nameAsc, current),
          _sortMenuItem(l10n.sortByNameDesc, CollectionSortType.nameDesc, current),
          _sortMenuItem(l10n.sortByDateAsc, CollectionSortType.dateAsc, current),
          _sortMenuItem(l10n.sortByDateDesc, CollectionSortType.dateDesc, current),
          _sortMenuItem(l10n.sortByCustom, CollectionSortType.custom, current),
        ];
      },
    );
  }

  PopupMenuItem<CollectionSortType> _sortMenuItem(
    String label,
    CollectionSortType type,
    CollectionSortType current,
  ) {
    return PopupMenuItem(
      value: type,
      child: Row(
        children: [
          if (type == current)
            const Icon(Icons.check, size: 18)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

/// 文件夹网格卡片
class _CollectionGridTile extends StatelessWidget {
  final Collection collection;

  const _CollectionGridTile({required this.collection});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openCollection(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            children: [
              // 顶部操作栏：星标 + 更多
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      icon: Icon(
                        collection.isStarred ? Icons.star : Icons.star_border,
                        color: collection.isStarred ? Colors.amber : null,
                      ),
                      tooltip: collection.isStarred
                          ? l10n.unstarCollection
                          : l10n.starCollection,
                      onPressed: () {
                        context
                            .read<CollectionProvider>()
                            .toggleStar(collection.id);
                      },
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: PopupMenuButton(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              const Icon(Icons.edit, size: 18),
                              const SizedBox(width: 8),
                              Text(l10n.renameCollection),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete,
                                  size: 18, color: Colors.red),
                              const SizedBox(width: 8),
                              Text(l10n.delete),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'rename') {
                          _showRenameCollectionDialog(context, collection);
                        } else if (value == 'delete') {
                          _showDeleteConfirmDialog(context, collection);
                        }
                      },
                    ),
                  ),
                ],
              ),
              // 文件夹图标
              Icon(
                Icons.folder,
                size: 48,
                color: collection.isStarred
                    ? Colors.amber
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 4),
              // 合集名称
              Text(
                collection.name,
                style: Theme.of(context).textTheme.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              // 音频数量
              Text(
                l10n.audioCount(collection.audioCount),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCollection(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CollectionDetailScreen(collectionId: collection.id),
      ),
    );
  }
}

/// 列表项
class _CollectionListTile extends StatelessWidget {
  final Collection collection;
  final bool showDragHandle;
  final int reorderIndex;

  const _CollectionListTile({
    super.key,
    required this.collection,
    this.showDragHandle = false,
    this.reorderIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            collection.isStarred ? Icons.folder_special : Icons.folder,
            color: collection.isStarred
                ? Colors.amber
                : Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          collection.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Row(
          children: [
            Text(
              l10n.audioCount(collection.audioCount),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(width: 12),
            Text(
              l10n.addedOn(_formatDate(collection.createdDate)),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 星标按钮
            SizedBox(
              width: 36,
              child: IconButton(
                icon: Icon(
                  collection.isStarred ? Icons.star : Icons.star_border,
                  color: collection.isStarred ? Colors.amber : null,
                  size: 22,
                ),
                tooltip: collection.isStarred
                    ? l10n.unstarCollection
                    : l10n.starCollection,
                padding: EdgeInsets.zero,
                onPressed: () {
                  context.read<CollectionProvider>().toggleStar(collection.id);
                },
              ),
            ),
            // 更多操作菜单
            SizedBox(
              width: 36,
              child: PopupMenuButton(
                padding: EdgeInsets.zero,
                iconSize: 22,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        const Icon(Icons.edit),
                        const SizedBox(width: 8),
                        Text(l10n.renameCollection),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(l10n.delete),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'rename') {
                    _showRenameDialog(context);
                  } else if (value == 'delete') {
                    _confirmDelete(context);
                  }
                },
              ),
            ),
            // 拖拽排序手柄
            if (showDragHandle)
              ReorderableDragStartListener(
                index: reorderIndex,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.drag_handle,
                    color: Theme.of(context).colorScheme.outline,
                    size: 22,
                  ),
                ),
              ),
          ],
        ),
        onTap: () => _openCollection(context),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  void _openCollection(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CollectionDetailScreen(collectionId: collection.id),
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    _showRenameCollectionDialog(context, collection);
  }

  void _confirmDelete(BuildContext context) {
    _showDeleteConfirmDialog(context, collection);
  }
}

/// 可拖拽排序的网格视图（Custom Order + Grid 模式）
class _ReorderableCollectionGrid extends StatefulWidget {
  final List<Collection> collections;

  const _ReorderableCollectionGrid({required this.collections});

  @override
  State<_ReorderableCollectionGrid> createState() =>
      _ReorderableCollectionGridState();
}

class _ReorderableCollectionGridState
    extends State<_ReorderableCollectionGrid> {
  late List<Collection> _items;
  int? _dragIndex;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.collections);
  }

  @override
  void didUpdateWidget(covariant _ReorderableCollectionGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 仅在非拖拽状态下同步 provider 数据
    if (_dragIndex == null) {
      _items = List.from(widget.collections);
    }
  }

  /// 拖拽进入目标位置时，移动元素让出空间
  void _onHover(String draggedId, int targetIndex) {
    final fromIndex = _items.indexWhere((c) => c.id == draggedId);
    if (fromIndex == -1 || fromIndex == targetIndex) return;
    setState(() {
      final item = _items.removeAt(fromIndex);
      _items.insert(targetIndex, item);
      _dragIndex = targetIndex;
    });
  }

  /// 提交最终排序
  void _commitOrder() {
    final orderedIds = _items.map((c) => c.id).toList();
    context.read<CollectionProvider>().applyCustomOrder(orderedIds);
    setState(() => _dragIndex = null);
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final collection = _items[index];

        return DragTarget<String>(
          onWillAcceptWithDetails: (details) {
            _onHover(details.data, index);
            // 返回 false，不触发 onAccept；排序在拖拽结束时统一提交
            return false;
          },
          builder: (context, candidateData, rejectedData) {
            return LongPressDraggable<String>(
              data: collection.id,
              onDragStarted: () {
                setState(() => _dragIndex = index);
              },
              onDragEnd: (_) => _commitOrder(),
              feedback: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 160,
                  height: 160 / 0.85,
                  child: Opacity(
                    opacity: 0.9,
                    child: _CollectionGridTile(collection: collection),
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: _CollectionGridTile(collection: collection),
              ),
              child: _CollectionGridTile(collection: collection),
            );
          },
        );
      },
    );
  }
}

/// 创建合集对话框
class _CreateCollectionDialog extends StatefulWidget {
  const _CreateCollectionDialog();

  @override
  State<_CreateCollectionDialog> createState() =>
      _CreateCollectionDialogState();
}

class _CreateCollectionDialogState extends State<_CreateCollectionDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.createCollection),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: l10n.collectionName,
          hintText: l10n.enterCollectionName,
          errorText: _error,
        ),
        onSubmitted: (_) => _create(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _create,
          child: Text(l10n.add),
        ),
      ],
    );
  }

  void _create() {
    final l10n = AppLocalizations.of(context)!;
    final name = _controller.text.trim();

    if (name.isEmpty) {
      setState(() => _error = l10n.collectionNameEmpty);
      return;
    }

    // 检查是否同名
    final provider = context.read<CollectionProvider>();
    final exists = provider.collections.any(
      (c) => c.name.toLowerCase() == name.toLowerCase(),
    );
    if (exists) {
      setState(() => _error = l10n.collectionNameExists);
      return;
    }

    provider.createCollection(name);
    Navigator.pop(context);
  }
}

// ===== 公共辅助方法 =====

/// 重命名合集对话框
void _showRenameCollectionDialog(BuildContext context, Collection collection) {
  final l10n = AppLocalizations.of(context)!;
  final controller = TextEditingController(text: collection.name);

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.renameCollection),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: l10n.collectionName,
        ),
        onSubmitted: (_) {
          final name = controller.text.trim();
          if (name.isNotEmpty) {
            context.read<CollectionProvider>().renameCollection(
                  collection.id,
                  name,
                );
            Navigator.pop(ctx);
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: () {
            final name = controller.text.trim();
            if (name.isNotEmpty) {
              context.read<CollectionProvider>().renameCollection(
                    collection.id,
                    name,
                  );
              Navigator.pop(ctx);
            }
          },
          child: Text(l10n.ok),
        ),
      ],
    ),
  );
}

/// 删除确认对话框
void _showDeleteConfirmDialog(BuildContext context, Collection collection) {
  final l10n = AppLocalizations.of(context)!;
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.deleteCollection),
      content: Text(l10n.deleteCollectionConfirm(collection.name)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () {
            context.read<CollectionProvider>().deleteCollection(collection.id);
            Navigator.pop(ctx);
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
}
