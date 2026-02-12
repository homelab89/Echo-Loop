import 'package:flutter/foundation.dart';
import '../models/collection.dart';
import '../services/storage_service.dart';

/// 合集排序方式
enum CollectionSortType {
  nameAsc,    // 名称升序
  nameDesc,   // 名称降序
  dateAsc,    // 创建时间升序
  dateDesc,   // 创建时间降序
  custom,     // 自定义排序
}

/// 合集视图模式
enum CollectionViewMode {
  grid,   // 文件夹/网格视图
  list,   // 列表视图
}

class CollectionProvider extends ChangeNotifier {
  List<Collection> _collections = [];
  bool _isLoading = false;
  CollectionViewMode _viewMode = CollectionViewMode.list;
  CollectionSortType _sortType = CollectionSortType.dateDesc;

  List<Collection> get collections => _getSortedCollections();
  bool get isLoading => _isLoading;
  bool get isEmpty => _collections.isEmpty;
  CollectionViewMode get viewMode => _viewMode;
  CollectionSortType get sortType => _sortType;

  /// 获取排序后的合集列表
  List<Collection> _getSortedCollections() {
    final sorted = List<Collection>.from(_collections);
    _sortList(sorted);
    return sorted;
  }

  void _sortList(List<Collection> list) {
    switch (_sortType) {
      case CollectionSortType.nameAsc:
        list.sort((a, b) => a.name.compareTo(b.name));
      case CollectionSortType.nameDesc:
        list.sort((a, b) => b.name.compareTo(a.name));
      case CollectionSortType.dateAsc:
        list.sort((a, b) => a.createdDate.compareTo(b.createdDate));
      case CollectionSortType.dateDesc:
        list.sort((a, b) => b.createdDate.compareTo(a.createdDate));
      case CollectionSortType.custom:
        list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
  }

  /// 加载合集列表
  Future<void> loadCollections() async {
    _isLoading = true;
    notifyListeners();

    _collections = await StorageService.loadCollections();

    _isLoading = false;
    notifyListeners();
  }

  /// 创建合集
  Future<void> createCollection(String name) async {
    final collection = Collection(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      createdDate: DateTime.now(),
      sortOrder: _collections.length,
    );
    _collections.add(collection);
    await _save();
    notifyListeners();
  }

  /// 删除合集
  Future<void> deleteCollection(String id) async {
    _collections.removeWhere((c) => c.id == id);
    await _save();
    notifyListeners();
  }

  /// 编辑合集名称
  Future<void> renameCollection(String id, String newName) async {
    final index = _collections.indexWhere((c) => c.id == id);
    if (index != -1) {
      _collections[index] = _collections[index].copyWith(name: newName);
      await _save();
      notifyListeners();
    }
  }

  /// 切换星标状态
  Future<void> toggleStar(String id) async {
    final index = _collections.indexWhere((c) => c.id == id);
    if (index != -1) {
      _collections[index] = _collections[index].copyWith(
        isStarred: !_collections[index].isStarred,
      );
      await _save();
      notifyListeners();
    }
  }

  /// 添加音频到合集
  Future<void> addAudioToCollection(String collectionId, String audioId) async {
    final index = _collections.indexWhere((c) => c.id == collectionId);
    if (index != -1) {
      final ids = List<String>.from(_collections[index].audioItemIds);
      if (!ids.contains(audioId)) {
        ids.add(audioId);
        _collections[index] = _collections[index].copyWith(audioItemIds: ids);
        await _save();
        notifyListeners();
      }
    }
  }

  /// 从合集中移除音频
  Future<void> removeAudioFromCollection(
      String collectionId, String audioId) async {
    final index = _collections.indexWhere((c) => c.id == collectionId);
    if (index != -1) {
      final ids = List<String>.from(_collections[index].audioItemIds);
      ids.remove(audioId);
      _collections[index] = _collections[index].copyWith(audioItemIds: ids);
      await _save();
      notifyListeners();
    }
  }

  /// 获取指定合集
  Collection? getCollectionById(String id) {
    try {
      return _collections.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 切换视图模式
  void toggleViewMode() {
    _viewMode = _viewMode == CollectionViewMode.grid
        ? CollectionViewMode.list
        : CollectionViewMode.grid;
    notifyListeners();
  }

  /// 设置排序方式
  void setSortType(CollectionSortType type) {
    _sortType = type;
    notifyListeners();
  }

  /// 重新排序合集（拖拽排序用）
  Future<void> reorderCollections(int oldIndex, int newIndex) async {
    // 使用当前排序后的列表做重排
    final sorted = _getSortedCollections();
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = sorted.removeAt(oldIndex);
    sorted.insert(newIndex, item);

    // 更新 sortOrder 并同步回 _collections
    for (int i = 0; i < sorted.length; i++) {
      final idx = _collections.indexWhere((c) => c.id == sorted[i].id);
      if (idx != -1) {
        _collections[idx] = _collections[idx].copyWith(sortOrder: i);
      }
    }

    await _save();
    notifyListeners();
  }

  /// 直接应用自定义排序（接受有序的 ID 列表）
  Future<void> applyCustomOrder(List<String> orderedIds) async {
    for (int i = 0; i < orderedIds.length; i++) {
      final idx = _collections.indexWhere((c) => c.id == orderedIds[i]);
      if (idx != -1) {
        _collections[idx] = _collections[idx].copyWith(sortOrder: i);
      }
    }
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    await StorageService.saveCollections(_collections);
  }
}
