
import 'package:flutter/material.dart';
import 'package:localsend_app/pages/tabs/send_tab_vm.dart';
import 'package:localsend_app/pages/wechat_room_page.dart';
import 'package:localsend_app/provider/chat_history_provider.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/provider/network/scan_facade.dart';
import 'package:localsend_app/widget/custom_icon_button.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

class SendTab extends StatelessWidget {
  const SendTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder(
      provider: (ref) => sendTabVmProvider,
      init: (context) async => context.global.dispatchAsync(SendTabInitAction(context)), // ignore: discarded_futures
      builder: (context, vm) {
        final chatHistory = context.ref.watch(chatHistoryProvider);

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: const Color(0xFFEDEDED),
            elevation: 0.5,
            title: const Text('文件传输', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600)),
            actions: [
              CustomIconButton(
                onPressed: () async {
                  context.redux(nearbyDevicesProvider).dispatch(ClearFoundDevicesAction());
                  await context.global.dispatchAsync(StartSmartScan());
                },
                child: const Icon(Icons.refresh, color: Colors.black87),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.black87),
                onPressed: () async => vm.onTapAddress(context), // 手动输入 IP 连线
              ),
            ],
          ),
          body: vm.nearbyDevices.isEmpty
              ? const Center(
                  child: Text('正在搜寻附近设备...', style: TextStyle(color: Colors.grey)),
                )
              : ListView.separated(
                  itemCount: vm.nearbyDevices.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 72, color: Color(0xFFEDEDED)),
                  itemBuilder: (context, index) {
                    final device = vm.nearbyDevices.elementAt(index);
                    final deviceKey = device.fingerprint.isNotEmpty ? device.fingerprint : (device.ip ?? '');
                    final lastMsg = chatHistory[deviceKey]?.lastOrNull;
                    final subtitleText = lastMsg != null
                        ? (lastMsg.fileName != null ? '[文件] ${lastMsg.fileName}' : (lastMsg.text ?? ''))
                        : '${device.deviceModel ?? '局域网设备'} (${device.ip})';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF07C160),
                          borderRadius: BorderRadius.circular(6), // 微信经典微圆角方形头像
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          device.alias.characters.first.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        device.alias,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
                      ),
                      subtitle: Text(
                        subtitleText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      onTap: () {
                        context.push(() => WeChatRoomPage(device: device));
                      },
                    );
                  },
                ),
        );
      },
    );
  }
}

