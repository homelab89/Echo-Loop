class Sentence {
  final int index;
  final String text;
  final Duration startTime;
  final Duration endTime;
  bool isBookmarked;

  Sentence({
    required this.index,
    required this.text,
    required this.startTime,
    required this.endTime,
    this.isBookmarked = false,
  });

  Duration get duration => endTime - startTime;

  Map<String, dynamic> toJson() => {
    'index': index,
    'text': text,
    'startTime': startTime.inMilliseconds,
    'endTime': endTime.inMilliseconds,
    'isBookmarked': isBookmarked,
  };

  factory Sentence.fromJson(Map<String, dynamic> json) => Sentence(
    index: json['index'],
    text: json['text'],
    startTime: Duration(milliseconds: json['startTime']),
    endTime: Duration(milliseconds: json['endTime']),
    isBookmarked: json['isBookmarked'] ?? false,
  );

  Sentence copyWith({
    int? index,
    String? text,
    Duration? startTime,
    Duration? endTime,
    bool? isBookmarked,
  }) {
    return Sentence(
      index: index ?? this.index,
      text: text ?? this.text,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isBookmarked: isBookmarked ?? this.isBookmarked,
    );
  }
}
