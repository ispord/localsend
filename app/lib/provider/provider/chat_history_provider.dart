import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:localsend_app/model/device.dart';

class ChatMessage {
  final String id;
  final bool isMe; // true = 右側綠色氣泡, false = 左側白色氣泡
  final String? text;
  final String? fileName;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.isMe,
    this.text,
    this.fileName,
    required this.timestamp,
  });
}

// 以設備 fingerprint 為鍵，儲存對應的聊天列表
final chatHistoryProvider = StateProvider<Map<String, List<ChatMessage>>>((ref) => {});
