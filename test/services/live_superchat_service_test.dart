import 'dart:convert';

import 'package:PiliPlus/models_new/live/live_superchat/purchase.dart';
import 'package:PiliPlus/services/live_gift_service.dart';
import 'package:PiliPlus/services/live_superchat_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/live_gift_fakes.dart';
import '../support/live_superchat_fakes.dart';

void main() {
  late ScTransport transport;
  late FakeJournal journal;
  late LiveGiftAccount account;
  late LiveGiftService gifts;
  late LiveSuperChatService sc;
  late DateTime now;
  setUp(() {
    transport = ScTransport()..balance = 1000000;
    journal = FakeJournal();
    account = LiveGiftAccount(100, FakeLoginIdentity(), 'test');
    now = DateTime.utc(2026);
    gifts = LiveGiftService(
      roomId: 200,
      anchorUid: 300,
      transport: transport,
      journal: journal,
      currentAccount: () => account,
      now: () => now,
    );
    sc = LiveSuperChatService(gifts);
  });
  tearDown(() {
    sc.dispose();
    gifts.dispose();
  });
  Future<LiveScSelection> select({
    int gold = 2000,
    String text = '你好',
    String key = '',
    String translation = '',
    int image = 0,
    int imageGold = 0,
  }) async {
    final config = await sc.load();
    return LiveScSelection(
      tier: config.tierForGold(gold)!,
      message: text,
      gold: gold,
      goodsId: config.goodsId,
      translationKey: key,
      translatedText: translation,
      imageId: image,
      imageGold: imageGold,
    );
  }

  Future<LiveScConfirmation> prepare() async =>
      sc.prepare(await select(), account.identity);
  test(
    'SC uses configured tier and separate animation fee with one order POST',
    () async {
      final selection = await select(gold: 40000, image: 7, imageGold: 99000);
      final c = await sc.prepare(selection, account.identity);
      transport.response = {
        'code': 0,
        'data': {
          'order_id': 'sc-order',
          'status': 4,
          'uid': 100,
          'pay_gold': 139000,
        },
      };
      final result = await sc.submit(c);
      expect(result.state, LiveActionState.succeeded);
      expect(result.message, contains('审核'));
      expect(transport.postCount, 1);
      expect(transport.sentPath, LiveSuperChatService.orderPath);
      expect(transport.sentBody!['pay_gold'], 139000);
      expect(jsonDecode(transport.sentBody!['biz_extra']), {
        'msg': '你好',
        'level': 1,
        'biz_id': 2,
        'trans_key': '',
        'sc_image_id': 7,
      });
      expect(transport.readImage, isTrue);
      expect((await sc.submit(c)).state, LiveActionState.notSubmitted);
      expect(transport.postCount, 1);
    },
  );
  test(
    'changed tier price or purchase permission invalidates confirmation',
    () async {
      var c = await prepare();
      (transport.config['price_configs'] as List).first['second'] = 9;
      expect((await sc.submit(c)).state, LiveActionState.notSubmitted);
      c = await prepare();
      (transport.config['price_configs'] as List)
              .first['type_detail']['can_buy'] =
          false;
      expect((await sc.submit(c)).state, LiveActionState.notSubmitted);
      expect(transport.postCount, 0);
    },
  );
  test(
    'custom amount rules and message limits checked before writes',
    () async {
      await expectLater(
        sc.prepare(await select(gold: 2100), account.identity),
        throwsA(isA<LiveGiftException>()),
      );
      transport.config['custom_gold'] = false;
      await expectLater(
        sc.prepare(await select(gold: 3000), account.identity),
        throwsA(isA<LiveGiftException>()),
      );
      await expectLater(
        sc.prepare(await select(text: '字' * 51), account.identity),
        throwsA(isA<LiveGiftException>()),
      );
      expect(transport.postCount, 0);
    },
  );
  test('translation key is bound to original text and account', () async {
    final translated = await sc.translate('你好');
    await expectLater(
      sc.prepare(
        await select(
          text: '修改',
          key: translated.key,
          translation: translated.text,
        ),
        account.identity,
      ),
      throwsA(isA<LiveGiftException>()),
    );
    final c = await sc.prepare(
      await select(key: translated.key, translation: translated.text),
      account.identity,
    );
    transport.response = {
      'code': 0,
      'data': {'order_id': 'translated-order', 'status': 5},
    };
    expect((await sc.submit(c)).state, LiveActionState.succeeded);
    expect(
      jsonDecode(transport.sentBody!['biz_extra'])['trans_key'],
      'test-key',
    );
  });
  test(
    'animation price change, account switch and expiry prevent purchase',
    () async {
      var c = await sc.prepare(
        await select(image: 7, imageGold: 99000),
        account.identity,
      );
      transport.config['customize_dm']['amount'] = 100000;
      expect((await sc.submit(c)).state, LiveActionState.notSubmitted);
      c = await prepare();
      account = LiveGiftAccount(100, FakeLoginIdentity(), 'changed');
      expect((await sc.submit(c)).state, LiveActionState.notSubmitted);
      c = await prepare();
      now = now.add(const Duration(seconds: 61));
      expect((await sc.submit(c)).state, LiveActionState.notSubmitted);
      expect(transport.postCount, 0);
    },
  );
  test(
    'journal failure prevents POST and timeout remains durable unknown',
    () async {
      var c = await prepare();
      journal.failStart = true;
      expect((await sc.submit(c)).state, LiveActionState.notSubmitted);
      expect(transport.postCount, 0);
      journal.failStart = false;
      c = await prepare();
      transport.timeout = true;
      expect((await sc.submit(c)).state, LiveActionState.unknown);
      expect(await gifts.pending(), isNotNull);
      await expectLater(prepare(), throwsA(isA<LiveGiftException>()));
      expect(transport.postCount, 1);
    },
  );
  test(
    'incomplete, wrong amount and unpaid order never claim success',
    () async {
      for (final data in [
        {'order_id': 'a', 'status': 1},
        {'order_id': 'b', 'status': 5, 'pay_gold': 999},
        {'status': 5},
      ]) {
        final c = await prepare();
        transport.response = {'code': 0, 'data': data};
        expect((await sc.submit(c)).state, LiveActionState.unknown);
        await gifts.acknowledgeUnknown(c.operationId);
      }
    },
  );
  test('shared account lock rejects overlapping purchases', () async {
    final c = await prepare();
    LiveGiftService.sendingAccounts.add(account.uid);
    try {
      expect((await sc.submit(c)).state, LiveActionState.notSubmitted);
      expect(transport.postCount, 0);
    } finally {
      LiveGiftService.sendingAccounts.remove(account.uid);
    }
  });
}
