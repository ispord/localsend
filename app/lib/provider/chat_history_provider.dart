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
    state = {
      ...state,
      deviceKey: [...currentList, message],
    };
  }
}

final chatHistoryProvider = NotifierProvider<ChatHistoryNotifier, Map<String, List<ChatMessage>>>((ref) {
  return ChatHistoryNotifier();
});
