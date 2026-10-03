import 'package:PiliPlus/pages/live_room/controller.dart';
import 'package:PiliPlus/pages/live_room/live_room_settings.dart';
import 'package:PiliPlus/pages/live_room/widgets/live_settings_panel.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

Future<void> showLiveSettings(
  BuildContext context,
  LiveRoomController controller, {
  required VoidCallback onDisplaySettings,
  LiveSettingsSection section = LiveSettingsSection.danmaku,
}) async {
  final action = await showDialog<String>(
    context: context,
    builder: (dialogContext) => LiveSettingsPanel(
      settings: controller.settings,
      initialSection: section,
      danmakuVisibility: Obx(
        () => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('显示画面弹幕'),
          subtitle: controller.plPlayerController.tempPlayerConf
              ? const Text('已启用临时播放器配置，本开关仅本次有效')
              : null,
          value: controller.plPlayerController.enableShowLiveDanmaku.value,
          onChanged: controller.setDanmakuVisible,
        ),
      ),
      onDisplaySettings: () => Navigator.of(dialogContext).pop('display'),
      onBlockRules: () {
        if (!Accounts.main.isLogin) {
          SmartDialog.showToast('请登录后管理平台屏蔽规则');
          return;
        }
        Navigator.of(dialogContext).pop('block');
      },
    ),
  );
  if (!context.mounted) return;
  if (action == 'display') {
    onDisplaySettings();
  } else if (action == 'block') {
    Get.toNamed(
      '/liveDmBlockPage',
      parameters: {'roomId': '${controller.roomId}'},
      arguments: controller,
    );
  }
}
