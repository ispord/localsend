import 'package:flutter/foundation.dart';
import 'package:refena_flutter/refena_flutter.dart';

class ChatMessage {
  final String id;
  final bool isMe;
  final String? text;
  final String? fileName;
  final String? filePath;
  final Uint8List? imageBytes;
  final bool isVideo;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.isMe,
    this.text,
    this.fileName,
    this.filePath,
    this.imageBytes,
    this.isVideo = false,
    required this.timestamp,
  });
}

class ChatHistoryNotifier extends Notifier<Map<String, List<ChatMessage>>> {
  @override
  Map<String, List<ChatMessage>> init() => {};

  void addMessage(String deviceKey, ChatMessage message) {
    final currentList = state[deviceKey] ?? [];
    if (currentList.isNotEmpty) {
      final last = currentList.last;
      final isSameSide = last.isMe == message.isMe;
      final isSameFile = message.fileName != null && last.fileName == message.fileName;
      final isSameText = message.text != null && last.text == message.text;
      final isWithin3Seconds = message.timestamp.difference(last.timestamp).inSeconds.abs() <= 3;

      if (isSameSide && isWithin3Seconds && (isSameFile || isSameText)) {
        return; // 拦截重复写入，确保只显示 1 张缩略图 / 1 条气泡
      }
    }

    state = {
      ...state,
      deviceKey: [...currentList, message],
    };
  }
