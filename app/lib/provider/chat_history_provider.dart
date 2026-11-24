import 'package:flutter/foundation.dart';
import 'package:refena_flutter/refena_flutter.dart';

enum MsgSendStatus { sending, success, failed }

class ChatMessage {
  final String id;
  final String? sessionId;
  final bool isMe;
  final String? text;
  final String? fileName;
  final String? filePath;
  final Uint8List? imageBytes;
  final bool isVideo;
  final MsgSendStatus status;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    this.sessionId,
    required this.isMe,
    this.text,
    this.fileName,
    this.filePath,
    this.imageBytes,
    this.isVideo = false,
    this.status = MsgSendStatus.success,
    required this.timestamp,
  });

  ChatMessage copyWith({MsgSendStatus? status}) {
    return ChatMessage(
      id: id,
      sessionId: sessionId,
      isMe: isMe,
      text: text,
      fileName: fileName,
      filePath: filePath,
      imageBytes: imageBytes,
      isVideo: isVideo,
      status: status ?? this.status,
      timestamp: timestamp,
    );
  }
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
        return;
      }
    }

    state = {
      ...state,
      deviceKey: [...currentList, message],
    };
  }

  void updateSessionStatus(String sessionId, MsgSendStatus newStatus) {
    final newState = <String, List<ChatMessage>>{};
    bool changed = false;

    state.forEach((key, list) {
      final updatedList = list.map((msg) {
        if (msg.sessionId == sessionId && msg.status != newStatus) {
          changed = true;
          return msg.copyWith(status: newStatus);
        }
        return msg;
      }).toList();
      newState[key] = updatedList;
    });

    if (changed) {
      state = newState;
    }
  }
}

final chatHistoryProvider = NotifierProvider<ChatHistoryNotifier, Map<String, List<ChatMessage>>>((ref) {
  return ChatHistoryNotifier();
});
