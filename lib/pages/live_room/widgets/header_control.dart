import 'dart:math' as math;

import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/draggable_sheet/dyn.dart';
import 'package:PiliPlus/common/widgets/marquee.dart';
import 'package:PiliPlus/models/common/video/live_quality.dart';
import 'package:PiliPlus/pages/live_room/controller.dart';
import 'package:PiliPlus/pages/video/widgets/header_control.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/utils/extension/context_ext.dart';
import 'package:PiliPlus/utils/extension/size_ext.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:collection/collection.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class LiveHeaderControl extends StatefulWidget {
  const LiveHeaderControl({
    super.key,
    required this.title,
    required this.upName,
    required this.plPlayerController,
    required this.onSendDanmaku,
    required this.onPlayAudio,
    required this.isPortrait,
    required this.liveController,
    required this.onlineWidget,
    required this.onMore,
  });

  final String? title;
  final String? upName;
  final PlPlayerController plPlayerController;
  final VoidCallback onSendDanmaku;
  final VoidCallback onPlayAudio;
  final bool isPortrait;
  final LiveRoomController liveController;
  final Widget onlineWidget;
  final VoidCallback onMore;

  @override
  State<LiveHeaderControl> createState() => LiveHeaderControlState();
}

class LiveHeaderControlState extends State<LiveHeaderControl>
    with TimeBatteryMixin {
  @override
  late final plPlayerController = widget.plPlayerController;

  @override
  bool get horizontalScreen => true;

  @override
  bool get isFullScreen => plPlayerController.isFullScreen.value;

  @override
  bool get isPortrait => widget.isPortrait;

  @override
  Widget build(BuildContext context) {
    final isFullScreen = this.isFullScreen;
    showCurrTimeIfNeeded(isFullScreen);
    final liveController = widget.liveController;
    Widget child;
    child = Obx(
      key: titleKey,
      () => MarqueeText(
        liveController.title.value,
        spacing: 30,
        velocity: 30,
        strutStyle: const StrutStyle(fontSize: 15, leading: 0),
        style: const TextStyle(fontSize: 15, height: 1, color: Colors.white),
      ),
    );
    if (isFullScreen) {
      child = Column(
        spacing: 5,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          child,
          Row(
            spacing: 10,
            children: [
              if (widget.upName case final upName?)
                Text(
                  upName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              liveController.watchedWidget,
              widget.onlineWidget,
              liveController.timeWidget,
            ],
          ),
        ],
      );
    }
    child = Expanded(child: child);

    if (!isFullScreen && !plPlayerController.isDesktopPip)
      return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            tooltip: '返回',
            onPressed: () {
              if (plPlayerController.isDesktopPip) {
                plPlayerController.exitDesktopPip();
              } else {
                plPlayerController.triggerFullScreen(status: false);
              }
            },
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
          ),
          child,
          ...?timeBatteryWidgets,
          IconButton(
            tooltip: '更多',
            onPressed: widget.onMore,
            icon: const Icon(Icons.more_horiz, color: Colors.white),
          ),
        ],
      ),
    );
  }

  static void showStream(BuildContext context, LiveRoomController controller) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxWidth: math.min(640, context.mediaQueryShortestSide),
      ),
      builder: (context) {
        final maxChildSize =
            PlatformUtils.isMobile && !context.mediaQuerySize.isPortrait
            ? 1.0
            : 0.7;
        return DynDraggableScrollableSheet(
          minChildSize: 0,
          maxChildSize: maxChildSize,
          snap: true,
          expand: false,
          snapSizes: [maxChildSize],
          initialChildSize: maxChildSize,
          builder: (context, scrollController) {
            final colorScheme = ColorScheme.of(context);
            final secondary = colorScheme.secondary;
            final onSurfaceVariant = colorScheme.onSurfaceVariant;
            final currStyle = TextStyle(fontSize: 14, color: secondary);
            return Column(
              children: [
                InkWell(
                  onTap: Get.back,
                  borderRadius: Style.bottomSheetRadius,
                  child: SizedBox(
                    height: 35,
                    child: Center(
                      child: Container(
                        width: 32,
                        height: 3,
                        decoration: BoxDecoration(
                          color: colorScheme.outline,
                          borderRadius: const .all(.circular(1.5)),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: .only(
                      bottom: MediaQuery.viewPaddingOf(context).bottom + 100,
                    ),
                    children: controller.stream.mapIndexed((si, stream) {
                      final isCurrStream = si == controller.streamIndex;
                      final streamColor = isCurrStream
                          ? secondary
                          : onSurfaceVariant;
                      return _ExpansionTile(
                        initiallyExpanded: isCurrStream,
                        iconColor: streamColor,
                        collapsedIconColor: streamColor,
                        title: Text(
                          stream.protocolName ?? si.toString(),
                          style: isCurrStream
                              ? currStyle
                              : const TextStyle(fontSize: 14),
                        ),
                        children: stream.format.mapIndexed((fi, format) {
                          final isCurrFormat =
                              isCurrStream && fi == controller.formatIndex;
                          final formatColor = isCurrFormat
                              ? secondary
                              : onSurfaceVariant;
                          return _ExpansionTile(
                            initiallyExpanded: isCurrFormat,
                            iconColor: formatColor,
                            collapsedIconColor: formatColor,
                            title: Text(
                              format.formatName ?? fi.toString(),
                              style: isCurrFormat
                                  ? currStyle
                                  : const TextStyle(fontSize: 14),
                            ),
                            children: format.codec.mapIndexed((ci, codec) {
                              final isCurrCodec =
                                  isCurrFormat && ci == controller.codecIndex;
                              final codecColor = isCurrCodec
                                  ? secondary
                                  : onSurfaceVariant;
                              return _ExpansionTile(
                                initiallyExpanded: isCurrCodec,
                                iconColor: codecColor,
                                collapsedIconColor: codecColor,
                                title: Text(
                                  '${codec.codecName ?? ci.toString()} (${LiveQuality.fromCode(codec.currentQn)?.desc ?? codec.currentQn})',
                                  style: isCurrCodec
                                      ? currStyle
                                      : const TextStyle(fontSize: 14),
                                ),
                                children: codec.urlInfo.mapIndexed((ui, url) {
                                  final isCurrUrl =
                                      isCurrCodec &&
                                      ui == controller.liveUrlIndex;
                                  return ListTile(
                                    dense: true,
                                    title: Text(
                                      '${url.host}...',
                                      style: isCurrUrl
                                          ? const TextStyle(fontSize: 14)
                                          : TextStyle(
                                              fontSize: 14,
                                              color: onSurfaceVariant,
                                            ),
                                    ),
                                    selected: isCurrUrl,
                                    onTap: isCurrUrl
                                        ? null
                                        : () {
                                            Get.back();
                                            controller.initLiveUrl(
                                              streamIndex: si,
                                              formatIndex: fi,
                                              codecIndex: ci,
                                              liveUrlIndex: ui,
                                            );
                                            GStorage.setting.put(
                                              SettingBoxKey.liveStream,
                                              [
                                                stream.protocolName!,
                                                format.formatName!,
                                                codec.codecName!,
                                              ],
                                            );
                                          },
                                  );
                                }).toList(),
                              );
                            }).toList(),
                          );
                        }).toList(),
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ExpansionTile extends ExpansionTile {
  const _ExpansionTile({
    required super.title,
    super.initiallyExpanded,
    super.iconColor,
    super.collapsedIconColor,
    super.children,
  }) : super(
         dense: true,
         childrenPadding: const .only(left: 20),
       );
}
