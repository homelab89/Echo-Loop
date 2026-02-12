/// 合集数据模型
class Collection {
  final String id;
  final String name;
  final DateTime createdDate;
  final bool isStarred;
  final int sortOrder;
  final List<String> audioItemIds; // 合集中的音频ID列表

  Collection({
    required this.id,
    required this.name,
    required this.createdDate,
    this.isStarred = false,
    this.sortOrder = 0,
    this.audioItemIds = const [],
  });

  int get audioCount => audioItemIds.length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdDate': createdDate.toIso8601String(),
        'isStarred': isStarred,
        'sortOrder': sortOrder,
        'audioItemIds': audioItemIds,
      };

  factory Collection.fromJson(Map<String, dynamic> json) => Collection(
        id: json['id'],
        name: json['name'],
        createdDate: DateTime.parse(json['createdDate']),
        isStarred: json['isStarred'] ?? false,
        sortOrder: json['sortOrder'] ?? 0,
        audioItemIds: List<String>.from(json['audioItemIds'] ?? []),
      );

  Collection copyWith({
    String? id,
    String? name,
    DateTime? createdDate,
    bool? isStarred,
    int? sortOrder,
    List<String>? audioItemIds,
  }) {
    return Collection(
      id: id ?? this.id,
      name: name ?? this.name,
      createdDate: createdDate ?? this.createdDate,
      isStarred: isStarred ?? this.isStarred,
      sortOrder: sortOrder ?? this.sortOrder,
      audioItemIds: audioItemIds ?? this.audioItemIds,
    );
  }
}
