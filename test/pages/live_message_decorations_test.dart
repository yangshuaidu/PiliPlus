import 'package:PiliPlus/models_new/live/live_superchat/item.dart';

import 'dart:async';
import 'dart:convert';

import 'package:PiliPlus/models_new/live/live_danmaku/live_message_parser.dart';
import 'package:PiliPlus/models_new/live/live_danmaku/live_room_notice.dart';
import 'package:PiliPlus/models_new/live/live_danmaku/live_user_badges.dart';
import 'package:PiliPlus/pages/live_room/live_gift_effects.dart';
import 'package:PiliPlus/pages/live_room/widgets/message_badges.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

List<int> varint(int v) {
  final bytes = <int>[];
  while (v > 127) {
    bytes.add((v & 127) | 128);
    v >>= 7;
  }
  return [...bytes, v];
}

List<int> number(int field, int value) => [
  ...varint(field << 3),
  ...varint(value),
];
List<int> bytes(int field, List<int> body) => [
  ...varint((field << 3) | 2),
  ...varint(body.length),
  ...body,
];
List<int> string(int field, String text) => bytes(field, utf8.encode(text));

void main() {
  test('re-enabled effects do not stall behind an invalidated material lookup', () async {
    final gate = Completer<Map<String, dynamic>>();
    final effects = LiveGiftEffects(loadCatalog: () => gate.future);
    const oldGift = LiveGiftMessage(uid: 1, name: '旧消息', giftName: '礼物', giftId: 10, quantity: 1, action: '赠送');
    const newGift = LiveGiftMessage(uid: 2, name: '新消息', giftName: '礼物', giftId: 10, quantity: 1, action: '赠送');
    effects.add(oldGift);
    effects.setEnabled(false);
    effects.setEnabled(true);
    effects.add(newGift);
    gate.complete({});
    await Future<void>.delayed(Duration.zero);
    expect(effects.current.value!.message.uid, 2);
    effects.dispose();
  });
  test('official lottery scene and binary emote survive protocol decoding', () {
    final emote = [
      ...string(1, 'official_1'),
      ...string(2, '//i0.hdslb.com/emote.gif'),
      ...number(4, 1),
      ...number(6, 32),
      ...number(7, 32),
    ];
    final encoded = [
      ...string(6, '[表情]'),
      ...number(11, 2),
      ...number(13, 1),
      ...bytes(14, [...string(1, '[表情]'), ...bytes(2, emote)]),
    ];
    final message = LiveMessageParser.danmaku({'dm_v2': base64Encode(encoded)})!
        .message;
    expect(message.lottery, isTrue);
    expect(message.uemote!.url, 'https://i0.hdslb.com/emote.gif');
    expect(message.uemote!.inPlayerArea, isTrue);
    final first = List<dynamic>.filled(16, null);
    first[9] = 1;
    expect(
      LiveMessageParser.danmaku({
        'info': [
          first,
          '抽奖内容',
          [1, '用户'],
        ],
      }, showMedal: false)!.message.lottery,
      isTrue,
    );
  });
  test('anonymous SC suppresses legacy real name and profile identifiers', () {
    final message = SuperChatItem.fromJson({
      'id': '7',
      'uid': 99,
      'price': '30',
      'user_info': {'uname': '隐藏原名', 'face': 'https://example.com/secret'},
      'uinfo': {
        'uid': 99,
        'base': {'is_mystery': true, 'name': '隐藏原名'},
      },
      'message': '匿名SC',
    }, 10);
    expect(message.uid, 0);
    expect(message.userInfo.uname, '匿名观众');
    expect(message.userInfo.face, isEmpty);
    expect(message.medalInfo, isNull);
  });

  test('legacy danmaku retains official rank, wealth, manager, guard and medal fields', () {
    final info = List<dynamic>.filled(18, null);
    info[0] = [];
    info[1] = '截图消息';
    info[2] = [1, '用户', 1];
    info[3] = [43, '云与鱼'];
    info[4] = [0, 0, 0, 1];
    info[5] = ['', 'title_1'];
    info[7] = 3;
    info[16] = [43];
    final badge = LiveMessageParser.danmaku({
      'info': info,
    }, showMedal: false)!.message.badges;
    expect(badge.rank, 1);
    expect(badge.wealth, 43);
    expect(badge.manager, isTrue);
    expect(badge.guard, 3);
    expect(badge.medalName, '云与鱼');
    expect(badge.title, '头衔');
  });
  test('binary-only dm_v2 preserves text, user, ID and badge information', () {
    final user = [
      ...number(1, 88),
      ...string(2, '二进制用户'),
      ...number(10, 1),
      ...bytes(11, [
        ...number(1, 27),
        ...string(2, '勋章'),
        ...number(9, 3),
        ...number(10, 1),
      ]),
      ...bytes(12, number(4, 2)),
      ...bytes(15, number(1, 21)),
    ];
    final message = [
      ...string(1, 'binary-id'),
      ...number(2, 1),
      ...number(4, 0xffffff),
      ...string(6, '不会遗漏的弹幕'),
      ...bytes(20, user),
    ];
    final parsed = LiveMessageParser.danmaku({
      'cmd': 'DANMU_MSG',
      'dm_v2': base64Encode(message),
    })!;
    expect(parsed.message.text, '不会遗漏的弹幕');
    expect(parsed.message.extra.mid, 88);
    expect(parsed.message.extra.id, 'binary-id');
    expect(parsed.message.badges.wealth, 21);
    expect(parsed.message.badges.rank, 2);
    expect(parsed.message.badges.guard, 3);
    expect(LiveMessageParser.danmaku({'dm_v2': 'broken'}), isNull);
  });
  test('anonymous live messages suppress identity and badges', () {
    final info = List<dynamic>.filled(18, null),
        first = List<dynamic>.filled(16, null);
    first[15] = {
      'user': {
        'uid': 99,
        'base': {'name': '隐藏原名', 'is_mystery': true},
        'wealth': {'level': 43},
      },
    };
    info[0] = first;
    info[1] = '匿名内容';
    info[2] = [99, '隐藏原名', 1];
    info[16] = [43];
    final message = LiveMessageParser.danmaku({'info': info})!.message;
    expect(message.extra.mid, 0);
    expect(message.name, '匿名观众');
    expect(message.badges.wealth, 0);
  });
  test('legacy and protobuf entry messages, follow and safe system text', () {
    final old = LiveRoomNotice.parse({
      'cmd': 'INTERACT_WORD',
      'data': {'uid': 1, 'uname': '用户', 'msg_type': 2, 'roomid': 10},
    }, 10)!;
    expect(old.text, '关注了主播');
    final payload = [
      ...number(5, 1),
      ...number(6, 10),
      ...bytes(22, [...number(1, 1), ...bytes(2, string(1, '新用户'))]),
    ];
    final modern = LiveRoomNotice.parse({
      'cmd': 'INTERACT_WORD_V2',
      'data': {'pb': base64Encode(payload)},
    }, 10)!;
    expect(modern.name, '新用户');
    expect(modern.entry, isTrue);
    expect(
      LiveRoomNotice.parse({
        'cmd': 'INTERACT_WORD',
        'data': {'roomid': 999, 'msg_type': 1},
      }, 10),
      isNull,
    );
    expect(
      LiveRoomNotice.parse({
        'cmd': 'NOTICE_MSG',
        'msg_common': '<script>bad()</script><b>系统消息</b>',
      }, 10)!.text,
      '系统消息',
    );
    expect(
      LiveRoomNotice.parse({
        'cmd': 'HEARTBEAT',
        'data': {'count': 3},
      }, 10),
      isNull,
    );
  });
  test('gift material snapshots support legacy V2 and own sender identity', () {
    final messages = LiveGiftMessage.parseAll({
      'cmd': 'SEND_GIFT_V2',
      'data': {
        'uid': 100,
        'uname': '自己',
        'gift_id': 1,
        'gift_name': '礼物',
        'num': 2,
        'gift_info': {'webp': 'https://i0.hdslb.com/gift.webp'},
      },
    });
    expect(messages.single.uid, 100);
    expect(messages.single.animationUrl, endsWith('.webp'));
  });
  testWidgets('all screenshot badges wrap within 320px', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: Text.rich(
              TextSpan(
                children: [
                  ...liveBadgeSpans(
                    const LiveUserBadges(
                      rank: 1,
                      wealth: 43,
                      guard: 3,
                      manager: true,
                      medalName: '云与鱼',
                      medalLevel: 43,
                      title: '特别头衔',
                    ),
                  ),
                  const TextSpan(text: '用户名：这是一条能自动换行的弹幕消息'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('榜1'), findsOneWidget);
    expect(find.text('舰长'), findsOneWidget);
    expect(find.text('房'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test(
    'turning effects off invalidates pending material lookup and clears queue',
    () async {
      final gate = Completer<Map<String, dynamic>>();
      final effects = LiveGiftEffects(
        loadCatalog: () => gate.future,
        duration: const Duration(milliseconds: 1),
      );
      const message = LiveGiftMessage(
        uid: 1,
        name: '测试',
        giftName: '礼物',
        giftId: 10,
        quantity: 1,
        action: '赠送',
      );
      effects.add(message);
      effects.setEnabled(false);
      gate.complete({
        'gift_config': {
          'base_config': {
            'list': [
              {'id': 10, 'gif': 'https://i0.hdslb.com/gift.gif'},
            ],
          },
        },
      });
      await Future<void>.delayed(Duration.zero);
      expect(effects.current.value, isNull);
      effects.setEnabled(true);
      effects.add(message);
      await Future<void>.delayed(Duration.zero);
      expect(effects.current.value!.url, endsWith('.gif'));
      effects.dispose();
      expect(effects.current.value, isNull);
    },
  );
}
