import 'package:PiliPlus/models_new/live/gift/live_gift.dart';

class LivePkMember {
  const LivePkMember({
    required this.uid,
    required this.roomId,
    required this.name,
    required this.face,
    required this.score,
    required this.scoreText,
    required this.winner,
    this.levelIcon = '',
  });
  final int uid, roomId, score, winner;
  final String name, face, scoreText, levelIcon;
  factory LivePkMember.parse(Map<String, dynamic> data) => LivePkMember(
    uid: liveInt(data['uid']) ?? 0,
    roomId:
        liveInt(data['room_id'] ?? data['init_id'] ?? data['match_id']) ?? 0,
    name: '${data['uname'] ?? ''}',
    face: '${data['face'] ?? ''}',
    score: liveInt(data['votes']) ?? 0,
    scoreText: '${data['votes_text'] ?? data['votes'] ?? '—'}',
    winner: liveInt(data['is_winner']) ?? -1,
    levelIcon: '${liveMap(data['battle_level'])['icon'] ?? ''}',
  );
}

class LivePkState {
  const LivePkState({
    required this.id,
    required this.status,
    required this.members,
    required this.serverTimestamp,
    required this.deadline,
    required this.receivedAt,
    this.legacy = false,
  });
  final int id, status, serverTimestamp;
  final bool legacy;
  final DateTime? deadline;
  final DateTime receivedAt;
  final List<LivePkMember> members;

  int remaining(DateTime now) =>
      (deadline?.difference(now).inSeconds ?? 0).clamp(0, 86400);
  String get phase => legacy
      ? 'PK'
      : switch (status) {
          101 => '准备',
          201 => 'PK',
          301 || 304 => '最后一击',
          401 || 404 || 501 => '结算',
          601 || 602 || 610 => '惩罚时间',
          >= 1000 => '已结束',
          _ => 'PK',
        };

  static LivePkState? parse(
    Map<String, dynamic> data,
    int roomId,
    DateTime now,
  ) {
    final basic = liveMap(data['pk_basic']);
    final modern = basic.isNotEmpty;
    final fields = modern ? basic : data;
    final id = liveInt(fields['pk_id']);
    if (id == null || id <= 0) return null;
    final status = liveInt(fields['status']) ?? 0;
    final members = modern
        ? liveMaps(data['members']).map(LivePkMember.parse).toList()
        : [
            for (final key in ['init_info', 'match_info'])
              if (data[key] is Map) LivePkMember.parse(liveMap(data[key])),
          ];
    if (members.length < 2 ||
        !members.any((member) => member.roomId == roomId)) {
      return null;
    }
    // Current room is always on the left; server participant order may reverse.
    members.sort(
      (a, b) => a.roomId == roomId
          ? -1
          : b.roomId == roomId
          ? 1
          : 0,
    );
    final timestamp =
        liveInt(data['timestamp']) ?? now.millisecondsSinceEpoch ~/ 1000;
    final end = modern
        ? (status == 101
              ? liveInt(fields['start_time'])
              : status == 301 || status == 304
              ? liveInt(
                  liveMap(liveMap(data['pk_play'])['final_conf'])['end_time'],
                )
              : status >= 601 && status < 1000
              ? liveInt(fields['punish_end_time'])
              : liveInt(fields['end_time']))
        : liveInt(fields['pk_end_time']);
    return LivePkState(
      id: id,
      status: status,
      members: members,
      serverTimestamp: timestamp,
      legacy: !modern,
      receivedAt: now,
      deadline: end == null || end <= 0
          ? null
          : now.add(Duration(seconds: end - timestamp)),
    );
  }
}
