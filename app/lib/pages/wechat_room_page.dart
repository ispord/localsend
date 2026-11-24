import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/provider/chat_history_provider.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:localsend_isolates/model/file_type.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:uuid/uuid.dart';

class WeChatRoomPage extends StatefulWidget {
  final Device device;

  const WeChatRoomPage({super.key, required this.device});

  @override
  State<WeChatRoomPage> createState() => _WeChatRoomPageState();
}

class _WeChatRoomPageState extends State<WeChatRoomPage> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  String get _deviceKey => widget.device.fingerprint.isNotEmpty ? widget.device.fingerprint : (widget.device.ip ?? '');

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();

    final bytes = Uint8List.fromList(utf8.encode(text));
    final textFile = CrossFile(
      name: '${const Uuid().v4()}.txt',
      fileType: FileType.text,
      size: bytes.length,
      thumbnail: null,
      asset: null,
      path: null,
      bytes: bytes,
      lastModified: DateTime.now(),
      lastAccessed: DateTime.now(),
    );

    await context.ref.notifier(sendProvider).startSession(
      target: widget.device,
      files: [textFile],
      background: true, // 背景發送，停留在聊天室
    );
    _scrollToBottom();
  }

  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || result.files.isEmpty) return;

    final crossFiles = result.files.map((f) {
      return CrossFile(
        name: f.name,
        fileType: FileType.other,
        size: f.size,
        thumbnail: null,
        asset: null,
        path: f.path,
        bytes: f.bytes,
        lastModified: DateTime.now(),
        lastAccessed: DateTime.now(),
      );
    }).toList();

    if (!mounted) return;
    await context.ref.notifier(sendProvider).startSession(
      target: widget.device,
      files: crossFiles,
      background: true,
    );
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.ref.watch(chatHistoryProvider)[_deviceKey] ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEDEDED),
        foregroundColor: Colors.black,
        elevation: 0.5,
        title: Text(widget.device.alias, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                return Align(
                  alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: const BoxConstraints(maxWidth: 260),
                    decoration: BoxDecoration(
                      color: msg.isMe ? const Color(0xFF95EC69) : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      msg.fileName != null ? '📄 [檔案] ${msg.fileName}' : (msg.text ?? ''),
                      style: const TextStyle(fontSize: 15, color: Colors.black87),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            color: const Color(0xFFF7F7F7),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      onSubmitted: (_) => _sendText(),
                      decoration: InputDecoration(
                        fillColor: Colors.white,
                        filled: true,
                        hintText: '輸入訊息...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 28, color: Colors.black87),
                    onPressed: _pickAndSendFile,
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF07C160),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onPressed: _sendText,
                    child: const Text('發送'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
