import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart' hide FileType;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/provider/chat_history_provider.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:localsend_isolates/model/file_type.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

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

  bool _isImage(String name) {
    final ext = name.toLowerCase();
    return ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.png') || ext.endsWith('.gif') || ext.endsWith('.webp') || ext.endsWith('.bmp');
  }

  bool _isVideo(String name) {
    final ext = name.toLowerCase();
    return ext.endsWith('.mp4') || ext.endsWith('.mov') || ext.endsWith('.avi') || ext.endsWith('.mkv') || ext.endsWith('.webm');
  }

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();

    final bytes = Uint8List.fromList(utf8.encode(text));
    final now = DateTime.now().toIso8601String();
    final textFile = CrossFile(
      name: '${const Uuid().v4()}.txt',
      fileType: FileType.text,
      size: bytes.length,
      thumbnail: null,
      asset: null,
      path: null,
      bytes: bytes,
      lastModified: now,
      lastAccessed: now,
    );

    await context.ref.notifier(sendProvider).startSession(
      target: widget.device,
      files: [textFile],
      background: true,
    );
    _scrollToBottom();
  }

  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.pickFiles(allowMultiple: true);
    if (result == null || result.files.isEmpty) return;

    final now = DateTime.now().toIso8601String();
    final crossFiles = result.files.map((f) {
      final isImg = _isImage(f.name);
      final isVid = _isVideo(f.name);
      return CrossFile(
        name: f.name,
        fileType: isImg ? FileType.image : (isVid ? FileType.video : FileType.other),
        size: f.size,
        thumbnail: null,
        asset: null,
        path: f.path,
        bytes: f.bytes,
        lastModified: now,
        lastAccessed: now,
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

  Widget _buildBubble(ChatMessage msg) {
    if (msg.imageBytes != null || (msg.fileName != null && _isImage(msg.fileName!) && msg.filePath != null)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: msg.imageBytes != null
            ? Image.memory(msg.imageBytes!, width: 180, fit: BoxFit.cover)
            : Image.file(File(msg.filePath!), width: 180, fit: BoxFit.cover),
      );
    }

    if (msg.isVideo && msg.filePath != null) {
      return _VideoThumbBubble(filePath: msg.filePath!, fileName: msg.fileName ?? '视频');
    }

    return GestureDetector(
      onLongPress: () {
        if (msg.text != null) {
          Clipboard.setData(ClipboardData(text: msg.text!));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)));
        }
      },
      child: Container(
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: _buildBubble(msg),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
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

class _VideoThumbBubble extends StatefulWidget {
  final String filePath;
  final String fileName;

  const _VideoThumbBubble({required this.filePath, required this.fileName});

  @override
  State<_VideoThumbBubble> createState() => _VideoThumbBubbleState();
}

class _VideoThumbBubbleState extends State<_VideoThumbBubble> {
  late VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.filePath))
      ..initialize().then((_) {
        if (mounted) setState(() => _ready = true);
      }).catchError((_) {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_ready)
            SizedBox(
              width: 180,
              child: AspectRatio(aspectRatio: _controller.value.aspectRatio, child: VideoPlayer(_controller)),
            )
          else
            Container(
              width: 180,
              height: 110,
              color: Colors.black87,
              alignment: Alignment.bottomLeft,
              padding: const EdgeInsets.all(8),
              child: Text(widget.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ),
          const Icon(Icons.play_circle_fill, size: 42, color: Colors.white70),
        ],
      ),
    );
  }
}
