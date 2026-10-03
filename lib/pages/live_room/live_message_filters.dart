import 'package:PiliPlus/utils/storage.dart';
import 'package:get/get.dart';

enum LiveMessageFilter {
  gifts('屏蔽全部礼物及广播'),
  giftEffects('屏蔽礼物声音与特效'),
  lottery('屏蔽抽奖弹幕'),
  entry('屏蔽进场信息'),
  superChat('屏蔽醒目留言'),
  cornerEmotes('屏蔽右下角表情动画'),
  emotes('屏蔽表情弹幕');

  const LiveMessageFilter(this.label);
  final String label;
}

/// Local display preferences; no account or room setting is changed remotely.
class LiveMessageFilters {
  final blocked = <String>{}.obs;
  bool hides(LiveMessageFilter filter) => blocked.contains(filter.name);
  void load() {
    final saved = GStorage.setting.get('liveMessageFiltersV1');
    if (saved is List) blocked.addAll(saved.whereType<String>());
  }

  Future<void> set(LiveMessageFilter filter, bool value) async {
    value ? blocked.add(filter.name) : blocked.remove(filter.name);
    await GStorage.setting.put('liveMessageFiltersV1', blocked.toList());
  }
}
