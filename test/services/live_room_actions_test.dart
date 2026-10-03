import 'dart:convert';

import 'package:PiliPlus/models_new/live/gift/live_red_packet.dart';
import 'package:PiliPlus/models_new/live/live_activity.dart';
import 'package:PiliPlus/services/live_activity_service.dart';
import 'package:PiliPlus/services/live_gift_service.dart';
import 'package:PiliPlus/services/live_red_packet_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/live_gift_fakes.dart';
import '../support/live_room_actions_fakes.dart';

void main() {
  late ActivityTransport transport;
  late FakeJournal journal;
  late LiveGiftAccount account;
  late LiveGiftService gifts;
  late LiveRedPacketService packets;
  late LiveActivityService activities;
  late DateTime now;
  setUp(() {
    transport = ActivityTransport();
    journal = FakeJournal();
    account = LiveGiftAccount(100, FakeLoginIdentity(), 'test-csrf');
    now = DateTime.utc(2026);
    gifts = LiveGiftService(
      roomId: 200,
      anchorUid: 300,
      transport: transport,
      journal: journal,
      currentAccount: () => account,
      now: () => now,
    );
    packets = LiveRedPacketService(gifts);
    activities = LiveActivityService(gifts);
  });
  tearDown(() {
    packets.dispose();
    activities.dispose();
    gifts.dispose();
  });
  Future<LiveRedPacketConfirmation> prepare([
    LiveRedPacketType type = LiveRedPacketType.gift,
  ]) async {
    final config = await packets.load(type);
    final p = config.packages.single;
    return packets.prepare(
      LiveRedPacketSelection(
        type: type,
        package: p,
        duration: config.durations.first,
        count: p.counts.first,
        requirement: 0,
        requirementText: config.requirements[0] ?? '',
        danmakuId: p.danmaku.firstOrNull?.id ?? 0,
        danmakuText: p.danmaku.firstOrNull?.text ?? '',
      ),
      account.identity,
    );
  }

  test(
    'gift and guard red packets use dedicated send route, cost and seconds',
    () async {
      for (final type in [LiveRedPacketType.gift, LiveRedPacketType.guard]) {
        final confirmation = await prepare(type);
        transport.response = {
          'code': 0,
          'data': {
            'lot_info': {'lot_id': 40, 'room_id': 200, 'sender_uid': 100},
          },
        };
        expect(
          (await packets.submit(confirmation)).state,
          LiveActionState.succeeded,
        );
        expect(transport.sentPath, endsWith('/SendRedPocket'));
        expect(transport.sentBody!['duration'], 300);
        expect(transport.sentBody!['danmu_msg'], '红包测试');
        expect(transport.sentBody!.containsKey('rp_type'), isFalse);
        expect(transport.sentBody!.containsKey('gift_id'), isFalse);
      }
    },
  );
  test(
    'battery configuration aliases and official absent-selector defaults',
    () async {
      transport.batteryDefaults = true;
      final confirmation = await prepare(LiveRedPacketType.battery);
      transport.response = {
        'code': 0,
        'data': {
          'lot_info': {'lot_id': 41},
        },
      };
      expect(
        (await packets.submit(confirmation)).state,
        LiveActionState.succeeded,
      );
      expect(transport.sentBody!['duration'], 0);
      expect(jsonDecode(transport.sentBody!['battery_info']), {
        'total_battery': 1000,
        'award_num': 10,
        'join_requirement': 0,
      });
    },
  );
  test(
    'changed price or participation wording invalidates paid confirmation',
    () async {
      var c = await prepare();
      transport.fee++;
      expect((await packets.submit(c)).state, LiveActionState.notSubmitted);
      c = await prepare(LiveRedPacketType.battery);
      transport.requirement = '粉丝团';
      expect((await packets.submit(c)).state, LiveActionState.notSubmitted);
      expect(transport.postCount, 0);
    },
  );
  test('expired and replaced account confirmation never posts', () async {
    var c = await prepare();
    now = now.add(const Duration(seconds: 61));
    expect((await packets.submit(c)).state, LiveActionState.notSubmitted);
    c = await prepare();
    account = LiveGiftAccount(100, FakeLoginIdentity(), 'new-csrf');
    expect((await packets.submit(c)).state, LiveActionState.notSubmitted);
    expect(transport.postCount, 0);
  });
  test(
    'timeout is durable unknown and blocks subsequent gift spending',
    () async {
      final c = await prepare();
      transport.timeout = true;
      expect((await packets.submit(c)).state, LiveActionState.unknown);
      expect(await gifts.pending(), isNotNull);
      await expectLater(prepare(), throwsA(isA<LiveGiftException>()));
      expect(transport.postCount, 1);
    },
  );
  test('malformed or wrong-room receipt never claims paid success', () async {
    final c = await prepare();
    transport.response = {
      'code': 0,
      'data': {
        'lot_info': {'lot_id': 1, 'room_id': 999},
      },
    };
    expect((await packets.submit(c)).state, LiveActionState.unknown);
  });
  test('journal failure prevents red packet request', () async {
    final c = await prepare();
    journal.failStart = true;
    expect((await packets.submit(c)).state, LiveActionState.notSubmitted);
    expect(transport.postCount, 0);
  });
  test('free anchor participation displays follow and danmaku, never sends gift parameters', () async {
    final activity = LiveActivity(
      LiveActivityKind.anchor,
      transport.anchor,
      now,
    );
    final c = await activities.prepare(activity);
    expect(c.activity.mayFollow, isTrue);
    expect(c.activity.danmaku, '参与测试');
    transport.response = {'code': 0, 'data': {}};
    expect(await activities.submit(c), contains('已接受'));
    expect(transport.sentPath, endsWith('/Anchor/Join'));
    expect(transport.sentBody!.containsKey('gift_id'), isFalse);
    expect(transport.sentBody!.containsKey('gift_num'), isFalse);
    await expectLater(
      activities.prepare(activity),
      throwsA(isA<LiveGiftException>()),
    );
  });
  test(
    'paid, ended, altered condition and changed account lottery cannot submit',
    () async {
      LiveActivity a() =>
          LiveActivity(LiveActivityKind.anchor, transport.anchor, now);
      transport.anchor['join_type'] = 1;
      await expectLater(
        activities.prepare(a()),
        throwsA(isA<LiveGiftException>()),
      );
      transport.anchor['join_type'] = 0;
      final c = await activities.prepare(a());
      transport.anchor = {...transport.anchor, 'danmu': '改变后的弹幕'};
      await expectLater(
        activities.submit(c),
        throwsA(isA<LiveGiftException>()),
      );
      final d = await activities.prepare(a());
      account = LiveGiftAccount(101, FakeLoginIdentity(), 'changed');
      await expectLater(
        activities.submit(d),
        throwsA(isA<LiveGiftException>()),
      );
      expect(transport.postCount, 0);
    },
  );
  test(
    'manual red draw revalidates list and timeout is never retried',
    () async {
      final a = LiveActivity(LiveActivityKind.redPacket, transport.red, now);
      final c = await activities.prepare(a);
      transport.timeout = true;
      expect(await activities.submit(c), contains('结果未知'));
      expect(transport.sentPath, endsWith('/RedPocketDraw'));
      await expectLater(
        activities.prepare(a),
        throwsA(isA<LiveGiftException>()),
      );
      expect(transport.postCount, 1);
    },
  );
}
