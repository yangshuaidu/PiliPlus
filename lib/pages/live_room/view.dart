import 'package:PiliPlus/pages/live_room/widgets/live_action_menu.dart';
import 'package:PiliPlus/pages/live_room/widgets/live_panel_surface.dart';
import 'package:PiliPlus/pages/live_room/widgets/superchat_purchase_panel.dart';
import 'package:PiliPlus/plugin/pl_player/models/video_fit_type.dart';
import 'package:PiliPlus/services/shutdown_timer_service.dart' show shutdownTimerService;
import 'package:PiliPlus/pages/setting/models/play_settings.dart' show showPlayerVolumeDialog;
import 'package:PiliPlus/pages/video/widgets/header_control.dart' show HeaderControlState;
import 'package:PiliPlus/pages/live_room/widgets/live_settings_dialog.dart';
import 'package:PiliPlus/pages/live_room/live_room_settings.dart';
import 'package:PiliPlus/pages/video/widgets/header_mixin.dart';

import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:PiliPlus/common/assets.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/button/icon_button.dart';
import 'package:PiliPlus/common/widgets/custom_icon.dart';
import 'package:PiliPlus/common/widgets/extra_hittest_stack.dart';
import 'package:PiliPlus/common/widgets/flutter/pop_scope.dart';
import 'package:PiliPlus/common/widgets/gesture/horizontal_drag_gesture_recognizer.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/keep_alive_wrapper.dart';
import 'package:PiliPlus/common/widgets/route_aware_mixin.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/scroll_physics.dart'
    show tabBarScrollPhysics;
import 'package:PiliPlus/models/common/live/live_contribution_rank_type.dart';
import 'package:PiliPlus/models_new/live/live_room_info_h5/data.dart';
import 'package:PiliPlus/models_new/live/live_superchat/item.dart';
import 'package:PiliPlus/pages/danmaku/danmaku_model.dart';
import 'package:PiliPlus/pages/live_room/contribution_rank/controller.dart';
import 'package:PiliPlus/pages/live_room/contribution_rank/view.dart';
import 'package:PiliPlus/pages/live_room/widgets/guard_rank_panel.dart';
import 'package:PiliPlus/pages/live_room/widgets/activity_panel.dart';
import 'package:PiliPlus/pages/live_room/widgets/gift_effect_overlay.dart';
import 'package:PiliPlus/pages/live_room/widgets/pk_bar.dart';
import 'package:PiliPlus/pages/live_room/controller.dart';
import 'package:PiliPlus/pages/live_room/superchat/superchat_card.dart';
import 'package:PiliPlus/pages/live_room/superchat/superchat_panel.dart';
import 'package:PiliPlus/pages/live_room/widgets/bottom_control.dart';
import 'package:PiliPlus/pages/live_room/widgets/chat_panel.dart';
import 'package:PiliPlus/pages/live_room/widgets/gift_sheet.dart';
import 'package:PiliPlus/pages/live_room/widgets/header_control.dart';
import 'package:PiliPlus/pages/video/widgets/player_focus.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_status.dart';
import 'package:PiliPlus/plugin/pl_player/utils/danmaku_options.dart';
import 'package:PiliPlus/plugin/pl_player/utils/fullscreen.dart';
import 'package:PiliPlus/plugin/pl_player/view/view.dart';
import 'package:PiliPlus/services/service_locator.dart';
import 'package:PiliPlus/utils/android/bindings.g.dart';
import 'package:PiliPlus/utils/extension/num_ext.dart';
import 'package:PiliPlus/utils/extension/size_ext.dart';
import 'package:PiliPlus/utils/image_utils.dart';
import 'package:PiliPlus/utils/max_screen_size.dart';
import 'package:PiliPlus/utils/mobile_observer.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/share_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/theme_utils.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:canvas_danmaku/danmaku_screen.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:screen_brightness_platform_interface/screen_brightness_platform_interface.dart';

const baseWhite = Color(0xFFEEEEEE);

class LiveRoomPage extends StatefulWidget {
  const LiveRoomPage({super.key});

  @override
  State<LiveRoomPage> createState() => _LiveRoomPageState();
}

class _LiveRoomPageState extends State<LiveRoomPage>
    with
        HeaderMixin<LiveRoomPage>,
        WidgetsBindingObserver,
        RouteAware,
        RouteAwareMixin {
  late final fullScreenSCWidth = Pref.fullScreenSCWidth;
  final String heroTag = Utils.generateRandomString(6);
  late final LiveRoomController _liveRoomController;
  @override
  late final PlPlayerController plPlayerController;

  late final GlobalKey pageKey = GlobalKey();
  late final GlobalKey chatKey = GlobalKey();
  late final GlobalKey scKey = GlobalKey();
  late final GlobalKey playerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    addObserverMobile(this);
    _liveRoomController = Get.put(
      LiveRoomController(heroTag),
      tag: heroTag,
    );
    plPlayerController = _liveRoomController.plPlayerController
      ..addStatusLister(playerListener);
    PlPlayerController.setPlayCallBack(plPlayerController.play);
    if (plPlayerController.removeSafeArea) {
      hideSystemBar();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (plPlayerController.removeSafeArea) {
      padding = .zero;
    } else {
      padding = MediaQuery.viewPaddingOf(context);
    }
    final size = MediaQuery.sizeOf(context);
    maxWidth = size.width;
    maxHeight = size.height;
    isWindowMode = MaxScreenSize.isWindowMode(
      width: maxWidth * plPlayerController.uiScale,
      height: maxHeight * plPlayerController.uiScale,
    );
    isPortrait = size.isPortrait;
    plPlayerController.screenRatio = maxHeight / maxWidth;
  }

  @override
  Future<void> didPopNext() async {
    addObserverMobile(this);
    if (!plPlayerController.isLive) {
      plPlayerController.isLive = true;
      _liveRoomController.isLoaded.refresh();
    }
    plPlayerController.danmakuController =
        _liveRoomController.danmakuController;
    PlPlayerController.setPlayCallBack(plPlayerController.play);
    _liveRoomController.startLiveTimer();
    if (plPlayerController.playerStatus.isPlaying &&
        plPlayerController.cid == null) {
      _liveRoomController
        ..danmakuController?.resume()
        ..startLiveMsg();
    } else {
      final shouldPlay = _liveRoomController.isPlaying ?? false;
      if (shouldPlay) {
        _liveRoomController
          ..danmakuController?.resume()
          ..startLiveMsg();
      }
      await _liveRoomController.playerInit(autoplay: shouldPlay);
    }
    if (!mounted) return;
    plPlayerController.addStatusLister(playerListener);
    super.didPopNext();
  }

  @override
  void didPushNext() {
    removeObserverMobile(this);
    plPlayerController.removeStatusLister(playerListener);
    _liveRoomController
      ..danmakuController?.clear()
      ..cancelLiveTimer()
      ..closeLiveMsg()
      ..isPlaying = plPlayerController.playerStatus.isPlaying;
    super.didPushNext();
  }

  void playerListener(PlayerStatus status) {
    if (status.isPlaying) {
      _liveRoomController
        ..danmakuController?.resume()
        ..startLiveTimer()
        ..startLiveMsg();
    } else {
      _liveRoomController
        ..danmakuController?.pause()
        ..cancelLiveTimer()
        ..closeLiveMsg();
    }
  }

  @override
  void dispose() {
    removeObserverMobile(this);
    videoPlayerServiceHandler?.onVideoDetailDispose(heroTag);
    if (Platform.isAndroid && !plPlayerController.setSystemBrightness) {
      ScreenBrightnessPlatform.instance.resetApplicationScreenBrightness();
    }
    PlPlayerController.setPlayCallBack(null);
    plPlayerController
      ..removeStatusLister(playerListener)
      ..dispose();
    for (final e in LiveContributionRankType.values) {
      Get.delete<ContributionRankController>(
        tag: '${_liveRoomController.roomId}${e.name}',
      );
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (plPlayerController.visible = state == .resumed) {
      if (!plPlayerController.showDanmaku) {
        _liveRoomController
          ..refreshMsgIfNeeded()
          ..startLiveTimer();
        plPlayerController.showDanmaku = true;
      }
    } else if (state == .paused) {
      _liveRoomController.cancelLiveTimer();
      plPlayerController
        ..showDanmaku = false
        ..danmakuController?.clear();
    }
  }

  late double maxWidth;
  late double maxHeight;
  bool isWindowMode = false;
  late EdgeInsets padding;
  late bool isPortrait;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (Platform.isAndroid && AndroidHelper.isPipMode) {
      child = videoPlayerPanel(
        isFullScreen,
        width: maxWidth,
        height: maxHeight,
        isPipMode: true,
        needDm: !plPlayerController.pipNoDanmaku,
      );
    } else {
      child = childWhenDisabled;
    }
    if (plPlayerController.keyboardControl) {
      child = PlayerFocus(
        plPlayerController: plPlayerController,
        onSendDanmaku: _liveRoomController.onSendDanmaku,
        onRefresh: _liveRoomController.queryLiveUrl,
        child: child,
      );
    }
    return Theme(
      data: ThemeUtils.darkTheme,
      child: child,
    );
  }

  Widget videoPlayerPanel(
    bool isFullScreen, {
    required double width,
    required double height,
    bool isPipMode = false,
    Color fill = Colors.black,
    Alignment alignment = Alignment.center,
    bool needDm = true,
  }) {
    if (!isFullScreen && !plPlayerController.isDesktopPip) {
      _liveRoomController.fsSC.value = null;
    }
    _liveRoomController.isFullScreen = isFullScreen;
    Widget player = Obx(
      key: playerKey,
      () {
        final message = _liveRoomController.playbackMessage.value;
        if (message != null) {
          return ColoredBox(color: const Color(0xFF191A21), child: Center(child: Padding(
            padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.live_tv_outlined, color: Colors.white54, size: 38),
              const SizedBox(height: 12), Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 15)),
              const SizedBox(height: 8), TextButton.icon(onPressed: _liveRoomController.queryLiveUrl, icon: const Icon(Icons.refresh, size: 18), label: const Text('刷新')),
            ]),
          )));
        }
        if (_liveRoomController.isLoaded.value && plPlayerController.isLive) {
          final roomInfoH5 = _liveRoomController.roomInfoH5.value;
          return PLVideoPlayer(
            maxWidth: width,
            maxHeight: height,
            fill: fill,
            alignment: alignment,
            plPlayerController: plPlayerController,
            headerControl: LiveHeaderControl(
              key: _liveRoomController.headerKey,
              title: roomInfoH5?.roomInfo?.title,
              upName: roomInfoH5?.anchorInfo?.baseInfo?.uname,
              plPlayerController: plPlayerController,
              onSendDanmaku: _liveRoomController.onSendDanmaku,
              onPlayAudio: _liveRoomController.queryLiveUrl,
              isPortrait: isPortrait,
              liveController: _liveRoomController,
              onlineWidget: onlineWidget,
              onMore: _showMore,
            ),
            bottomControl: BottomControl(
              plPlayerController: plPlayerController,
              liveRoomCtr: _liveRoomController,
              onMore: _showMore,
              onQuality: _showQuality,
            ),
            danmuWidget: !needDm
                ? null
                : LiveDanmaku(
                    liveRoomController: _liveRoomController,
                    plPlayerController: plPlayerController,
                    isFullScreen: isFullScreen,
                    isPipMode: plPlayerController.isDesktopPip || isPipMode,
                    size: Size(width, height),
                  ),
          );
        }
        return const SizedBox.shrink();
      },
    );
    if (_liveRoomController.showSuperChat &&
        (isFullScreen || plPlayerController.isDesktopPip)) {
      player = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: player),
          if (kDebugMode) ...[
            Positioned(
              top: 50,
              right: 0,
              child: TextButton(
                onPressed: () {
                  final item = SuperChatItem.random;
                  _liveRoomController
                    ..fsSC.value = item
                    ..addDm(item);
                },
                child: const Text('add superchat'),
              ),
            ),
            Positioned(
              right: 0,
              top: 90,
              child: TextButton(
                onPressed: () {
                  _liveRoomController.fsSC.value = null;
                },
                child: const Text('remove superchat'),
              ),
            ),
          ],
          Positioned(
            left: padding.left + 25,
            bottom: 25,
            width: fullScreenSCWidth,
            child: Obx(() {
              final item = _liveRoomController.fsSC.value;
              if (item == null) {
                return const SizedBox.shrink();
              }
              try {
                return ExtraHitTestStack(
                  key: ValueKey(item.id),
                  clipBehavior: Clip.none,
                  children: [
                    SuperChatCard(
                      item: item,
                      onRemove: () => _liveRoomController.fsSC.value = null,
                      onReport: () => _liveRoomController.reportSC(item),
                    ),
                    Positioned(
                      right: -6,
                      top: -6,
                      child: iconButton(
                        size: 24,
                        iconSize: 14,
                        bgColor: const Color(0xEEFFFFFF),
                        iconColor: Colors.black54,
                        icon: const Icon(Icons.clear),
                        onPressed: () => _liveRoomController.fsSC.value = null,
                      ),
                    ),
                  ],
                );
              } catch (_) {
                if (kDebugMode) rethrow;
                return const SizedBox.shrink();
              }
            }),
          ),
        ],
      );
    }
    if (!isPipMode && !plPlayerController.isDesktopPip) {
      player = Stack(
        children: [
          Positioned.fill(child: player),
          Positioned(
            left: 12,
            bottom: 64,
            child: LiveGiftEffectOverlay(
              effects: _liveRoomController.giftEffects,
            ),
          ),
          Positioned(
            right: 16,
            bottom: 64,
            child: IgnorePointer(
              child: Obx(() {
                final url = _liveRoomController.cornerEmoteUrl.value;
                return url == null
                    ? const SizedBox.shrink()
                    : Image.network(
                        url,
                        width: 88,
                        height: 88,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      );
              }),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Obx(() {
              final state = _liveRoomController.roomFeatures.pk.value;
              return state == null
                  ? const SizedBox.shrink()
                  : LivePkBar(state: state);
            }),
          ),
        ],
      );
    }
    return popScope(
      canPop: !isFullScreen && !plPlayerController.isDesktopPip,
      onPopInvokedWithResult: plPlayerController.onPopInvokedWithResult,
      child: player,
    );
  }

  Widget get childWhenDisabled {
    return Obx(() {
      final isFullScreen = this.isFullScreen || plPlayerController.isDesktopPip;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          const SizedBox.expand(child: ColoredBox(color: Colors.black)),
          if (!isFullScreen)
            Obx(
              () {
                final appBackground = _liveRoomController
                    .roomInfoH5
                    .value
                    ?.roomInfo
                    ?.appBackground;
                Widget child;
                if (appBackground != null && appBackground.isNotEmpty) {
                  child = CachedNetworkImage(
                    fit: BoxFit.cover,
                    width: maxWidth,
                    height: maxHeight,
                    memCacheWidth: maxWidth.cacheSize(context),
                    imageUrl: ImageUtils.safeThumbnailUrl(appBackground),
                    placeholder: (_, _) => const SizedBox.shrink(),
                  );
                } else {
                  child = Image.asset(
                    Assets.livingBackground,
                    fit: BoxFit.cover,
                    width: maxWidth,
                    height: maxHeight,
                    cacheWidth: maxWidth.cacheSize(context),
                  );
                }
                return Positioned.fill(
                  child: Opacity(opacity: 0.6, child: child),
                );
              },
            ),
          if (isPortrait && _liveRoomController.usePortraitOverlay && !isFullScreen)
            Positioned.fill(child: Stack(children: [
              Positioned.fill(child: _buildPP(false)),
              Positioned(top: 0, left: 0, right: 0, child: Obx(() => _liveRoomController.cleanScreen.value
                ? const SizedBox.shrink() : SizedBox(height: padding.top + kToolbarHeight, child: _buildAppBar(false)))),
            ]))
          else ScaffoldLayout(
            appBar: isWindowMode && isFullScreen && !isPortrait
                ? null
                : _buildAppBar(isFullScreen),
            body: isPortrait
                ? Obx(
                    () {
                      if (_liveRoomController.usePortraitOverlay) {
                        return _buildPP(isFullScreen);
                      }
                      return _buildPH(isFullScreen);
                    },
                  )
                : _buildBodyH(isFullScreen),
          ),
        ],
      );
    });
  }

  Widget _buildPH(bool isFullScreen) {
    final height = maxWidth / Style.aspectRatio16x9;
    final videoHeight = isFullScreen
        ? maxHeight - (isWindowMode && !isPortrait ? 0 : padding.top)
        : height;
    final bottomHeight = maxHeight - padding.top - height - kToolbarHeight;
    return Column(
      children: [
        SizedBox(
          width: maxWidth,
          height: videoHeight,
          child: videoPlayerPanel(
            isFullScreen,
            width: maxWidth,
            height: videoHeight,
          ),
        ),
        Offstage(
          offstage: isFullScreen,
          child: SizedBox(
            width: maxWidth,
            height: max(0, bottomHeight),
            child: _buildBottomWidget,
          ),
        ),
      ],
    );
  }

  Widget _buildPP(bool isFullScreen) => LayoutBuilder(builder: (context, constraints) {
    final height = constraints.maxHeight;
    final bottomHeight = 60.0 + padding.bottom;
    return Stack(children: [
      Positioned.fill(child: videoPlayerPanel(isFullScreen, width: constraints.maxWidth,
        height: height, needDm: isFullScreen, alignment: Alignment.center)),
      if (!isFullScreen) ...[
        const Positioned.fill(child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0x66000000), Colors.transparent, Colors.transparent, Color(0x99000000)], stops: [0, .25, .5, 1]),
        )))),
        Obx(() => _liveRoomController.cleanScreen.value ? const SizedBox.shrink() : Positioned(
          left: 0, right: 58, bottom: bottomHeight + 8, height: height * .29, child: _buildChatWidget(true))),
        Obx(() => _liveRoomController.cleanScreen.value ? const SizedBox.shrink() : Positioned(
          left: 0, right: 0, bottom: 0, height: bottomHeight, child: _buildInputWidget)),
        Obx(() => Positioned(right: 10, bottom: _liveRoomController.cleanScreen.value ? padding.bottom + 12 : bottomHeight + 10,
          child: Material(color: Colors.black45, shape: const CircleBorder(), child: IconButton(
            tooltip: _liveRoomController.cleanScreen.value ? '退出清屏' : '清屏',
            icon: Icon(_liveRoomController.cleanScreen.value ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white),
            onPressed: _liveRoomController.cleanScreen.toggle,
          )))),
      ],
    ]);
  });

  Widget get onlineWidget => GestureDetector(
    onTap: _showRank,
    child: Obx(() {
      final viewers = _liveRoomController.topViewers;
      return Tooltip(
        message: '观众与大航海榜',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (viewers.isNotEmpty)
              SizedBox(
                width: 24 + (viewers.length - 1) * 17,
                height: 24,
                child: Stack(
                  children: [
                    for (final (index, viewer) in viewers.indexed)
                      Positioned(
                        left: index * 17.0,
                        child: NetworkImgLayer(
                          src: viewer.face,
                          width: 24,
                          height: 24,
                          type: .avatar,
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 65),
              child: Text(
                _liveRoomController.onlineCount.value ?? '观众',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }),
  );

  void _showRank() {
    final live = _liveRoomController;
    if (live.ruid case final ruid?) {
      showLivePanel<void>(context, (context) => LivePanelSurface(child: DefaultTabController(length: 2, child: Column(children: [
        const LiveSheetHeading(title: '房间观众'),
        const TabBar(tabs: [Tab(text: '房间观众'), Tab(text: '大航海')]),
        Expanded(child: TabBarView(children: [
          ContributionRankPanel(ruid: ruid, roomId: live.roomId),
          ColoredBox(color: const Color(0xFF202536), child: LiveGuardRankPanel(roomId: live.roomId, ruid: ruid, embedded: true)),
        ])),
      ]))));
    }
  }

  void _showMore() {
    final live = _liveRoomController;
    final url = 'https://live.bilibili.com/${live.roomId}';
    showLiveActionMenu(context, title: '更多', sharing: [
      if (PlatformUtils.isMobile) LiveMenuAction('分享直播', Icons.share_outlined, () => ShareUtils.shareText(url)),
      LiveMenuAction('复制链接', Icons.link, () => Utils.copyText(url)),
      LiveMenuAction('浏览器打开', Icons.open_in_browser, () => PageUtils.inAppWebview(url, off: true)),
      if (live.roomInfoH5.value?.roomInfo case final room?)
        LiveMenuAction('分享至消息', Icons.forward_to_inbox_outlined, () => PageUtils.pmShare(context, content: {
          'cover': room.cover ?? '', 'sourceID': live.roomId.toString(),
          'title': room.title ?? '', 'url': url, 'authorID': room.uid.toString(),
          'source': '直播', 'desc': room.title ?? '',
          'author': live.roomInfoH5.value?.anchorInfo?.baseInfo?.uname ?? '',
        })),
    ], actions: [
      LiveMenuAction('刷新', Icons.refresh, live.queryLiveUrl),
      LiveMenuAction('播放设置', Icons.tune, _showPlaybackSettings),
      LiveMenuAction('清晰度', Icons.high_quality_outlined, _showQuality),
      LiveMenuAction(live.usePortraitOverlay ? '分区观看' : '竖屏全屏', Icons.stay_current_portrait, () {
        live.portraitOverlay.value = !live.usePortraitOverlay; live.cleanScreen.value = false;
      }),
      for (final section in LiveSettingsSection.values)
        LiveMenuAction(section.title, switch (section) {
          LiveSettingsSection.danmaku => Icons.chat_bubble_outline,
          LiveSettingsSection.gifts => Icons.auto_awesome_outlined,
          LiveSettingsSection.notifications => Icons.notifications_outlined,
        }, () => showLiveSettings(context, live, section: section, onDisplaySettings: () => showSetDanmaku(isLive: true))),
      LiveMenuAction('礼物', Icons.card_giftcard_outlined, _showGifts),
      LiveMenuAction('发红包', Icons.redeem, () => _showGifts(redPacket: true)),
      LiveMenuAction('醒目留言', Icons.chat_outlined, () => showLiveSuperChatPurchase(context,
        roomId: live.roomId, anchorUid: live.ruid,
        anchorName: live.roomInfoH5.value?.anchorInfo?.baseInfo?.uname ?? '当前主播',
        areaId: live.roomInfoH5.value?.roomInfo?.areaId,
        parentAreaId: live.roomInfoH5.value?.roomInfo?.parentAreaId)),
      LiveMenuAction('红包与天选', Icons.celebration_outlined, () => showLiveActivities(context, live.roomFeatures, live.ruid ?? 0)),
      LiveMenuAction('观众与大航海', Icons.groups_outlined, _showRank),
    ]);
  }

  void _showGifts({bool redPacket = false}) {
    final live = _liveRoomController;
    showLiveGiftPanel(context, roomId: live.roomId, anchorUid: live.ruid,
      anchorName: live.roomInfoH5.value?.anchorInfo?.baseInfo?.uname ?? '当前主播',
      areaId: live.roomInfoH5.value?.roomInfo?.areaId,
      parentAreaId: live.roomInfoH5.value?.roomInfo?.parentAreaId,
      redPacket: redPacket);
  }

  void _showQuality() => showLivePanel<void>(context, (context) => LivePanelSurface(
    child: Column(children: [const LiveSheetHeading(title: '清晰度'), Expanded(child: ListView(children: [
      for (final quality in _liveRoomController.acceptQnList)
        ListTile(title: Text(quality.desc), trailing: quality.code == _liveRoomController.currentQn ? const Icon(Icons.check, color: liveAccent) : null,
          onTap: () { Navigator.pop(context); _liveRoomController.changeQn(quality.code); }),
    ]))]),
  ));

  void _showPlaybackSettings() => showLivePanel<void>(context, (sheetContext) => LivePanelSurface(
    child: Column(children: [const LiveSheetHeading(title: '播放设置'), Expanded(child: ListView(children: [
      Obx(() => SwitchListTile.adaptive(title: const Text('后台播放'), subtitle: const Text('切换应用或锁屏后继续听直播'),
        value: plPlayerController.continueLiveInBackground.value, onChanged: plPlayerController.setContinueLiveInBackground)),
      Obx(() => SwitchListTile.adaptive(title: const Text('仅播放音频'), value: plPlayerController.onlyPlayAudio.value,
        onChanged: (value) { plPlayerController.onlyPlayAudio.value = value; _liveRoomController.queryLiveUrl(); })),
      ListTile(title: const Text('清晰度'), trailing: Obx(() => Text(_liveRoomController.currentQnDesc.value)),
        onTap: () { Navigator.pop(sheetContext); _showQuality(); }),
      ExpansionTile(title: const Text('画面比例'), children: [for (final fit in VideoFitType.values)
        Obx(() => RadioListTile<VideoFitType>(title: Text(fit.desc), value: fit, groupValue: plPlayerController.videoFit.value,
          onChanged: (value) { if (value != null) plPlayerController.toggleVideoFit(value); }))]),
      if (_liveRoomController.isLoaded.value)
        ListTile(leading: const Icon(Icons.alt_route), title: const Text('切换播放线路'),
          onTap: () { Navigator.pop(sheetContext); LiveHeaderControlState.showStream(context, _liveRoomController); }),
      if (Platform.isAndroid || PlatformUtils.isDesktop)
        ListTile(leading: const Icon(Icons.picture_in_picture_outlined), title: const Text('小窗播放'), onTap: () {
          Navigator.pop(sheetContext);
          if (PlatformUtils.isDesktop) { plPlayerController.toggleDesktopPip(); }
          else if (AndroidHelper.isPipAvailable) { plPlayerController.enterPip(); }
          else { SmartDialog.showToast('当前设备暂不支持画中画'); }
        }),
      ListTile(leading: const Icon(Icons.schedule), title: const Text('定时关闭'), onTap: () {
        Navigator.pop(sheetContext); shutdownTimerService.showScheduleExitDialog(context, isFullScreen: isFullScreen, isLive: true);
      }),
      if (PlatformUtils.isDesktop)
        Obx(() => SwitchListTile(title: const Text('窗口置顶'), value: plPlayerController.isAlwaysOnTop.value, onChanged: plPlayerController.setAlwaysOnTop)),
      if (plPlayerController.videoPlayerController case final player?) ...[
        ListTile(leading: const Icon(Icons.info_outline), title: const Text('播放信息'), onTap: () {
          Navigator.pop(sheetContext); HeaderControlState.showPlayerInfo(context, player: player);
        }),
        if (PlatformUtils.isMobile) ListTile(leading: const Icon(Icons.volume_up_outlined), title: const Text('播放器音量'), onTap: () {
          Navigator.pop(sheetContext); showPlayerVolumeDialog(context, () {}, onChanged: player.setVolume);
        }),
      ],
    ]))]),
  ));


  PreferredSizeWidget _buildAppBar(bool isFullScreen) {
    final compactHeader = MediaQuery.sizeOf(context).width < 520;
    return AppBar(
      primary: !plPlayerController.removeSafeArea,
      toolbarHeight: isFullScreen ? 0 : null,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      titleTextStyle: const TextStyle(color: Colors.white),
      title: isFullScreen || plPlayerController.isDesktopPip
          ? null
          : Obx(
              () {
                RoomInfoH5Data? roomInfoH5 =
                    _liveRoomController.roomInfoH5.value;
                if (roomInfoH5 == null) {
                  return const SizedBox.shrink();
                }
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () =>
                      Get.toNamed('/member?mid=${roomInfoH5.roomInfo?.uid}'),
                  child: Row(
                    spacing: 10,
                    mainAxisSize: .min,
                    children: [
                      NetworkImgLayer(
                        width: 34,
                        height: 34,
                        type: .avatar,
                        src: roomInfoH5.anchorInfo!.baseInfo!.face,
                      ),
                      Flexible(
                        child: Column(
                          spacing: 1,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              spacing: 10,
                              mainAxisSize: .min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Flexible(
                                  child: Text(
                                    roomInfoH5.anchorInfo!.baseInfo!.uname!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              spacing: 10,
                              mainAxisSize: .min,
                              children: [
                                Flexible(
                                  child: _liveRoomController.watchedWidget,
                                ),
                                if (!compactHeader)
                                  _liveRoomController.timeWidget,
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      actions: [
        if (!compactHeader)
          IconButton(
            tooltip: '红包与天选',
            onPressed: () => showLiveActivities(
              context,
              _liveRoomController.roomFeatures,
              _liveRoomController.ruid ?? 0,
            ),
            constraints: const BoxConstraints.tightFor(width: 36, height: 40),
            padding: EdgeInsets.zero,
            icon: Obx(
              () => Badge(
                isLabelVisible: _liveRoomController.roomFeatures.activities.any(
                  (a) => a.active(DateTime.now()),
                ),
                child: const Icon(Icons.redeem, size: 20),
              ),
            ),
          ),
        if (!isFullScreen)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: onlineWidget,
          ),
        IconButton(tooltip: '更多', onPressed: _showMore, icon: const Icon(Icons.more_vert, size: 22)),
      ],
    );
  }

  Widget _buildBodyH(bool isFullScreen) {
    double videoWidth =
        clampDouble(maxHeight / maxWidth * 1.08, 0.56, 0.7) * maxWidth;
    final rightWidth = min(400.0, maxWidth - videoWidth - padding.horizontal);
    videoWidth = maxWidth - rightWidth - padding.horizontal;
    final videoHeight = maxHeight - padding.top - kToolbarHeight;
    final width = isFullScreen ? maxWidth : videoWidth;
    final height = isFullScreen
        ? maxHeight - (isWindowMode && !isPortrait ? 0 : padding.top)
        : videoHeight;
    return Padding(
      padding: isFullScreen
          ? EdgeInsets.zero
          : EdgeInsets.only(left: padding.left, right: padding.right),
      child: Row(
        children: [
          Container(
            width: width,
            height: height,
            margin: EdgeInsets.only(bottom: padding.bottom),
            child: videoPlayerPanel(
              isFullScreen,
              fill: Colors.transparent,
              width: width,
              height: height,
            ),
          ),
          Offstage(
            offstage: isFullScreen,
            child: SizedBox(
              width: rightWidth,
              height: videoHeight,
              child: _buildBottomWidget,
            ),
          ),
        ],
      ),
    );
  }

  Widget get _buildBottomWidget => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: _buildChatWidget()),
      _buildInputWidget,
    ],
  );

  Widget _buildChatWidget([bool isPP = false]) {
    Widget chat() => LiveRoomChatPanel(
      key: chatKey,
      isPP: isPP,
      liveRoomController: _liveRoomController,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: isPP ? 0 : 4, top: isPP ? 0 : 4),
      child: _liveRoomController.showSuperChat
          ? PageView(
              key: pageKey,
              controller: _liveRoomController.pageController,
              physics: tabBarScrollPhysics,
              onPageChanged: _liveRoomController.pageIndex.call,
              horizontalDragGestureRecognizer:
                  CustomHorizontalDragGestureRecognizer.new,
              children: [
                KeepAliveWrapper(child: chat()),
                SuperChatPanel(
                  key: scKey,
                  controller: _liveRoomController,
                ),
              ],
            )
          : chat(),
    );
  }

  Widget get _buildInputWidget {
    final child = Padding(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + padding.bottom),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Expanded(
              child: Material(
                color: const Color(0xFF383740),
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  onTap: _liveRoomController.onSendDanmaku,
                  borderRadius: BorderRadius.circular(24),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          '发个弹幕聊聊',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, color: Colors.white70),
                        ),
                      ),
                      IconButton(
                        tooltip: '表情弹幕',
                        constraints: const BoxConstraints.tightFor(
                          width: 44,
                          height: 44,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: () =>
                            _liveRoomController.onSendDanmaku(true),
                        icon: const Icon(
                          Icons.emoji_emotions_outlined,
                          color: Colors.white70,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Builder(
              builder: (context) {
                final isLogin = kDebugMode || _liveRoomController.isLogin;
                return Material(
                  color: const Color(0xFF383740),
                  shape: const CircleBorder(),
                  child: Tooltip(
                    message: '点赞',
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: isLogin ? null : _liveRoomController.toastNotLogin,
                      onTapDown: isLogin
                          ? _liveRoomController.onLikeTapDown
                          : null,
                      onTapUp: isLogin ? _liveRoomController.onLikeTapUp : null,
                      onTapCancel: isLogin
                          ? _liveRoomController.onLikeTapUp
                          : null,
                      child: SizedBox.square(
                        dimension: 44,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(
                              Icons.thumb_up_off_alt,
                              color: Colors.white,
                              size: 22,
                            ),
                            Positioned(
                              top: -12,
                              right: 0,
                              child: Obx(() {
                                final count =
                                    _liveRoomController.likeClickTime.value;
                                return count == 0
                                    ? const SizedBox.shrink()
                                    : Text(
                                        'x$count',
                                        style: const TextStyle(
                                          color: Color(0xFFFB7299),
                                          fontSize: 12,
                                        ),
                                      );
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: '礼物',
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFFB7299),
                foregroundColor: Colors.white,
                fixedSize: const Size(44, 44),
                padding: EdgeInsets.zero,
              ),
              onPressed: () => showLiveGiftPanel(
                context,
                roomId: _liveRoomController.roomId,
                anchorUid: _liveRoomController.ruid,
                anchorName:
                    _liveRoomController
                        .roomInfoH5
                        .value
                        ?.anchorInfo
                        ?.baseInfo
                        ?.uname ??
                    '当前主播',
                areaId: _liveRoomController.roomInfoH5.value?.roomInfo?.areaId,
                parentAreaId: _liveRoomController
                    .roomInfoH5
                    .value
                    ?.roomInfo
                    ?.parentAreaId,
              ),
              icon: const Icon(Icons.card_giftcard_rounded, size: 24),
            ),
          ],
        ),
      ),
    );
    if (_liveRoomController.showSuperChat) {
      return Stack(
        children: [
          child,
          Positioned(
            left: 0,
            top: 0,
            right: 0,
            child: Obx(
              () => _BorderIndicator(
                radius: const Radius.circular(20),
                isLeft: _liveRoomController.pageIndex.value == 0,
              ),
            ),
          ),
        ],
      );
    }
    return child;
  }
}

class _BorderIndicator extends LeafRenderObjectWidget {
  const _BorderIndicator({
    required this.radius,
    required this.isLeft,
  });

  final Radius radius;
  final bool isLeft;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderBorderIndicator(
      radius: radius,
      isLeft: isLeft,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderBorderIndicator renderObject,
  ) {
    renderObject
      ..radius = radius
      ..isLeft = isLeft;
  }
}

class _RenderBorderIndicator extends RenderBox {
  _RenderBorderIndicator({
    required this._radius,
    required this._isLeft,
  });

  Radius _radius;
  Radius get radius => _radius;
  set radius(Radius value) {
    if (_radius == value) return;
    _radius = value;
    markNeedsLayout();
  }

  bool _isLeft;
  bool get isLeft => _isLeft;
  set isLeft(bool value) {
    if (_isLeft == value) return;
    _isLeft = value;
    markNeedsPaint();
  }

  @override
  void performLayout() {
    size = constraints.constrainDimensions(constraints.maxWidth, _radius.x);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final size = this.size;
    final canvas = context.canvas;
    final width = size.width / 2;

    BoxBorder.paintNonUniformBorder(
      canvas,
      Rect.fromLTWH(
        offset.dx + (_isLeft ? 0 : width),
        offset.dy,
        width,
        size.height,
      ),
      borderRadius: BorderRadius.only(
        topLeft: _isLeft ? _radius : .zero,
        topRight: _isLeft ? .zero : _radius,
      ),
      textDirection: null,
      top: const BorderSide(),
      color: Colors.white38,
    );
  }
}

class LiveDanmaku extends StatefulWidget {
  final LiveRoomController liveRoomController;
  final PlPlayerController plPlayerController;
  final bool isPipMode;
  final bool isFullScreen;
  final Size size;

  const LiveDanmaku({
    super.key,
    required this.liveRoomController,
    required this.plPlayerController,
    this.isPipMode = false,
    required this.isFullScreen,
    required this.size,
  });

  @override
  State<LiveDanmaku> createState() => _LiveDanmakuState();

  bool get notFullscreen => !isFullScreen || isPipMode;
}

class _LiveDanmakuState extends State<LiveDanmaku> {
  PlPlayerController get plPlayerController => widget.plPlayerController;

  @override
  void didUpdateWidget(LiveDanmaku oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notFullscreen != widget.notFullscreen &&
        !DanmakuOptions.sameFontScale) {
      plPlayerController.danmakuController?.updateOption(
        DanmakuOptions.get(notFullscreen: widget.notFullscreen),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final option = DanmakuOptions.get(notFullscreen: widget.notFullscreen);
    return Obx(
      () => AnimatedOpacity(
        opacity: plPlayerController.enableShowLiveDanmaku.value
            ? plPlayerController.danmakuOpacity.value
            : 0,
        duration: const Duration(milliseconds: 100),
        child: DanmakuScreen<DanmakuExtra>(
          createdController: (e) {
            widget.liveRoomController.danmakuController =
                plPlayerController.danmakuController = e;
          },
          option: option,
          size: widget.size,
        ),
      ),
    );
  }
}
