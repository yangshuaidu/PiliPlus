import 'dart:convert';

import 'package:PiliPlus/models_new/live/gift/live_gift.dart';

enum LiveActivityKind { redPacket, anchor }

class LiveActivity {
  LiveActivity(this.kind, this.data, this.receivedAt);
  final LiveActivityKind kind;
  final Map<String, dynamic> data;
  final DateTime receivedAt;
  bool get isRed => kind == LiveActivityKind.redPacket;
  int get id => liveInt(data[isRed ? 'lot_id' : 'id']) ?? 0;
  String get key => '${kind.name}:$id';
  int get status => liveInt(data['lot_status']) ?? 0;
  bool get joined => liveInt(data[isRed ? 'user_status' : 'status']) == 2;
  bool get paid => !isRed && liveInt(data['join_type']) == 1;
  bool get freeSupported => isRed || liveInt(data['join_type']) == 0;
  bool get anonymous =>
      data['is_mystery'] == true || liveInt(data['is_mystery']) == 1;
  String get sender => anonymous ? '匿名观众' : '${data['sender_name'] ?? '观众'}';
  String get title => isRed
      ? '$sender 的${const {1: '礼物', 2: '上舰', 3: '电池'}[liveInt(data['rp_type'])] ?? ''}红包'
      : '天选：${data['award_name'] ?? '福袋'} × ${data['award_num'] ?? '—'}';
  String get danmaku {
    final list = liveMaps(data['danmu_new']);
    return '${list.isNotEmpty ? list.first['danmu'] ?? data['danmu'] ?? '' : data['danmu'] ?? ''}';
  }

  String get requirement {
    final text = data[isRed ? 'receive_uname' : 'require_text'];
    if (text is String && text.isNotEmpty) return text;
    if (isRed) {
      if (liveInt(data['rp_type']) == 2) return '上舰红包：以平台返回的航海资格条件为准';
      return const {
            0: '全部观众',
            1: '关注条件由平台核验',
            2: '粉丝团条件由平台核验',
          }[liveInt(data['join_requirement']) ?? 0] ??
          '以平台核验的参与条件为准';
    }
    return '参与条件由平台核验';
  }

  bool get mayFollow => !isRed && liveInt(data['require_type']) == 1;
  int remaining(DateTime now) {
    final elapsed = now.difference(receivedAt).inSeconds;
    final initial = isRed
        ? (liveInt(data['end_time']) ?? 0) -
              (liveInt(data['current_time']) ??
                  receivedAt.millisecondsSinceEpoch ~/ 1000)
        : liveInt(data['time']) ?? 0;
    return (initial - elapsed).clamp(0, 86400);
  }

  bool active(DateTime now) =>
      remaining(now) > 0 && (isRed ? status < 2 : status == 0);
  String get consentFingerprint => jsonEncode({
    'key': key,
    'paid': paid,
    'join_type': data['join_type'],
    'requirement': requirement,
    'require_type': data['require_type'],
    'require_value': data['require_value'],
    'join_requirement': data['join_requirement'],
    'danmaku': danmaku,
    'award': data['award_name'],
    'rp_type': data['rp_type'],
  });
  List<Map<String, dynamic>> get winners =>
      liveMaps(data[isRed ? 'winner_info' : 'award_users']);
  static List<LiveActivity> redPackets(dynamic raw, DateTime now) {
    final map = liveMap(raw);
    final list = raw is List
        ? raw
        : map['list'] is List
        ? map['list']
        : map['lot_info'] is List
        ? map['lot_info']
        : [map];
    return liveMaps(list)
        .map((d) => LiveActivity(LiveActivityKind.redPacket, d, now))
        .where((a) => a.id > 0)
        .toList();
  }
}
