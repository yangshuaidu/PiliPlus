import 'package:PiliPlus/pages/live_room/controller.dart';
import 'package:PiliPlus/pages/live_room/live_message_filters.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

Future<void> showLiveMessageFilters(
  BuildContext context,
  LiveRoomController controller,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('直播消息与屏蔽'),
    content: SizedBox(
      width: 380,
      child: SingleChildScrollView(
        child: Obx(
          () => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('显示榜单、等级与头衔'),
                value: controller.showMessageBadges.value,
                onChanged: controller.showMessageBadges.call,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('显示系统消息'),
                value: controller.showRoomNotices.value,
                onChanged: controller.showRoomNotices.call,
              ),
              const Divider(),
              for (final filter in LiveMessageFilter.values)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(filter.label),
                  value: controller.filters.hides(filter),
                  onChanged: (value) =>
                      controller.updateMessageFilter(filter, value),
                ),
              const Text(
                '分类屏蔽保存在本机。礼物动画目前支持 GIF / WebP，无礼物音效。',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  if (!Accounts.main.isLogin) {
                    SmartDialog.showToast('请登录后管理平台屏蔽规则');
                    return;
                  }
                  Navigator.pop(context);
                  Get.toNamed(
                    '/liveDmBlockPage',
                    parameters: {'roomId': '${controller.roomId}'},
                    arguments: controller,
                  );
                },
                icon: const Icon(Icons.block),
                label: const Text('管理屏蔽词与用户'),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('完成'),
      ),
    ],
  ),
);
