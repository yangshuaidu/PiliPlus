import 'package:PiliPlus/pages/live_room/live_room_settings.dart';
import 'package:PiliPlus/pages/live_room/widgets/live_panel_surface.dart';
import 'package:flutter/cupertino.dart' show CupertinoSlidingSegmentedControl;
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class LiveSettingsPanel extends StatefulWidget {
  const LiveSettingsPanel({
    super.key,
    required this.settings,
    this.initialSection = LiveSettingsSection.danmaku,
    this.danmakuVisibility,
    this.superChatAvailable = true,
    required this.onDisplaySettings,
    required this.onBlockRules,
  });
  final LiveRoomSettings settings;
  final LiveSettingsSection initialSection;
  final Widget? danmakuVisibility;
  final bool superChatAvailable;
  final VoidCallback onDisplaySettings, onBlockRules;

  @override
  State<LiveSettingsPanel> createState() => _LiveSettingsPanelState();
}

class _LiveSettingsPanelState extends State<LiveSettingsPanel> {
  late LiveSettingsSection _section = widget.initialSection;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.settings.load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String? _description(LiveRoomOption option) => switch (option) {
    LiveRoomOption.cornerEmotes => '需同时开启表情弹幕',
    LiveRoomOption.superChats =>
      widget.superChatAvailable ? null : '播放器设置已将醒目留言设为“不显示”，更改后重新进入直播间生效',
    LiveRoomOption.globalBroadcasts => '其他直播间的礼物、活动等全站消息',
    LiveRoomOption.giftBroadcasts => '当前直播间的公告与广播',
    LiveRoomOption.guardMessages => '开通、续费大航海的聊天提示',
    LiveRoomOption.giftEffects => '与聊天区赠礼消息分别控制',
    LiveRoomOption.lotteryNotices => '不影响手动查看或参与活动',
    LiveRoomOption.moderationNotices => '仅隐藏提示，不改变房间或播放状态',
    _ => null,
  };

  @override
  Widget build(BuildContext context) => LivePanelSurface(
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _section.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: '关闭设置',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<LiveSettingsSection>(
              groupValue: _section,
              backgroundColor: const Color(0xFF121218),
              thumbColor: const Color(0xFF41404A),
              onValueChanged: (value) {
                if (value == null) return;
                setState(() => _section = value);
                if (_scroll.hasClients) _scroll.jumpTo(0);
              },
              children: {
                for (final section in LiveSettingsSection.values)
                  section: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      section.label,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.25,
                        color: Colors.white,
                      ),
                    ),
                  ),
              },
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_section == LiveSettingsSection.danmaku) ...[
                ?widget.danmakuVisibility,
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: const Text(
                    '字体、透明度与显示区域',
                    style: TextStyle(fontSize: 14, height: 1.4),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: widget.onDisplaySettings,
                ),
              ],
              Obx(
                () => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final option in LiveRoomOption.values)
                      if (option.section == _section)
                        SwitchListTile.adaptive(
                          key: ValueKey(option.name),
                          controlAffinity: ListTileControlAffinity.trailing,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          title: Text(
                            option.label,
                            style: const TextStyle(fontSize: 14, height: 1.4),
                          ),
                          subtitle: _description(option) == null
                              ? null
                              : Text(
                                  _description(option)!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: Colors.white54,
                                  ),
                                ),
                          value:
                              option == LiveRoomOption.superChats &&
                                  !widget.superChatAvailable
                              ? false
                              : widget.settings.enabled(option),
                          onChanged:
                              option == LiveRoomOption.superChats &&
                                  !widget.superChatAvailable
                              ? null
                              : (value) => widget.settings.set(option, value),
                        ),
                    if (widget.settings.saveError.value case final error?)
                      Text(
                        error,
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          height: 1.4,
                        ),
                      ),
                  ],
                ),
              ),
              if (_section == LiveSettingsSection.danmaku)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: const Text(
                    '管理屏蔽词与用户',
                    style: TextStyle(fontSize: 14, height: 1.4),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: widget.onBlockRules,
                ),
              const Divider(),
              TextButton(
                onPressed: () => widget.settings.reset(_section),
                child: const Text('恢复本页分类默认值'),
              ),
              const Text(
                '自动保存 · 适用于所有直播间',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: Colors.white38,
                ),
              ),
            ],
            ),
          ),
        ),
      ],
    ),
  );
}
