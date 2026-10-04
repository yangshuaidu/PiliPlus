import 'package:PiliPlus/pages/live_room/widgets/gift_panel.dart';
import 'package:PiliPlus/pages/live_room/widgets/live_panel_surface.dart';
import 'package:PiliPlus/pages/live_room/widgets/red_packet_panel.dart';
import 'package:PiliPlus/services/live_red_packet_service.dart';
import 'package:PiliPlus/services/live_gift_gateway.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_ui/material_ui.dart';

Future<void> showLiveGiftPanel(
  BuildContext context, {
  required int roomId,
  required int? anchorUid,
  required String anchorName,
  int? areaId,
  int? parentAreaId,
}) async {
  if (!Accounts.main.isLogin) {
    SmartDialog.showToast('请先登录后再送礼');
    return;
  }
  if (roomId <= 0 || anchorUid == null || anchorUid <= 0) {
    SmartDialog.showToast('主播信息尚未加载，请稍后重试');
    return;
  }
  final service = createLiveGiftService(
    roomId: roomId,
    anchorUid: anchorUid,
    areaId: areaId,
    parentAreaId: parentAreaId,
  );
  try {
    await showLivePanel<void>(
      context,
      (context) => LiveGiftPanel(
        service: service,
        anchorName: anchorName,
        onRecharge: () => PageUtils.launchURL(
          'https://link.bilibili.com/p/live-h5-recharge/',
        ),
        onRedPacket: () async {
          final redPackets = LiveRedPacketService(service);
          try {
            await showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              isDismissible: false,
              enableDrag: false,
              constraints: const BoxConstraints(maxWidth: 600),
              builder: (_) => LiveRedPacketPanel(
                service: redPackets,
                anchorName: anchorName,
              ),
            );
          } finally {
            redPackets.dispose();
          }
        },
      ),
    );
  } finally {
    service.dispose();
  }
}
