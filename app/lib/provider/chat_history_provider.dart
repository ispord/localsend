import 'package:refena_flutter/refena_flutter.dart';

class ChatMessage {
  final String id;
  final bool isMe; // true: 我發送的(綠色), false: 對方發送的(白色)
  final String? text;
  final String? fileName;
  final String? filePath;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.isMe,
    this.text,
    this.fileName,
    this.filePath,
    required this.timestamp,
  });
}

final chatHistoryProvider = NotifierProvider<ChatHistoryNotifier, Map<String, List<ChatMessage>>>((ref) {
  return ChatHistoryNotifier();
});

class ChatHistoryNotifier extends Notifier<Map<String, List<ChatMessage>>> {
  @override
  Map<String, List<ChatMessage>> init() => {};

  void addMessage(String deviceKey, ChatMessage message) {
    if (deviceKey.isEmpty) return;
    final currentList = state[deviceKey] ?? [];
    state = {
      ...state,
      deviceKey: [...currentList, message],
    };
  }
}
