import 'dart:async';
import 'dart:convert';

import 'package:PiliPlus/models_new/live/gift/live_gift_parser.dart';
import 'package:PiliPlus/services/live_gift_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/live_gift_fakes.dart';

void main() {
  late FakeTransport transport;
  late FakeJournal journal;
  late LiveGiftService service;
  late LiveGiftAccount account;
  late DateTime clock;

  LiveGiftService create() => LiveGiftService(
    roomId: 200,
    anchorUid: 300,
    transport: transport,
    journal: journal,
    currentAccount: () => account,
    now: () => clock,
  );
  Future<LiveGiftConfirmation> prepare({
    bool bag = false,
    int count = 1,
  }) async {
    final snapshot = await service.loadPanel();
    return service.prepare(
      snapshot.gifts.single,
      count,
      bagItem: bag ? snapshot.bag.single : null,
      expectedAccountIdentity: snapshot.accountIdentity,
    );
  }

  setUp(() {
    transport = FakeTransport();
    journal = FakeJournal();
    account = LiveGiftAccount(100, FakeLoginIdentity(), 'test-csrf');
    clock = DateTime.utc(2026, 10, 3);
    service = create();
  });
  tearDown(() => service.dispose());

  test('medal progress reads official current state, never purchase projection', () async {
    transport.giftMessageData = {
      'fans_medal_info': {
        'received': true,
        'current': {'medal': {
          'target_id': 300,
          'medal_name': '测试勋章',
          'level': 27,
          'intimacy': 722,
          'next_intimacy': 2000,
        }},
        'expectation': {'medal': {
          'target_id': 300,
          'medal_name': '测试勋章',
          'level': 28,
          'intimacy': 0,
          'next_intimacy': 5000,
        }},
      },
    };
    final snapshot = await service.loadPanel();
    expect(snapshot.medal!.level, 27);
    expect(snapshot.medal!.remaining, 1278);
    expect(transport.lastMedalQuery!['target_id'], 300);
    expect(transport.lastMedalQuery!['room_id'], 200);
    expect(transport.lastMedalQuery!['gift_id'], 10);
    expect(transport.lastMedalQuery!['price'], 100);
    expect(transport.postCount, 0);
    transport.giftMessageData = {
      'fans_medal_info': {'received': false, 'current': {
        'medal': {'target_id': 300, 'medal_name': '测试勋章', 'level': 27}
      }},
    };
    expect((await service.loadPanel()).medal, isNull);
    expect(transport.postCount, 0);
  });

  test('room gift tabs are included and duplicate entries appear once', () {
    final gifts = LiveGiftParser.gifts(
      {
        'gift_config': {
          'base_config': {
            'list': [
              giftConfig(),
              {...giftConfig(), 'id': 11},
            ],
          },
        },
        'gift_data': {
          'max_send_gift': 99,
          'room_gift_list': {
            'gold_list': [
              {'gift_id': 10},
            ],
          },
          'tab_list': [
            {
              'list': [
                {'gift_id': 10},
                {'gift_id': 11},
              ],
            },
          ],
        },
      },
      200,
      300,
    );
    expect(gifts.map((gift) => gift.id), [10, 11]);
  });

  test(
    'room disabling its bag blocks a previously confirmed bag gift',
    () async {
      final confirmation = await prepare(bag: true);
      transport.bagDisabled = true;
      expect(
        (await service.submit(confirmation)).state,
        LiveActionState.notSubmitted,
      );
      expect(transport.postCount, 0);
    },
  );

  test(
    'an unknown result arriving during refresh is rechecked under the lock',
    () async {
      final confirmation = await prepare();
      transport.onCatalogRead = () {
        journal.records['100:200:300'] = {
          'state': 'unknown',
          'operation_id': 'another-panel',
          'gift_name': '其他礼物',
          'quantity': 1,
        };
      };
      expect(
        (await service.submit(confirmation)).state,
        LiveActionState.notSubmitted,
      );
      expect(transport.postCount, 0);
      expect(journal.records['100:200:300']!['operation_id'], 'another-panel');
    },
  );

  test('official groups retain names, ordering and overlapping membership', () {
    final groups = LiveGiftParser.groups({
      'gift_data': {
        'room_gift_list': {
          'gold_list': [
            {'gift_id': '10'},
            {'gift_id': 10},
          ],
        },
        'tab_list': [
          {
            'tab_id': 2,
            'tab_name': '航海',
            'position': 5,
            'list': [
              {'gift_id': 20},
            ],
          },
          {
            'tab_id': 11,
            'tab_name': '互动',
            'position': 2,
            'list': [
              {'gift_id': 10},
              {'gift_id': 11},
              {'gift_id': -1},
            ],
          },
          {
            'tab_id': 9,
            'tab_name': '粉丝团',
            'position': 4,
            'list': [
              {'gift_id': 11},
            ],
          },
        ],
      },
    });
    expect(groups.map((group) => group.name), ['常规', '互动', '粉丝团', '航海']);
    expect(groups.map((group) => group.id), [
      'room',
      'tab:11',
      'tab:9',
      'tab:2',
    ]);
    expect(groups[0].giftIds, {10});
    expect(groups[1].giftIds, {10, 11});
    expect(groups[2].giftIds, {11});
  });

  test('integer gold display preserves fractional batteries', () {
    expect(liveBatteryAmount(0), '0');
    expect(liveBatteryAmount(100), '1');
    expect(liveBatteryAmount(101), '1.01');
    expect(liveBatteryAmount(110), '1.1');
    expect(liveBatteryAmount(9900), '99');
  });
  test('unknown prices, blind boxes and other-room gifts cannot send', () {
    final invalid = [
      {...giftConfig(), 'price': null},
      {...giftConfig(), 'gift_type': 6},
      {
        ...giftConfig(),
        'gift_attrs': [6],
      },
      {...giftConfig(), 'bind_roomid': 999},
      {...giftConfig(), 'bind_ruid': 999},
      {...giftConfig(), 'privilege_required': 1},
    ];
    for (final config in invalid) {
      expect(
        LiveGiftParser.gift(config, roomId: 200, anchorUid: 300).sendable,
        isFalse,
      );
    }
  });
  test('fixed quantity rules and expired inventory are retained', () {
    final gift = LiveGiftParser.gift({
      ...giftConfig(),
      'diy_count_map': 0,
      'count_map': [
        {'num': 1},
        {'num': 10},
      ],
    }, maxQuantity: 99);
    expect(gift.allowedQuantities, [1, 10]);
    final bag = LiveGiftParser.bag(
      {
        'gift_config': [giftConfig()],
        'list': [
          {
            'type': 1,
            'bag_id': 50,
            'gift_id': 10,
            'gift_num': 1,
            'expire_at': 1,
          },
        ],
      },
      200,
      300,
      clock,
    );
    expect(bag.single.available, isFalse);
  });
  test('preparing or cancelling a confirmation never sends', () async {
    final confirmation = await prepare();
    service.cancelConfirmation();
    expect(
      (await service.submit(confirmation)).state,
      LiveActionState.notSubmitted,
    );
    expect(transport.postCount, 0);
  });
  test(
    'paid gift uses raw price, exact recipient and one matching receipt',
    () async {
      transport.price = 123;
      final confirmation = await prepare(count: 2);
      expect(confirmation.displayTotalPrice, '2.46');
      final result = await service.submit(confirmation);
      expect(result.state, LiveActionState.succeeded);
      expect(transport.postCount, 1);
      expect(transport.sentPath, LiveGiftService.sendGoldPath);
      expect(transport.sentBody!['price'], 123);
      expect(transport.sentBody!['gift_num'], 2);
      expect(jsonDecode(transport.sentBody!['receive_users'] as String), [
        {'uid': 300},
      ]);
      expect(journal.records.values.single.containsKey('csrf'), isFalse);
      expect(journal.records.values.single['total_price'], 246);
    },
  );
  test(
    'bag consumes inventory with zero payment, even with zero balance',
    () async {
      transport.balance = 0;
      final confirmation = await prepare(bag: true, count: 2);
      expect(confirmation.totalPrice, 0);
      expect(
        (await service.submit(confirmation)).state,
        LiveActionState.succeeded,
      );
      expect(transport.sentPath, LiveGiftService.sendBagPath);
      expect(transport.sentBody!['bag_id'], 50);
      expect(transport.sentBody!['price'], 0);
    },
  );
  test('price changing after confirmation prevents submission', () async {
    final confirmation = await prepare();
    transport.price++;
    expect(
      (await service.submit(confirmation)).state,
      LiveActionState.notSubmitted,
    );
    expect(transport.postCount, 0);
  });
  test('stock changing after confirmation prevents submission', () async {
    final confirmation = await prepare(bag: true, count: 2);
    transport.stock = 1;
    expect(
      (await service.submit(confirmation)).state,
      LiveActionState.notSubmitted,
    );
    expect(transport.postCount, 0);
  });
  test('bag expiring after confirmation prevents submission', () async {
    final confirmation = await prepare(bag: true);
    transport.expires = 1;
    expect(
      (await service.submit(confirmation)).state,
      LiveActionState.notSubmitted,
    );
    expect(transport.postCount, 0);
  });
  test('balance and quantity are checked before confirmation', () async {
    transport.balance = 1;
    await expectLater(prepare(), throwsA(isA<LiveGiftException>()));
    transport.balance = 100000;
    await expectLater(prepare(count: 0), throwsA(isA<LiveGiftException>()));
    await expectLater(prepare(count: 100), throwsA(isA<LiveGiftException>()));
    expect(transport.postCount, 0);
  });
  test(
    'new login instance invalidates a confirmation, even for the same UID',
    () async {
      final confirmation = await prepare();
      account = LiveGiftAccount(100, FakeLoginIdentity(), 'test-csrf');
      expect(
        (await service.submit(confirmation)).state,
        LiveActionState.notSubmitted,
      );
      expect(transport.postCount, 0);
    },
  );
  test('selection from a different account cannot prepare a payment', () async {
    final snapshot = await service.loadPanel();
    account = LiveGiftAccount(101, FakeLoginIdentity(), 'new-csrf');
    await expectLater(
      service.prepare(
        snapshot.gifts.single,
        1,
        expectedAccountIdentity: snapshot.accountIdentity,
      ),
      throwsA(isA<LiveGiftException>()),
    );
    expect(transport.postCount, 0);
  });
  test('expired confirmation and a closed panel do not send', () async {
    final confirmation = await prepare();
    clock = clock.add(const Duration(minutes: 2));
    expect(
      (await service.submit(confirmation)).state,
      LiveActionState.notSubmitted,
    );
    service.dispose();
    expect(
      (await service.submit(confirmation)).state,
      LiveActionState.notSubmitted,
    );
    expect(transport.postCount, 0);
  });
  test(
    'concurrent clicks and reuse of a confirmation send only once',
    () async {
      final confirmation = await prepare();
      transport.postGate = Completer<void>();
      final first = service.submit(confirmation);
      await transport.postStarted.future;
      expect(
        (await service.submit(confirmation)).state,
        LiveActionState.notSubmitted,
      );
      transport.postGate!.complete();
      expect((await first).state, LiveActionState.succeeded);
      expect(
        (await service.submit(confirmation)).state,
        LiveActionState.notSubmitted,
      );
      expect(transport.postCount, 1);
    },
  );
  test(
    'network timeout remains unknown and is never automatically resent',
    () async {
      final confirmation = await prepare();
      transport.timeout = true;
      expect(
        (await service.submit(confirmation)).state,
        LiveActionState.unknown,
      );
      service.dispose();
      service = create();
      expect((await service.pending())?.state, LiveActionState.unknown);
      await expectLater(prepare(), throwsA(isA<LiveGiftException>()));
      expect(transport.postCount, 1);
    },
  );
  test('code zero without a matching receipt is not success', () async {
    final confirmation = await prepare();
    transport.response = {'code': 0, 'data': {}};
    expect((await service.submit(confirmation)).state, LiveActionState.unknown);
    expect(await service.pending(), isNotNull);
  });
  test('receipt for another recipient is not success', () async {
    final confirmation = await prepare();
    transport.response = {
      'code': 0,
      'data': {
        'uid': 100,
        'gift_list': [
          {
            'gift_id': 10,
            'gift_num': 1,
            'receiver_uinfo': {'uid': 999},
            'tid': 'wrong-order',
          },
        ],
      },
    };
    expect((await service.submit(confirmation)).state, LiveActionState.unknown);
  });
  test('server rejection is shown as failed rather than success', () async {
    final confirmation = await prepare();
    transport.response = {'code': -400, 'message': '不可赠送'};
    final result = await service.submit(confirmation);
    expect(result.state, LiveActionState.failed);
    expect(result.message, '不可赠送');
    expect(await service.pending(), isNull);
  });
  test('cannot send without a durable submission marker', () async {
    final confirmation = await prepare();
    journal.failStart = true;
    expect(
      (await service.submit(confirmation)).state,
      LiveActionState.notSubmitted,
    );
    expect(transport.postCount, 0);
  });
  test('failure to save the final receipt keeps the pending marker', () async {
    final confirmation = await prepare();
    journal.failFinish = true;
    expect((await service.submit(confirmation)).state, LiveActionState.unknown);
    expect(journal.records.values.single['state'], 'submitting');
    expect((await service.pending())?.state, LiveActionState.unknown);
  });
  test(
    'explicit acknowledgement unlocks future gifts without replay or success',
    () async {
      final confirmation = await prepare();
      transport.timeout = true;
      await service.submit(confirmation);
      await service.acknowledgeUnknown(confirmation.operationId);
      expect(await service.pending(), isNull);
      expect(journal.records.values.single['state'], 'unknown');
      expect(transport.postCount, 1);
      await prepare();
      expect(transport.postCount, 1);
    },
  );
  test('closing or switching accounts during a write still journals the original result', () async {
    final confirmation = await prepare();
    transport.postGate = Completer<void>();
    final result = service.submit(confirmation);
    await transport.postStarted.future;
    service.dispose();
    account = LiveGiftAccount(101, FakeLoginIdentity(), 'new-csrf');
    transport.postGate!.complete();
    expect((await result).state, LiveActionState.succeeded);
    expect(journal.records['100:200:300']!['state'], 'succeeded');
    expect(journal.records.containsKey('101:200:300'), isFalse);
  });
  test(
    'read errors cannot be treated as an empty successful purchase',
    () async {
      final confirmation = await prepare();
      transport.failReads = true;
      expect(
        (await service.submit(confirmation)).state,
        LiveActionState.notSubmitted,
      );
      expect(transport.postCount, 0);
    },
  );
}
