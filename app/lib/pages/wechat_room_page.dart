import 'package:desktop_drop/desktop_drop.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:pasteboard/pasteboard.dart';
import 'package:localsend_isolates/model/session_status.dart';
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

class WeChatRoomPage extends StatefulWidget {
  final Device device;

  const WeChatRoomPage({super.key, required this.device});

  @override
  State<WeChatRoomPage> createState() => _WeChatRoomPageState();
}
Widget _buildStatusIcon(ChatMessage msg) {
  if (!msg.isMe) return const SizedBox.shrink();
  switch (msg.status) {
    case MsgSendStatus.sending:
      return const Padding(
        padding: EdgeInsets.only(right: 6),
        child: SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 1.8, color: Colors.grey),
        ),
      );
    case MsgSendStatus.success:
      return const Padding(
        padding: EdgeInsets.only(right: 6),
        child: Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF07C160)),
      );
    case MsgSendStatus.failed:
      return GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('发送失败，请检查对方设备是否在线'), duration: Duration(seconds: 2)),
          );
        },
        child: const Padding(
          padding: EdgeInsets.only(right: 6),
          child: Icon(Icons.error, size: 18, color: Colors.redAccent),
        ),
      );
  }
}

class _WeChatRoomPageState extends State<WeChatRoomPage> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

    bool _isDragging = false;

  Future<void> _handleDroppedFiles(DropDoneDetails details) async {
    if (details.files.isEmpty) return;

    final now = DateTime.now().toIso8601String();
    final crossFiles = <CrossFile>[];

    for (final xFile in details.files) {
      final path = xFile.path;
      final file = File(path);
      if (!file.existsSync() || FileSystemEntity.isDirectorySync(path)) {
        continue; // 跳过空路径或文件夹
      }
      final name = xFile.name;
      final size = file.lengthSync();
      final isImg = _isImage(name);
      final isVid = _isVideo(name);

      crossFiles.add(
        CrossFile(
          name: name,
          fileType: isImg ? FileType.image : (isVid ? FileType.video : FileType.other),
          size: size,
          thumbnail: null,
          asset: null,
          path: path,
          bytes: null,
          lastModified: now,
          lastAccessed: now,
        ),
      );
    }

    if (crossFiles.isEmpty || !mounted) return;
    await context.ref.notifier(sendProvider).startSession(
      target: widget.device,
      files: crossFiles,
      background: true,
    );
    _scrollToBottom();
  }

  Future<void> _handlePaste() async {
    // 1. 优先检测剪贴板里是否有截图图片
    final imageBytes = await Pasteboard.image;
    if (imageBytes != null && imageBytes.isNotEmpty) {
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('发送剪贴板图片', style: TextStyle(fontSize: 16)),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320, maxHeight: 280),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(imageBytes, fit: BoxFit.contain),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF07C160), foregroundColor: Colors.white),
              autofocus: true,
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('发送'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await _sendImageBytes(imageBytes);
      }
      return;
    }

    // 2. 其次检测剪贴板里是否有直接 Ctrl+C 复制的本地文件
    final copiedPaths = await Pasteboard.files();
    if (copiedPaths.isNotEmpty) {
      final now = DateTime.now().toIso8601String();
      final crossFiles = <CrossFile>[];
      for (final path in copiedPaths) {
        final file = File(path);
        if (!file.existsSync() || FileSystemEntity.isDirectorySync(path)) continue;
        final name = path.split(Platform.pathSeparator).last;
        final isImg = _isImage(name);
        final isVid = _isVideo(name);
        crossFiles.add(
          CrossFile(
            name: name,
            fileType: isImg ? FileType.image : (isVid ? FileType.video : FileType.other),
            size: file.lengthSync(),
            thumbnail: null,
            asset: null,
            path: path,
            bytes: null,
            lastModified: now,
            lastAccessed: now,
          ),
        );
      }
      if (crossFiles.isNotEmpty && mounted) {
        await context.ref.notifier(sendProvider).startSession(
          target: widget.device,
          files: crossFiles,
          background: true,
        );
        _scrollToBottom();
      }
      return;
    }

    // 3. 如果是纯文本，正常追加到输入框里
    final textData = await Clipboard.getData(Clipboard.kTextPlain);
    if (textData?.text != null && textData!.text!.isNotEmpty) {
      final current = _textController.text;
      final selection = _textController.selection;
      if (selection.isValid) {
        final newText = current.replaceRange(selection.start, selection.end, textData.text!);
        _textController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: selection.start + textData.text!.length),
        );
      } else {
        _textController.text = current + textData.text!;
      }
    }
  }

  Future<void> _sendImageBytes(Uint8List bytes) async {
    final now = DateTime.now().toIso8601String();
    final fileName = 'screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
    final imgFile = CrossFile(
      name: fileName,
      fileType: FileType.image,
      size: bytes.length,
      thumbnail: null,
      asset: null,
      path: null,
      bytes: bytes,
      lastModified: now,
      lastAccessed: now,
    );

    if (!mounted) return;
    await context.ref.notifier(sendProvider).startSession(
      target: widget.device,
      files: [imgFile],
      background: true,
    );
    _scrollToBottom();
  }


  String get _deviceKey => widget.device.fingerprint.isNotEmpty ? widget.device.fingerprint : (widget.device.ip ?? '');

  bool _isImage(String name) {
    final ext = name.toLowerCase();
    return ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.png') || ext.endsWith('.gif') || ext.endsWith('.webp') || ext.endsWith('.bmp');
  }

  bool _isVideo(String name) {
    final ext = name.toLowerCase();
    return ext.endsWith('.mp4') || ext.endsWith('.mov') || ext.endsWith('.avi') || ext.endsWith('.mkv') || ext.endsWith('.webm');
  }

  Future<void> _openWithSystemApp(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('文件正在接收中，请稍后再试'), duration: Duration(seconds: 2)));
      }
      return;
    }
    if (Platform.isWindows) {
      await Process.run('explorer', [filePath]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [filePath]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [filePath]);
    }
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
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }


  Widget _buildBubble(ChatMessage msg) {
    // 1. 图片消息（支持自动等待下载完成后显示缩略图 + 点击放大）
    if (msg.imageBytes != null || (msg.fileName != null && _isImage(msg.fileName!) && msg.filePath != null)) {
      return _ChatImageBubble(
        imageBytes: msg.imageBytes,
        filePath: msg.filePath,
        onTap: (bytes, path) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _FullScreenImagePage(imageBytes: bytes, filePath: path),
            ),
          );
        },
      );
    }

    // 2. 视频消息（显示微信视频卡片 + 点击调用电脑默认播放器打开）
    if (msg.isVideo && msg.filePath != null) {
      return GestureDetector(
        onTap: () => _openWithSystemApp(msg.filePath!),
        child: Container(
          width: 210,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF2B2B2B),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.play_circle_fill, size: 40, color: Color(0xFF07C160)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      msg.fileName ?? '视频文件',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    const Text('点击使用播放器打开', style: TextStyle(color: Colors.white60, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 3. 普通文件或纯文本消息（点击文件可直接用系统软件打开，长按复制文字）
    return GestureDetector(
      onTap: () {
        if (msg.filePath != null) {
          _openWithSystemApp(msg.filePath!);
        }
      },
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
          msg.fileName != null ? '📄 [文件] ${msg.fileName}' : (msg.text ?? ''),
          style: const TextStyle(fontSize: 15, color: Colors.black87),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.ref.watch(chatHistoryProvider)[_deviceKey] ?? [];
final sessions = context.ref.watch(sendProvider);
for (final msg in messages) {
  if (msg.isMe && msg.sessionId != null && msg.status == MsgSendStatus.sending) {
    final session = sessions[msg.sessionId];
    if (session != null) {
      if (session.status == SessionStatus.finished) {
        Future.microtask(() => context.ref.notifier(chatHistoryProvider).updateSessionStatus(msg.sessionId!, MsgSendStatus.success));
      } else if (session.status == SessionStatus.declined ||
          session.status == SessionStatus.recipientBusy ||
          session.status == SessionStatus.finishedWithErrors ||
          session.status == SessionStatus.canceledBySender ||
          session.status == SessionStatus.canceledByReceiver) {
        Future.microtask(() => context.ref.notifier(chatHistoryProvider).updateSessionStatus(msg.sessionId!, MsgSendStatus.failed));
      }
    }
  }
}




    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyV, control: true): _handlePaste,
        const SingleActivator(LogicalKeyboardKey.keyV, meta: true): _handlePaste,
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFEDEDED),
        appBar: AppBar(
          backgroundColor: const Color(0xFFEDEDED),
          foregroundColor: Colors.black,
          elevation: 0.5,
          title: Text(widget.device.alias, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        ),

      body: DropTarget(
        onDragEntered: (_) => setState(() => _isDragging = true),
        onDragExited: (_) => setState(() => _isDragging = false),
        onDragDone: (details) async {
          setState(() => _isDragging = false);
          await _handleDroppedFiles(details);
        },
        child: Stack(
          children: [
            Column(
              children: [
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              interactive: true,
              child: ListView.builder(
                controller: _scrollController,
                reverse: true, // 核心：从底部开始排列，新消息永远在最下方
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  // 因为 reverse: true，索引 0 显示在最底部，所以倒序取最后一条消息
                  final msg = messages[messages.length - 1 - index];
                  return Align(
                    alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (msg.isMe) _buildStatusIcon(msg),
                          _buildBubble(msg),
                        ],
                      ),
                    ),
                  );
                },
              ),
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
                              hintText: '输入消息...',
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
                          child: const Text('发送'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_isDragging)
              Positioned.fill(
                child: Container(
                  color: const Color(0xCC07C160),
                  alignment: Alignment.center,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.file_upload_outlined, size: 64, color: Colors.white),
                      SizedBox(height: 12),
                      Text(
                        '松开鼠标立即发送文件',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),

class _ChatImageBubble extends StatefulWidget {
  final Uint8List? imageBytes;
  final String? filePath;
  final void Function(Uint8List? bytes, String? path) onTap;

  const _ChatImageBubble({this.imageBytes, this.filePath, required this.onTap});

  @override
  State<_ChatImageBubble> createState() => _ChatImageBubbleState();
}

class _ChatImageBubbleState extends State<_ChatImageBubble> {
  Timer? pollTimer;
  bool isFileReady = false;
  int retryCount = 0;

  @override
  void initState() {
    super.initState();
    checkFile();
    if (!isFileReady && widget.imageBytes == null && widget.filePath != null) {
      pollTimer = Timer.periodic(const Duration(milliseconds: 500), (t) {
        retryCount++;
        checkFile();
        if (isFileReady || retryCount > 40) {
          t.cancel();
        }
      });
    }
  }

  void checkFile() {
    if (widget.filePath != null) {
      final f = File(widget.filePath!);
      if (f.existsSync() && f.lengthSync() > 0) {
        if (mounted) {
          setState(() => isFileReady = true);
        }
      }
    }
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageBytes != null) {
      return GestureDetector(
        onTap: () => widget.onTap(widget.imageBytes, null),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.memory(widget.imageBytes!, width: 180, fit: BoxFit.cover),
        ),
      );
    }

    if (isFileReady && widget.filePath != null) {
      return GestureDetector(
        onTap: () => widget.onTap(null, widget.filePath),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.file(
            File(widget.filePath!),
            width: 180,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, stack) {
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) setState(() {});
              });
              return buildPlaceholder();
            },
          ),
        ),
      );
    }

    return buildPlaceholder();
  }

  Widget buildPlaceholder() {
    return Container(
      width: 180,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF07C160)),
      ),
    );
  }
}

class _FullScreenImagePage extends StatelessWidget {
  final Uint8List? imageBytes;
  final String? filePath;

  const _FullScreenImagePage({this.imageBytes, this.filePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: imageBytes != null
              ? Image.memory(imageBytes!, fit: BoxFit.contain)
              : Image.file(File(filePath!), fit: BoxFit.contain),
        ),
      ),
    );
  }
}

