import 'package:PiliPlus/pages/live_room/widgets/live_user_panel.dart';
import 'package:PiliPlus/common/widgets/badge.dart';
import 'package:PiliPlus/common/widgets/flutter/live_list_view.dart';
import 'package:PiliPlus/common/widgets/gesture/tap_gesture_recognizer.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/scroll_physics.dart'
    show platformClampingPhysics;
import 'package:PiliPlus/models_new/live/live_danmaku/danmaku_msg.dart';
import 'package:PiliPlus/models_new/live/live_danmaku/live_message_parser.dart';
import 'package:PiliPlus/models_new/live/live_danmaku/live_room_notice.dart';
import 'package:PiliPlus/pages/live_room/widgets/message_badges.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/pages/live_room/live_message_session.dart';
import 'package:PiliPlus/models_new/live/live_superchat/item.dart';
import 'package:PiliPlus/pages/live_room/controller.dart';
import 'package:PiliPlus/pages/live_room/live_room_settings.dart';
import 'package:PiliPlus/pages/live_room/superchat/superchat_card.dart';
import 'package:PiliPlus/pages/member/widget/medal_widget.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class LiveRoomChatPanel extends StatelessWidget {
  const LiveRoomChatPanel({
    super.key,
    required this.liveRoomController,
    required this.isPP,
  });

  final LiveRoomController liveRoomController;
  final bool isPP;

  bool get disableAutoScroll => liveRoomController.disableAutoScroll.value;

  @override
  Widget build(BuildContext context) {
    late final bg = isPP
        ? Colors.black.withValues(alpha: 0.36)
        : Colors.transparent;
    late final nameColor = isPP
        ? Colors.white.withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.6);
    late final colorScheme = ColorScheme.of(context);
    late final primary = colorScheme.isDark
        ? colorScheme.primary
        : colorScheme.inversePrimary;
    return Stack(
      children: [
        Obx(
          () {
            liveRoomController.settings.revision.value;
            final showBadges = liveRoomController.settings.enabled(
              LiveRoomOption.badges,
            );
            return LiveListView.separated(
              key: const PageStorageKey(LiveRoomChatPanel),
              // multiply by 2 to account for separators
              initialIndex: liveRoomController.trimDmIndex * 2,
              padding: const .symmetric(horizontal: 12),
              controller: liveRoomController.scrollController,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemCount: liveRoomController.builtLength =
                  liveRoomController.messages.length,
              physics: platformClampingPhysics,
              itemBuilder: (_, index) {
                liveRoomController.chatSimpleIndex = index;
                final item = liveRoomController.messages[index];
                if (!liveRoomController.messageVisible(item))
                  return const SizedBox.shrink();
                if (item is LiveRoomNotice) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withValues(alpha: .24),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            if (showBadges) ...liveBadgeSpans(item.badges),
                            if (item.name.isNotEmpty &&
                                !item.text.contains(item.name))
                              TextSpan(
                                text:
                                    '${item.uid > 0 && item.uid == Accounts.main.mid ? '我' : item.name} ',
                                style: const TextStyle(
                                  color: Colors.lightBlueAccent,
                                ),
                              ),
                            TextSpan(
                              text: item.text,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                if (item is LiveGiftMessage) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            if (showBadges) ...liveBadgeSpans(item.badges),
                            const WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Icon(
                                Icons.card_giftcard,
                                size: 16,
                                color: Colors.amber,
                              ),
                            ),
                            TextSpan(
                              text:
                                  ' ${item.uid > 0 && item.uid == Accounts.main.mid ? '我 · ${item.name}' : item.name} ',
                              style: const TextStyle(color: Colors.amber),
                              recognizer: item.uid <= 0
                                  ? null
                                  : (NoDeadlineTapGestureRecognizer()
                                      ..onTap = () => Get.toNamed(
                                        '/member?mid=${item.uid}',
                                      )),
                            ),
                            TextSpan(
                              text:
                                  '${item.action} ${item.giftName} × ${item.quantity}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                if (item is DanmakuMsg) {
                  WidgetSpan? medal;
                  if (showBadges &&
                      item.badges.medalName.isEmpty &&
                      item.medalInfo != null) {
                    final medalInfo = item.medalInfo!;
                    try {
                      medal = WidgetSpan(
                        child: Padding(
                          padding: const .only(right: 4),
                          child: MedalWidget.fromMedalInfo(
                            medal: medalInfo,
                            padding: MedalWidget.mediumPadding,
                          ),
                        ),
                      );
                    } catch (e, s) {
                      if (kDebugMode) {
                        Utils.reportError(e, s);
                      }
                    }
                  }
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Builder(
                      builder: (itemContext) {
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _openMessage(context, item),
                          child: Container(
                          constraints: const BoxConstraints(minHeight: 40),
                          padding: const .symmetric(
                            horizontal: isPP ? 8 : 0,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: const .all(.circular(14)),
                          ),
                          child: Text.rich(
                            style: const TextStyle(fontSize: 15, height: 1.4, color: Colors.white),
                            TextSpan(
                              children: [
                                if (showBadges) ...liveBadgeSpans(item.badges, onTap: () => _openMessage(context, item, profile: true)),
                                if (item.extra.mid == liveRoomController.ruid)
                                  const WidgetSpan(
                                    child: Padding(
                                      padding: .only(right: 4),
                                      child: PBadge(
                                        text: '主播',
                                        isStack: false,
                                        type: .line_primary,
                                      ),
                                    ),
                                  ),
                                ?medal,
                                TextSpan(
                                  text: '${item.name}: ',
                                  style: TextStyle(
                                    color:
                                        liveNameColor(item.badges.nameColor) ??
                                        nameColor,
                                    fontSize: 15,
                                  ),
                                  recognizer: item.extra.mid == 0
                                      ? null
                                      : (NoDeadlineTapGestureRecognizer()
                                          ..onTap = () => _openMessage(context, item, profile: true)),
                                ),
                                if (item.reply case final reply?)
                                  TextSpan(
                                    text: '@${reply.name} ',
                                    style: TextStyle(
                                      color: primary,
                                      fontSize: 15,
                                    ),
                                    recognizer: (reply.mid ?? 0) <= 0
                                        ? null
                                        : (NoDeadlineTapGestureRecognizer()
                                            ..onTap = () => Get.toNamed(
                                              '/member?mid=${reply.mid}',
                                            )),
                                  ),
                                _buildMsg(item),
                              ],
                            ),
                          ),
                        ));
                      },
                    ),
                  );
                }
                if (item is SuperChatItem) {
                  return SuperChatCard(
                    item: item,
                    persistentSC: true,
                    onReport: () => liveRoomController.reportSC(item),
                  );
                }
                return null;
              },
            );
          },
        ),
        Obx(() {
          final state = liveRoomController.messageConnectionState.value;
          if (state == LiveMessageConnectionState.connected ||
              state == LiveMessageConnectionState.suspended) {
            return const SizedBox.shrink();
          }
          return Positioned(
            left: 12,
            bottom: 42,
            child: Material(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
              child: TextButton.icon(
                onPressed: state == LiveMessageConnectionState.stopped
                    ? liveRoomController.retryLiveMessages
                    : null,
                icon: const Icon(Icons.sync, size: 16, color: Colors.amber),
                label: Text(
                  state.label,
                  style: const TextStyle(color: Colors.amber),
                ),
              ),
            ),
          );
        }),
        Obx(() {
          liveRoomController.deliveryRevision.value;
          final entries = liveRoomController.deliveryTracker.entries;
          if (entries.isEmpty) return const SizedBox.shrink();
          return Positioned(
            left: 12,
            right: 12,
            top: 0,
            child: Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('弹幕发送检测'),
                      content: SizedBox(
                        width: 440,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '回显表示本客户端收到自己的弹幕，不能证明其他观众均可见。未回显也不能单独证明被屏蔽。仅检测本次进入直播间后的发送。',
                              ),
                              const SizedBox(height: 12),
                              for (final entry in entries)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text('${entry.text}\n${entry.label}'),
                                ),
                            ],
                          ),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('关闭'),
                        ),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      entries.first.label,
                      maxLines: 2,
                      style: const TextStyle(color: Colors.amber, fontSize: 11),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
        if (kDebugMode && liveRoomController.showSuperChat) ...[
          Positioned(
            top: 50,
            right: 0,
            child: TextButton(
              onPressed: () {
                final item = SuperChatItem.random;
                liveRoomController
                  ..superChatMsg.insert(0, item)
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
                if (liveRoomController.superChatMsg.isNotEmpty) {
                  liveRoomController.superChatMsg.removeLast();
                }
              },
              child: const Text('remove superchat'),
            ),
          ),
        ],
        if (liveRoomController.showSuperChat)
          Positioned(
            top: 12,
            right: 12,
            child: Obx(() {
              final isEmpty = liveRoomController.superChatMsg.isEmpty;
              return AnimatedOpacity(
                opacity: isEmpty ? 0 : 1,
                duration: const Duration(milliseconds: 120),
                child: GestureDetector(
                  onTap: isEmpty
                      ? null
                      : () => liveRoomController.pageController?.animateToPage(
                          1,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                        ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                      color: const Color(0x2FFFFFFF),
                      border: Border.all(color: Colors.white24, width: 0.7),
                    ),
                    padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
                    child: Text.rich(
                      style: const TextStyle(color: Colors.white, height: 1),
                      strutStyle: const StrutStyle(height: 1, leading: 0),
                      TextSpan(
                        children: [
                          TextSpan(
                            text:
                                'SC(${liveRoomController.superChatMsg.length})',
                          ),
                          const WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Icon(
                              size: 18,
                              Icons.keyboard_arrow_right,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        Obx(
          () => liveRoomController.disableAutoScroll.value
              ? Positioned(
                  right: 12,
                  bottom: 0,
                  child: ElevatedButton.icon(
                    style: const ButtonStyle(visualDensity: .comfortable),
                    icon: const Icon(Icons.arrow_downward_rounded, size: 20),
                    label: const Text('回到底部'),
                    onPressed: liveRoomController.handleJumpToBottom,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  InlineSpan _buildMsg(DanmakuMsg obj) {
    final uemote = obj.uemote;
    if (uemote != null) {
      // "room_{{room_id}}_{{int}}" , "upower_[{{emote}}]" , "official_{{int}}"
      final height = uemote.isOfficial ? 32.0 : 48.0;
      final ratio = uemote.height > 0 ? uemote.width / uemote.height : 1.0;
      final width = (height * ratio).clamp(24.0, 128.0).toDouble();
      return WidgetSpan(
        child: NetworkImgLayer(
          src: uemote.url,
          type: .emote,
          width: width,
          height: height,
        ),
      );
    }
    final emots = obj.emots;
    if (emots != null) {
      RegExp regExp = RegExp(emots.keys.map(RegExp.escape).join('|'));
      final List<InlineSpan> spanChildren = <InlineSpan>[];
      obj.text.splitMapJoin(
        regExp,
        onMatch: (match) {
          final key = match[0]!;
          final emote = emots[key]!;
          spanChildren.add(
            WidgetSpan(
              child: NetworkImgLayer(
                src: emote.url,
                type: .emote,
                width: emote.height > 0 ? (28.0 * emote.width / emote.height).clamp(16.0, 84.0).toDouble() : 28,
                height: 28,
              ),
            ),
          );
          return '';
        },
        onNonMatch: (String nonMatchStr) {
          spanChildren.add(
            TextSpan(
              text: nonMatchStr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
              ),
            ),
          );
          return '';
        },
      );
      return TextSpan(children: spanChildren);
    } else {
      return TextSpan(
        text: obj.text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
        ),
      );
    }
  }

  Future<void> _openMessage(BuildContext context, DanmakuMsg item, {bool profile = false}) async {
    final autoScroll = liveRoomController.autoScroll && !liveRoomController.disableAutoScroll.value;
    if (autoScroll) liveRoomController.autoScroll = false;
    try {
      if (profile) { await showLiveUserPanel(context, liveRoomController, item); }
      else { await showLiveMessageActions(context, liveRoomController, item); }
    } finally {
      if (autoScroll && context.mounted) { liveRoomController..autoScroll = true..scrollToBottom(); }
    }
  }
}
