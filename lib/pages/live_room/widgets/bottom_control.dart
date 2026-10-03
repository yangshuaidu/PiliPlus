import 'package:PiliPlus/pages/live_room/widgets/live_settings_dialog.dart';
import 'package:PiliPlus/pages/live_room/live_room_settings.dart';
import 'package:PiliPlus/common/widgets/custom_icon.dart';
import 'package:PiliPlus/pages/live_room/controller.dart';
import 'package:PiliPlus/pages/live_room/widgets/gift_sheet.dart';
import 'package:PiliPlus/pages/video/widgets/header_mixin.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/video_fit_type.dart';
import 'package:PiliPlus/plugin/pl_player/widgets/common_btn.dart';
import 'package:PiliPlus/plugin/pl_player/widgets/play_pause_btn.dart';
import 'package:PiliPlus/utils/theme_utils.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class BottomControl extends StatefulWidget {
  const BottomControl({
    super.key,
    required this.plPlayerController,
    required this.liveRoomCtr,
    required this.onRefresh,
    this.subTitleStyle = const TextStyle(fontSize: 12),
    this.titleStyle = const TextStyle(fontSize: 14),
  });

  final PlPlayerController plPlayerController;
  final LiveRoomController liveRoomCtr;
  final VoidCallback onRefresh;

  final TextStyle subTitleStyle;
  final TextStyle titleStyle;

  @override
  State<BottomControl> createState() => _BottomControlState();
}

class _BottomControlState extends State<BottomControl> with HeaderMixin {
  late final LiveRoomController liveRoomCtr = widget.liveRoomCtr;
  @override
  late final PlPlayerController plPlayerController = widget.plPlayerController;
  @override
  ThemeData get theme => ThemeUtils.darkTheme;

  @override
  Widget build(BuildContext context) {
    final isFullScreen = plPlayerController.isFullScreen.value;
    return Padding(
      padding: const .symmetric(horizontal: 14, vertical: 13),
      child: Material(
        type: .transparency,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: IntrinsicWidth(
                child: Row(
                  children: [
                    PlayOrPauseButton(plPlayerController: plPlayerController),
                    ComBtn(
                      height: 30,
                      tooltip: '刷新',
                      icon: const Icon(
                        Icons.refresh,
                        size: 18,
                        color: Colors.white,
                      ),
                      onTap: widget.onRefresh,
                    ),
                    const Spacer(),
                    if (isFullScreen)
                      ComBtn(
                        height: 30,
                        tooltip: '礼物',
                        icon: const Icon(
                          Icons.card_giftcard,
                          size: 18,
                          color: Colors.white,
                        ),
                        onTap: () => showLiveGiftPanel(
                          context,
                          roomId: liveRoomCtr.roomId,
                          anchorUid: liveRoomCtr.ruid,
                          anchorName:
                              liveRoomCtr
                                  .roomInfoH5
                                  .value
                                  ?.anchorInfo
                                  ?.baseInfo
                                  ?.uname ??
                              '当前主播',
                          areaId:
                              liveRoomCtr.roomInfoH5.value?.roomInfo?.areaId,
                          parentAreaId: liveRoomCtr
                              .roomInfoH5
                              .value
                              ?.roomInfo
                              ?.parentAreaId,
                        ),
                      ),
                    for (final section in [
                      LiveSettingsSection.gifts,
                      LiveSettingsSection.notifications,
                    ])
                      ComBtn(
                        height: 30,
                        tooltip: section.title,
                        icon: Icon(
                          section == LiveSettingsSection.gifts
                              ? Icons.card_giftcard_outlined
                              : Icons.notifications_outlined,
                          size: 18,
                          color: Colors.white,
                        ),
                        onTap: () => showLiveSettings(
                          context,
                          liveRoomCtr,
                          section: section,
                          onDisplaySettings: () => showSetDanmaku(isLive: true),
                        ),
                      ),
                    const SizedBox(width: 3),
                    Obx(
                      () {
                        final enableShowLiveDanmaku =
                            plPlayerController.enableShowLiveDanmaku.value;
                        return ComBtn(
                          height: 30,
                          tooltip: "${enableShowLiveDanmaku ? '关闭' : '开启'}弹幕",
                          icon: enableShowLiveDanmaku
                              ? const Icon(
                                  size: 18,
                                  CustomIcons.dm_on,
                                  color: Colors.white,
                                )
                              : const Icon(
                                  size: 18,
                                  CustomIcons.dm_off,
                                  color: Colors.white,
                                ),
                          onTap: () => liveRoomCtr.setDanmakuVisible(
                            !enableShowLiveDanmaku,
                          ),
                        );
                      },
                    ),
                    ComBtn(
                      height: 30,
                      tooltip: '弹幕设置',
                      icon: const Icon(
                        size: 18,
                        CustomIcons.dm_settings,
                        color: Colors.white,
                      ),
                      onTap: () => showLiveSettings(
                        context,
                        liveRoomCtr,
                        onDisplaySettings: () => showSetDanmaku(isLive: true),
                      ),
                    ),
                    Obx(
                      () => PopupMenuButton<VideoFitType>(
                        tooltip: '画面比例',
                        initialValue: plPlayerController.videoFit.value,
                        color: Colors.black.withValues(alpha: 0.8),
                        itemBuilder: (context) {
                          return VideoFitType.values
                              .map(
                                (boxFit) => PopupMenuItem<VideoFitType>(
                                  height: 35,
                                  padding: const EdgeInsets.only(left: 30),
                                  value: boxFit,
                                  onTap: () =>
                                      plPlayerController.toggleVideoFit(boxFit),
                                  child: Text(
                                    boxFit.desc,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              )
                              .toList();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            plPlayerController.videoFit.value.desc,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Obx(
                      () => PopupMenuButton<int>(
                        tooltip: '画质',
                        padding: EdgeInsets.zero,
                        initialValue: liveRoomCtr.currentQn,
                        color: Colors.black.withValues(alpha: 0.8),
                        itemBuilder: (context) {
                          return liveRoomCtr.acceptQnList
                              .map(
                                (e) => PopupMenuItem<int>(
                                  height: 35,
                                  padding: const EdgeInsets.only(left: 30),
                                  value: e.code,
                                  onTap: () => liveRoomCtr.changeQn(e.code),
                                  child: Text(
                                    e.desc,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              )
                              .toList();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            liveRoomCtr.currentQnDesc.value,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (!plPlayerController.isDesktopPip)
                      ComBtn(
                        height: 30,
                        tooltip: isFullScreen ? '退出全屏' : '全屏',
                        icon: isFullScreen
                            ? const Icon(
                                Icons.fullscreen_exit,
                                size: 24,
                                color: Colors.white,
                              )
                            : const Icon(
                                Icons.fullscreen,
                                size: 24,
                                color: Colors.white,
                              ),
                        onTap: () => plPlayerController.triggerFullScreen(
                          status: !isFullScreen,
                        ),
                        onSecondaryTap: () =>
                            plPlayerController.triggerFullScreen(
                              status: !isFullScreen,
                              inAppFullScreen: true,
                            ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
