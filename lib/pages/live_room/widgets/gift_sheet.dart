import 'package:PiliPlus/pages/live_room/widgets/gift_panel.dart';
import 'package:PiliPlus/services/live_gift_gateway.dart';
import 'package:PiliPlus/utils/accounts.dart';
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (context) =>
          LiveGiftPanel(service: service, anchorName: anchorName),
    );
  } finally {
    service.dispose();
  }
}
