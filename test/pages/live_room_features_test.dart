import 'dart:convert';

import 'package:PiliPlus/models_new/live/live_contribution_rank/item.dart';
import 'package:PiliPlus/models_new/live/live_danmaku/live_gift_broadcast.dart';
import 'package:PiliPlus/models_new/live/live_danmaku/live_message_parser.dart';
import 'package:PiliPlus/models_new/live/live_pk.dart';
import 'package:PiliPlus/pages/live_room/live_danmaku_delivery.dart';
import 'package:PiliPlus/pages/live_room/live_room_features.dart';
import 'package:PiliPlus/pages/live_room/widgets/pk_bar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

List<int> wireBytes(int tag, List<int> bytes) => [tag, bytes.length, ...bytes];
Map<String, dynamic> pkEvent({int timestamp = 100, int status = 201}) => {
  'pk_basic': {
    'pk_id': 7,
    'status': status,
    'end_time': 160,
    'punish_end_time': 220,
  },
  'timestamp': timestamp,
  'members': [
    {'room_id': 20, 'uid': 2, 'uname': '另一位主播的很长名称', 'votes': 40},
    {'room_id': 10, 'uid': 1, 'uname': '本房间主播的很长名称', 'votes': 60},
  ],
};

void main() {
  test('protobuf gifts preserve multi-item quantity and suppress anonymous identity', () {
    List<int> gift(String name, int count) => [
      8,
      10,
      ...wireBytes(18, utf8.encode(name)),
      24,
      count,
    ];
    final user = [
      8,
      99,
      ...wireBytes(18, [...wireBytes(10, utf8.encode('不应显示')), 32, 1]),
    ];
    final bytes = [
      8,
      99,
      ...wireBytes(18, utf8.encode('原始名字')),
      ...wireBytes(82, gift('礼物A', 2)),
      ...wireBytes(82, gift('礼物B', 3)),
      ...wireBytes(122, user),
    ];
    final items = LiveGiftMessage.parseAll({
      'cmd': 'SEND_GIFT_V2',
      'data': {'pb': base64Encode(bytes)},
    });
    expect(items.map((a) => a.quantity), [2, 3]);
    expect(items.map((a) => a.name), ['匿名观众', '匿名观众']);
    expect(items.every((a) => a.uid == 0), isTrue);
    expect(LiveGiftBroadcast.decode(base64Encode([82, 100, 1])), isNull);
  });
  test('explicit mystery rank does not expose raw identity or medal', () {
    final user = LiveContributionRankItem.fromJson({
      'uid': 77,
      'name': 'secret',
      'face': 'secret.png',
      'uinfo': {
        'base': {'is_mystery': 1},
        'medal': {'level': 'invalid'},
      },
    });
    expect(user.anonymous, isTrue);
    expect(user.uid, isNull);
    expect(user.face, isNull);
    expect(user.uinfoMedal, isNull);
    expect(
      LiveContributionRankItem.fromJson({
        'uid': '8',
        'name': '普通观众',
        'uinfo': {
          'medal': {'level': []},
        },
      }).name,
      '普通观众',
    );
  });
  test('PK orders current room first and uses server-relative countdown', () {
    final now = DateTime.utc(2026);
    final state = LivePkState.parse(pkEvent(), 10, now)!;
    expect(state.members.first.roomId, 10);
    expect(state.remaining(now.add(const Duration(seconds: 8))), 52);
    expect(LivePkState.parse(pkEvent(), 99, now), isNull);
    expect(
      LivePkState.parse(pkEvent(status: 601), 10, now)!.remaining(now),
      120,
    );
  });
  test(
    'terminal PK without member list cannot be resurrected by stale events',
    () {
      final features = LiveRoomFeatures(10);
      features.onEvent({'cmd': 'PK_INFO', 'data': pkEvent()});
      expect(features.pk.value, isNotNull);
      features.onEvent({'cmd': 'PK_INFO', 'data': pkEvent(timestamp: 90)});
      expect(features.pk.value!.serverTimestamp, 100);
      features.onEvent({
        'cmd': 'PK_INFO',
        'data': {
          'pk_basic': {'pk_id': 7, 'status': 1000},
        },
      });
      expect(features.pk.value, isNull);
      features.onEvent({'cmd': 'PK_INFO', 'data': pkEvent(timestamp: 120)});
      expect(features.pk.value, isNull);
      features.dispose();
    },
  );
  test('duplicate live event ID cannot acknowledge two equal sends', () {
    final tracker = LiveDanmakuDeliveryTracker(onChanged: () {});
    final first = tracker.begin(1, '相同内容', connected: true);
    final second = tracker.begin(1, '相同内容', connected: true);
    tracker.observe(uid: 1, text: '相同内容', id: 'message1');
    tracker.observe(uid: 1, text: '相同内容', id: 'message1');
    expect(first.state, LiveDeliveryState.echoed);
    expect(second.state, LiveDeliveryState.sending);
    tracker.clear();
    expect(tracker.entries, isEmpty);
    tracker.dispose();
  });
  testWidgets('PK two-side bar fits 320px with long names', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LivePkBar(
            state: LivePkState.parse(pkEvent(), 10, DateTime.now())!,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('60'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
