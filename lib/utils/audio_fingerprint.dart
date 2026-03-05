// 音频文件 SHA256 指纹计算工具
//
// 用于 AI 转录去重：相同内容的音频只需转录一次。
// 使用 Isolate 异步计算，避免阻塞 UI 线程。
import 'dart:isolate';
import 'package:crypto/crypto.dart';
import 'package:universal_io/io.dart';

/// 计算音频文件的 SHA256 哈希值
///
/// 在 Isolate 中执行流式计算，避免将整个文件加载到内存。
/// [absolutePath] 音频文件的绝对路径。
/// 返回十六进制小写 SHA256 字符串。
/// 文件不存在时抛出 [FileSystemException]。
Future<String> computeAudioSha256(String absolutePath) {
  return Isolate.run(() => _computeSha256(absolutePath));
}

/// Isolate 内部执行的同步 SHA256 计算
String _computeSha256(String absolutePath) {
  final file = File(absolutePath);
  if (!file.existsSync()) {
    throw FileSystemException('File not found', absolutePath);
  }
  final sink = AccumulatorSink<Digest>();
  final output = sha256.startChunkedConversion(sink);
  // 流式读取，每次 64KB
  final stream = file.openSync();
  try {
    final buffer = List<int>.filled(65536, 0);
    int bytesRead;
    while ((bytesRead = stream.readIntoSync(buffer)) > 0) {
      output.add(buffer.sublist(0, bytesRead));
    }
  } finally {
    stream.closeSync();
  }
  output.close();
  return sink.events.first.toString();
}

/// crypto 包的辅助类：收集 chunked conversion 的结果
class AccumulatorSink<T> implements Sink<T> {
  final List<T> events = [];

  @override
  void add(T event) => events.add(event);

  @override
  void close() {}
}
