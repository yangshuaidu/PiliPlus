import 'package:PiliPlus/models_new/live/gift/live_gift.dart';
import 'package:PiliPlus/models_new/live/live_danmaku/live_user_badges.dart';
import 'package:PiliPlus/models_new/live/live_danmaku/live_wire_decoder.dart';
import 'package:html/parser.dart' as html;

class LiveRoomNotice {
  const LiveRoomNotice({
    required this.text,
    this.uid = 0,
    this.name = '',
    this.entry = false,
    this.follow = false,
    this.share = false,
    this.broadcast = false,
    this.lottery = false,
    this.badges = const LiveUserBadges(),
    this.id = '',
  });
  final String text, name, id;
  final int uid;
  final bool entry, follow, share, broadcast, lottery;
  final LiveUserBadges badges;
  static String _plain(dynamic value) {
    if (value is! String) return '';
    final fragment = html.parseFragment(
      value.replaceAll('<%', '').replaceAll('%>', ''),
    );
    for (final element in fragment.querySelectorAll('script,style')) {
      element.remove();
    }
    final text = fragment.text?.trim() ?? '';
    return text.length > 600 ? '${text.substring(0, 600)}…' : text;
  }

  static LiveRoomNotice? parse(dynamic event, int roomId) {
    final root = liveMap(event);
    final cmd = '${root['cmd']}'.split(':').first;
    var data = liveMap(root['data']);
    if (cmd == 'INTERACT_WORD_V2' && data['pb'] is String)
      data = LiveWireDecoder.interaction(data['pb']) ?? {};
    final user = liveMap(data['uinfo'] ?? data['sender_uinfo']);
    final badges = LiveUserBadges.parse(user, data: data);
    final uid = badges.anonymous ? 0 : liveInt(user['uid'] ?? data['uid']) ?? 0;
    final name = badges.anonymous
        ? '匿名观众'
        : _plain(
            liveMap(user['base'])['name'] ?? data['uname'] ?? data['username'],
          );
    String text = '';
    bool entry = false, follow = false, share = false;
    switch (cmd) {
      case 'INTERACT_WORD':
      case 'INTERACT_WORD_V2':
        final sourceRoom = liveInt(data['roomid']);
        if (sourceRoom != null && sourceRoom > 0 && sourceRoom != roomId)
          return null;
        final type = liveInt(data['msg_type']);
        entry = type == 1;
        follow = type == 2 || type == 4 || type == 5;
        share = type == 3;
        text =
            const {
              1: '进入直播间',
              2: '关注了主播',
              3: '分享了直播间',
              4: '特别关注了主播',
              5: '与主播互粉',
            }[type] ??
            '';
      case 'ENTRY_EFFECT':
      case 'ENTRY_EFFECT_MUST_RECEIVE':
        entry = true;
        text = badges.anonymous ? '匿名观众进入直播间' : _plain(data['copy_writing']);
      case 'USER_TOAST_MSG':
      case 'USER_TOAST_MSG_V2':
        text = badges.anonymous
            ? '匿名观众开通了大航海'
            : _plain(data['toast_msg'] ?? data['toast_msg2']);
      case 'WELCOME_GUARD':
      case 'WELCOME':
        entry = true;
        text = '进入直播间';
      case 'NOTICE_MSG':
        text = _plain(
          root['msg_common'] ?? root['msg_self'] ?? data['msg_common'],
        );
      case 'COMMON_NOTICE_DANMAKU':
        final segments = liveMaps(data['content_segments']);
        text = segments
            .map((s) => _plain(liveMap(s['text'])['text']))
            .where((s) => s.isNotEmpty)
            .join();
      case 'WARNING':
      case 'CUT_OFF':
        text = _plain(data['msg'] ?? root['msg']);
      case 'LIVE':
        text = '主播开始直播';
      case 'PREPARING':
        text = '主播已结束直播';
      case 'ROOM_CHANGE':
        text = '直播间标题：${_plain(data['title'])}';
      case 'ANCHOR_LOT_START':
        text = '天选开始：${_plain(data['award_name'])}';
      case 'ANCHOR_LOT_END':
        text = '天选正在开奖';
      case 'ANCHOR_LOT_AWARD':
        text = '天选结果已公布，可在“红包与天选”查看';
      case 'POPULARITY_RED_POCKET_V2_NEW':
      case 'POPULARITY_RED_POCKET_V2_START':
        text = '红包活动已开始，可在“红包与天选”查看';
      case 'POPULARITY_RED_POCKET_V2_WINNER_LIST':
        text = '红包结果已公布，可在“红包与天选”查看';
      case 'LIKE_INFO_V3_CLICK':
        text = _plain(data['like_text']);
    }
    if (text.isEmpty) return null;
    final timestamp =
        liveInt(data['timestamp'] ?? data['trigger_time']) ??
        DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return LiveRoomNotice(
      broadcast: {
        'NOTICE_MSG',
        'COMMON_NOTICE_DANMAKU',
        'USER_TOAST_MSG',
        'USER_TOAST_MSG_V2',
      }.contains(cmd),
      lottery:
          cmd.startsWith('ANCHOR_LOT_') ||
          cmd.startsWith('POPULARITY_RED_POCKET_'),
      text: text,
      uid: uid,
      name: name,
      entry: entry,
      follow: follow,
      share: share,
      badges: badges,
      id: entry && uid > 0
          ? 'entry:$uid:${timestamp ~/ 5}'
          : data['id'] == null
          ? ''
          : '$cmd:${data['id']}',
    );
  }
}
