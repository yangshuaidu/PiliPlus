import 'package:PiliPlus/pages/live_room/live_room_settings.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class LiveSettingsPanel extends StatefulWidget {
  const LiveSettingsPanel({
    super.key,
    required this.settings,
    this.initialSection = LiveSettingsSection.danmaku,
    this.danmakuVisibility,
    required this.onDisplaySettings,
    required this.onBlockRules,
  });

  final LiveRoomSettings settings;
  final LiveSettingsSection initialSection;
  final Widget? danmakuVisibility;
  final VoidCallback onDisplaySettings, onBlockRules;

  @override
  State<LiveSettingsPanel> createState() => _LiveSettingsPanelState();
}

class _LiveSettingsPanelState extends State<LiveSettingsPanel> {
  late LiveSettingsSection _section = widget.initialSection;

  @override
  void initState() {
    super.initState();
    widget.settings.load();
  }

  String? _description(LiveRoomOption option) => switch (option) {
    LiveRoomOption.cornerEmotes => '需同时开启表情弹幕',
    LiveRoomOption.superChats => '控制已接收留言的展示，不影响订单与购买记录',
    LiveRoomOption.giftMessages => '聊天区中的赠礼记录，与特效开关独立',
    LiveRoomOption.giftBroadcasts => '直播广播和开通大航海的提示',
    LiveRoomOption.giftEffects => 'GIF / WebP 动画；当前版本没有礼物音效',
    LiveRoomOption.lotteryNotices => '活动开始、开奖与结果提示，不影响手动查看活动',
    LiveRoomOption.roomNotices => '开播、下播、标题变更等直播间内提示',
    _ => null,
  };

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _section.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭设置',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final section in LiveSettingsSection.values)
                    ChoiceChip(
                      label: Text(section.label),
                      selected: _section == section,
                      onSelected: (_) => setState(() => _section = section),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('分类设置自动保存，适用于本机所有直播间。'),
              if (_section == LiveSettingsSection.notifications) ...[
                const SizedBox(height: 8),
                const Text('这些选项控制直播间内的消息，不是手机或桌面推送。'),
              ],
              if (_section == LiveSettingsSection.danmaku) ...[
                ?widget.danmakuVisibility,
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('字体、透明度与显示区域'),
                  subtitle: const Text('含速度、描边及弹幕类型；与播放器共用'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: widget.onDisplaySettings,
                ),
              ],
              const Divider(),
              Obx(
                () => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final option in LiveRoomOption.values)
                      if (option.section == _section)
                        SwitchListTile(
                          key: ValueKey(option.name),
                          contentPadding: EdgeInsets.zero,
                          title: Text(option.label),
                          subtitle: _description(option) == null
                              ? null
                              : Text(_description(option)!),
                          value: widget.settings.enabled(option),
                          onChanged: (value) =>
                              widget.settings.set(option, value),
                        ),
                    if (widget.settings.saveError.value case final error?)
                      Text(
                        error,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
              if (_section == LiveSettingsSection.danmaku)
                TextButton.icon(
                  onPressed: widget.onBlockRules,
                  icon: const Icon(Icons.block),
                  label: const Text('管理屏蔽词与用户'),
                ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => widget.settings.reset(_section),
                icon: const Icon(Icons.restore),
                label: const Text('恢复本页分类默认值'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
