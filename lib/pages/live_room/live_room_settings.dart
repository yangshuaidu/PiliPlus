import 'package:PiliPlus/models_new/live/live_danmaku/danmaku_msg.dart';
import 'package:PiliPlus/models_new/live/live_danmaku/live_message_parser.dart';
import 'package:PiliPlus/models_new/live/live_danmaku/live_room_notice.dart';
import 'package:PiliPlus/models_new/live/live_superchat/item.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:get/get.dart';

enum LiveSettingsSection {
  danmaku('弹幕', '弹幕设置'),
  gifts('礼物', '礼物设置'),
  notifications('通知', '通知设置');

  const LiveSettingsSection(this.label, this.title);
  final String label, title;
}

enum LiveRoomOption {
  badges(LiveSettingsSection.danmaku, '显示榜单、等级与头衔'),
  emotes(LiveSettingsSection.danmaku, '显示表情弹幕'),
  cornerEmotes(LiveSettingsSection.danmaku, '显示右下角表情动画'),
  lotteryDanmaku(LiveSettingsSection.danmaku, '显示抽奖弹幕'),
  superChats(LiveSettingsSection.danmaku, '显示醒目留言'),
  giftMessages(LiveSettingsSection.gifts, '显示赠礼消息'),
  guardMessages(LiveSettingsSection.gifts, '大航海开通提示'),
  giftEffects(LiveSettingsSection.gifts, '播放礼物特效'),
  entryNotices(LiveSettingsSection.notifications, '显示进场通知'),
  followNotices(LiveSettingsSection.notifications, '显示关注通知'),
  shareNotices(LiveSettingsSection.notifications, '显示分享通知'),
  globalBroadcasts(LiveSettingsSection.notifications, '全站广播'),
  giftBroadcasts(LiveSettingsSection.notifications, '直播间广播'),
  likeNotices(LiveSettingsSection.notifications, '点赞提示'),
  rankNotices(LiveSettingsSection.notifications, '榜单与排名提示'),
  lotteryNotices(LiveSettingsSection.notifications, '显示红包与天选通知'),
  roomStatusNotices(LiveSettingsSection.notifications, '开播、下播与标题变更'),
  moderationNotices(LiveSettingsSection.notifications, '房间警告与切断提示'),
  roomNotices(LiveSettingsSection.notifications, '其他系统通知');

  const LiveRoomOption(this.section, this.label);
  final LiveSettingsSection section;
  final String label;
}

/// One shared set of local display preferences for all open live rooms.
/// These switches never change account permissions or perform room actions.
class LiveRoomSettings {
  LiveRoomSettings({
    Object? Function(String key)? read,
    Future<void> Function(String key, Object value)? write,
  }) : _read = read ?? ((key) => GStorage.setting.get(key)),
       _write = write ?? ((key, value) => GStorage.setting.put(key, value));

  static final shared = LiveRoomSettings();
  static const storageKey = 'liveRoomSettingsV2';
  final Object? Function(String key) _read;
  final Future<void> Function(String key, Object value) _write;
  final _values = <String, bool>{}.obs;
  final revision = 0.obs;
  final saveError = Rxn<String>();
  Map<String, bool> _saved = {};
  Future<void> _writes = Future<void>.value();
  bool _loaded = false;
  int _edit = 0;

  bool enabled(LiveRoomOption option) => _values[option.name] ?? true;

  void load() {
    if (_loaded) return;
    final defaults = {
      for (final option in LiveRoomOption.values) option.name: true,
    };
    final stored = _read(storageKey);
    if (stored is Map) {
      for (final option in LiveRoomOption.values) {
        final value = stored[option.name];
        if (value is bool) defaults[option.name] = value;
      }
      // New independent switches inherit their old combined switch once, so
      // an upgrade does not bring back categories the user had already hidden.
      for (final (child, parent) in [
        (LiveRoomOption.globalBroadcasts, LiveRoomOption.giftBroadcasts),
        (LiveRoomOption.guardMessages, LiveRoomOption.giftBroadcasts),
        (LiveRoomOption.likeNotices, LiveRoomOption.roomNotices),
        (LiveRoomOption.rankNotices, LiveRoomOption.roomNotices),
        (LiveRoomOption.roomStatusNotices, LiveRoomOption.roomNotices),
        (LiveRoomOption.moderationNotices, LiveRoomOption.roomNotices),
      ]) {
        if (stored[child.name] is! bool) defaults[child.name] = defaults[parent.name]!;
      }
    } else {
      // Preserve the effective behavior of the old combined blocking switches.
      final legacy = _read('liveMessageFiltersV1');
      if (legacy is List) {
        void hide(String oldName, List<LiveRoomOption> options) {
          if (legacy.contains(oldName)) {
            for (final option in options) {
              defaults[option.name] = false;
            }
          }
        }

        hide('gifts', [
          LiveRoomOption.giftMessages,
          LiveRoomOption.giftBroadcasts,
          LiveRoomOption.globalBroadcasts,
          LiveRoomOption.guardMessages,
          LiveRoomOption.giftEffects,
        ]);
        hide('giftEffects', [LiveRoomOption.giftEffects]);
        hide('lottery', [
          LiveRoomOption.lotteryDanmaku,
          LiveRoomOption.lotteryNotices,
        ]);
        hide('entry', [LiveRoomOption.entryNotices]);
        hide('superChat', [LiveRoomOption.superChats]);
        hide('cornerEmotes', [LiveRoomOption.cornerEmotes]);
        hide('emotes', [LiveRoomOption.emotes, LiveRoomOption.cornerEmotes]);
      }
    }
    _saved = Map.of(defaults);
    _values.assignAll(defaults);
    _loaded = true;
    revision.value++;
  }

  Future<bool> set(LiveRoomOption option, bool value) =>
      _persist({option.name: value});

  Future<bool> reset(LiveSettingsSection section) => _persist({
    for (final option in LiveRoomOption.values)
      if (option.section == section) option.name: true,
  });

  Future<bool> _persist(Map<String, bool> updates) {
    load();
    final snapshot = {..._values, ...updates};
    final edit = ++_edit;
    _values.assignAll(snapshot);
    saveError.value = null;
    revision.value++;
    // Serialize rapid changes so a slower earlier save cannot win after restart.
    final operation = _writes.then((_) async {
      try {
        await _write(storageKey, snapshot);
        _saved = Map.of(snapshot);
        if (edit == _edit) saveError.value = null;
        return true;
      } catch (_) {
        if (edit == _edit) {
          _values.assignAll(_saved);
          revision.value++;
          saveError.value = '设置未保存，已恢复上次保存的选项，请重试。';
        }
        return false;
      }
    });
    _writes = operation.then((_) {});
    return operation;
  }

  /// Applied both when receiving a message and when rebuilding existing chat.
  bool allows(Object? message, {bool activityDanmaku = false}) {
    if (message is LiveGiftMessage) return enabled(message.guardPurchase
        ? LiveRoomOption.guardMessages : LiveRoomOption.giftMessages);
    if (message is SuperChatItem) return enabled(LiveRoomOption.superChats);
    if (message is LiveRoomNotice) {
      if (message.entry) return enabled(LiveRoomOption.entryNotices);
      if (message.follow) return enabled(LiveRoomOption.followNotices);
      if (message.share) return enabled(LiveRoomOption.shareNotices);
      if (message.kind case final kind?) {
        return enabled(switch (kind) {
          LiveNoticeKind.guard => LiveRoomOption.guardMessages,
          LiveNoticeKind.globalBroadcast => LiveRoomOption.globalBroadcasts,
          LiveNoticeKind.roomBroadcast => LiveRoomOption.giftBroadcasts,
          LiveNoticeKind.like => LiveRoomOption.likeNotices,
          LiveNoticeKind.rank => LiveRoomOption.rankNotices,
          LiveNoticeKind.roomStatus => LiveRoomOption.roomStatusNotices,
          LiveNoticeKind.moderation => LiveRoomOption.moderationNotices,
          LiveNoticeKind.system => LiveRoomOption.roomNotices,
        });
      }
      if (message.broadcast) return enabled(LiveRoomOption.giftBroadcasts);
      if (message.lottery) return enabled(LiveRoomOption.lotteryNotices);
      return enabled(LiveRoomOption.roomNotices);
    }
    if (message is DanmakuMsg) {
      if (!enabled(LiveRoomOption.emotes) &&
          (message.uemote != null || message.emots?.isNotEmpty == true)) {
        return false;
      }
      if (!enabled(LiveRoomOption.lotteryDanmaku) &&
          (message.lottery || activityDanmaku)) {
        return false;
      }
    }
    return true;
  }
}
