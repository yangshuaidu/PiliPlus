import 'dart:convert';

import 'package:PiliPlus/models/model_owner.dart';
import 'package:PiliPlus/models_new/live/live_danmaku/danmaku_msg.dart';
import 'package:PiliPlus/models_new/live/live_danmaku/live_emote.dart';
import 'package:PiliPlus/models_new/live/live_medal_wall/uinfo_medal.dart';
import 'package:PiliPlus/pages/danmaku/danmaku_model.dart';
import 'package:PiliPlus/models_new/live/live_danmaku/live_gift_broadcast.dart';
import 'package:PiliPlus/models_new/live/live_danmaku/live_wire_decoder.dart';
import 'package:PiliPlus/models_new/live/live_danmaku/live_user_badges.dart';

/// Optional decoration failures must not discard a readable chat message.
class LiveMessageParser {
  static int integer(dynamic value, [int fallback = 0]) =>
      value is int ? value : int.tryParse('$value') ?? fallback;
  static Map<String, dynamic> map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : {};
  static dynamic at(dynamic value, int index) =>
      value is List && index < value.length ? value[index] : null;
  static Map<String, dynamic> extra(dynamic value) {
    if (value is String) {
      try {
        return map(jsonDecode(value));
      } catch (_) {
        return {};
      }
    }
    return map(value);
  }

  static ({DanmakuMsg message, int color, int mode})? danmaku(
    dynamic event, {
    bool showMedal = true,
  }) {
    final root = map(event);
    final info = root['info'];
    if (info is! List && root['dm_v2'] is String) {
      return _binaryDanmaku(root['dm_v2']);
    }
    final text = at(info, 1);
    if (text is! String) return null;
    final first = at(info, 0);
    final content = map(at(first, 15));
    final user = map(content['user']);
    final legacy = at(info, 2);
    final badges = LiveUserBadges.parse(user, info: info);
    final uid = badges.anonymous ? 0 : integer(user['uid'] ?? at(legacy, 0));
    final name = badges.anonymous
        ? '匿名观众'
        : map(user['base'])['name'] ?? at(legacy, 1) ?? '观众';
    final detail = extra(content['extra']);
    final check = map(at(info, 9));
    BaseEmote? uemote;
    final emots = <String, BaseEmote>{};
    try {
      if (at(first, 13) is Map) {
        uemote = BaseEmote.fromJson(map(at(first, 13)));
      }
    } catch (_) {}
    for (final entry in map(detail['emots']).entries) {
      try {
        emots[entry.key] = BaseEmote.fromJson(map(entry.value));
      } catch (_) {}
    }
    UinfoMedal? medal;
    if (showMedal && !badges.anonymous) {
      try {
        medal = UinfoMedal.lightMedal(
          user['medal'] is Map ? map(user['medal']) : null,
        );
      } catch (_) {}
    }
    final replyMid = integer(detail['reply_mid']);
    return (
      message: DanmakuMsg(
        name: '$name',
        text: text,
        emots: emots.isEmpty ? null : emots,
        uemote: uemote,
        medalInfo: medal,
        badges: badges,
        lottery: {1, 2}.contains(integer(at(first, 9))),
        reply: replyMid > 0
            ? Owner(
                mid: detail['reply_is_mystery'] == true ? 0 : replyMid,
                name: detail['reply_is_mystery'] == true
                    ? '匿名观众'
                    : '${detail['reply_uname'] ?? ''}',
              )
            : null,
        extra: LiveDanmaku(
          id: detail['id_str'] ?? '',
          mid: uid,
          dmType: integer(detail['dm_type'] ?? at(first, 12)),
          ts: check['ts'] ?? at(first, 4) ?? 0,
          ct: check['ct'] ?? '',
        ),
      ),
      color: integer(detail['color'] ?? at(first, 3), 0xffffff),
      mode: integer(detail['mode'] ?? at(first, 1), 1),
    );
  }

  static ({DanmakuMsg message, int color, int mode})? _binaryDanmaku(
    String encoded,
  ) {
    final data = LiveWireDecoder.danmaku(encoded);
    if (data == null || data['content'] is! String) return null;
    final user = map(data['user']);
    final check = map(data['check']);
    final reply = map(data['reply']);
    final emots = <String, BaseEmote>{};
    for (final entry in map(data['emoticons']).entries) {
      try {
        emots[entry.key] = BaseEmote.fromJson(map(entry.value));
      } catch (_) {}
    }
    final special = integer(data['dm_type']) == 1;
    final badges = LiveUserBadges.parse(
      user,
      data: {
        'isadmin': integer(user['attr']) != 0,
        'uname_color': user['name_color'],
      },
    );
    return (
      message: DanmakuMsg(
        name: '${user['name'] ?? '观众'}',
        text: data['content'],
        badges: badges,
        lottery: {1, 2}.contains(integer(data['biz_scene'])),
        uemote: special ? emots[data['content']] : null,
        emots: !special && emots.isNotEmpty ? emots : null,
        reply: integer(reply['reply_mid']) > 0
            ? Owner(
                mid: integer(reply['reply_mid']),
                name: '${reply['reply_uname'] ?? ''}',
              )
            : null,
        extra: LiveDanmaku(
          id: data['id_str'] ?? '',
          mid: integer(user['uid']),
          dmType: integer(data['dm_type']),
          ts: check['ts'] ?? data['ctime'] ?? 0,
          ct: check['token'] ?? '',
        ),
      ),
      color: integer(data['color'], 0xffffff),
      mode: integer(data['mode'], 1),
    );
  }
}

class LiveGiftMessage {
  const LiveGiftMessage({
    required this.uid,
    required this.name,
    required this.giftName,
    required this.quantity,
    required this.action,
    this.id = '',
    this.giftId = 0,
    this.imageUrl = '',
    this.animationUrl = '',
    this.badges = const LiveUserBadges(),
  });
  final int uid;
  final String name, giftName, action, id;
  final int quantity;
  final int giftId;
  final String imageUrl, animationUrl;
  final LiveUserBadges badges;

  static List<LiveGiftMessage> parseAll(dynamic event) {
    final root = LiveMessageParser.map(event);
    var data = LiveMessageParser.map(root['data']);
    if (data['pb'] is String) {
      data = LiveGiftBroadcast.decode(data['pb']) ?? {};
    }
    if (data['gift_list'] is List) {
      final sender = LiveMessageParser.map(data['sender_uinfo']);
      return [
        for (final item in data['gift_list'])
          ?parse({
            'cmd': 'SEND_GIFT',
            'data': {
              ...LiveMessageParser.map(item),
              'uid': data['uid'],
              'uname': data['uname'],
              'uinfo': sender,
            },
          }),
      ];
    }
    final gift = parse(event);
    return gift == null ? [] : [gift];
  }

  static LiveGiftMessage? parse(dynamic event) {
    final root = LiveMessageParser.map(event);
    final cmd = '${root['cmd']}'.split(':').first;
    // COMBO_SEND is a cumulative duplicate of SEND_GIFT, not another gift.
    if (cmd != 'SEND_GIFT' && cmd != 'SEND_GIFT_V2' && cmd != 'GUARD_BUY')
      return null;
    final data = LiveMessageParser.map(root['data']);
    final user = LiveMessageParser.map(data['sender_uinfo'] ?? data['uinfo']);
    final base = LiveMessageParser.map(user['base']);
    final anonymous =
        base['is_mystery'] == true ||
        base['is_mystery'] == 1 ||
        data['is_mystery'] == true ||
        data['is_mystery'] == 1 ||
        user['anonymous'] == true ||
        (user['anon'] is Map && (user['anon'] as Map).isNotEmpty);
    final name =
        data['uname'] ??
        data['username'] ??
        LiveMessageParser.map(user['base'])['name'] ??
        '观众';
    final gift = data['giftName'] ?? data['gift_name'];
    final count = LiveMessageParser.integer(data['num']);
    if (gift is! String || gift.isEmpty || count < 1) return null;
    return LiveGiftMessage(
      uid: anonymous
          ? 0
          : LiveMessageParser.integer(user['uid'] ?? data['uid']),
      name: anonymous ? '匿名观众' : '${base['name'] ?? name}',
      giftName: gift,
      quantity: count,
      giftId: LiveMessageParser.integer(data['giftId'] ?? data['gift_id']),
      imageUrl: liveAssetUrl(
        LiveMessageParser.map(data['gift_info'])['img_basic'],
      ),
      animationUrl: liveAssetUrl(
        LiveMessageParser.map(data['gift_info'])['webp'],
      ),
      badges: LiveUserBadges.parse(user, data: data),
      action: cmd == 'GUARD_BUY' ? '开通' : '${data['action'] ?? '赠送'}',
      id: data['tid'] == null
          ? ''
          : 'gift:${data['tid']}:${data['giftId'] ?? data['gift_id'] ?? gift}',
    );
  }
}
