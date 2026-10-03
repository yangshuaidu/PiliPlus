import 'dart:convert';

import 'package:PiliPlus/models_new/live/gift/live_gift.dart';
import 'package:PiliPlus/models_new/live/live_danmaku/live_user_badges.dart';

class LiveScTier {
  LiveScTier(this.data);
  final Map<String, dynamic> data;
  int get id => liveInt(data['id']) ?? 0;
  int get level => liveInt(data['level']) ?? 0;
  // Official price_configs.price is multiplied by 1000 for pay_gold.
  int get gold => (liveInt(data['price']) ?? 0) * 1000;
  int get seconds => liveInt(data['second']) ?? 0;
  int get limit => liveInt(data['limit']) ?? 0;
  bool get enabled =>
      data['type_detail'] is! Map ||
      liveBool(liveMap(data['type_detail'])['can_buy']) == true;
  String get badge => '${liveMap(data['type_detail'])['button_text'] ?? ''}';
  String get description => '${liveMap(data['type_detail'])['desc'] ?? ''}';
  String get fingerprint => jsonEncode([
    id,
    level,
    gold,
    seconds,
    limit,
    enabled,
    badge,
    description,
  ]);
}

class LiveScConfig {
  LiveScConfig(this.data)
    : tiers =
          liveMaps(data['price_configs'])
              .map(LiveScTier.new)
              .where(
                (t) => t.id > 0 && t.gold > 0 && t.limit > 0 && t.seconds > 0,
              )
              .toList()
            ..sort((a, b) => a.gold.compareTo(b.gold));
  final Map<String, dynamic> data;
  final List<LiveScTier> tiers;
  int get goodsId => liveInt(data['goods_id']) ?? 12;
  bool get customPrice =>
      data['custom_gold'] != false && data['custom_gold'] != 0;
  bool get translation => liveInt(data['trans_status']) == 1;
  bool get customAnimation =>
      liveInt(liveMap(data['customize_dm'])['switch']) == 1;
  int get animationGold =>
      liveInt(liveMap(data['customize_dm'])['amount']) ?? 0;
  String get notice => '${data['msg'] ?? ''}';
  String get banReason {
    final ban = liveMap(data['user_ban_info']);
    if (liveBool(ban['limited']) != true) return '';
    final tip = '${ban['limited_tip'] ?? ''}';
    return tip.isNotEmpty ? tip : '当前账号暂时无法购买醒目留言';
  }

  LiveScTier? tierForGold(int gold) =>
      tiers.where((t) => gold >= t.gold).lastOrNull;
}

class LiveScImage {
  const LiveScImage(this.id, this.url);
  final int id;
  final String url;
  static List<LiveScImage> parse(Map<String, dynamic> data) => [
    for (final item in liveMaps(data['list']))
      if (liveInt(item['id']) case final id? when id > 0)
        if (liveAssetUrl(item['origin_url']) case final url when url.isNotEmpty)
          LiveScImage(id, url),
  ];
}

class LiveScSelection {
  const LiveScSelection({
    required this.tier,
    required this.message,
    required this.gold,
    required this.goodsId,
    this.translationKey = '',
    this.translatedText = '',
    this.imageId = 0,
    this.imageGold = 0,
  });
  final LiveScTier tier;
  final String message, translationKey, translatedText;
  final int gold, goodsId, imageId, imageGold;
  int get totalGold => gold + imageGold;
}

class LiveScConfirmation {
  const LiveScConfirmation(
    this.selection,
    this.uid,
    this.identity,
    this.operationId,
    this.expiresAt,
  );
  final LiveScSelection selection;
  final int uid;
  final Object identity;
  final String operationId;
  final DateTime expiresAt;
}
