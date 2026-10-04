import 'dart:async';

import 'package:PiliPlus/services/live_gift_service.dart';

Map<String, dynamic> giftConfig({int price = 100}) => {
  'id': 10,
  'name': '测试礼物',
  'price': price,
  'coin_type': 'gold',
  'max_send_limit': 99,
  'draw': 0,
  'gift_type': 0,
  'gift_attrs': [0],
  'diy_count_map': 1,
};

class FakeTransport implements LiveGiftTransport {
  int price = 100;
  int balance = 100000;
  int stock = 3;
  int expires = 0;
  int postCount = 0;
  String? sentPath;
  Map<String, dynamic>? sentBody;
  bool timeout = false;
  bool failReads = false;
  bool bagDisabled = false;
  void Function()? onCatalogRead;
  Map<String, dynamic>? response;
  Map<String, dynamic>? catalogData;
  Map<String, dynamic>? fansMedal;
  Map<String, dynamic>? giftMessageData;
  Map<String, dynamic>? lastMedalQuery;
  Completer<void>? postGate;
  final postStarted = Completer<void>();

  @override
  Future<Map<String, dynamic>> get(
    String path,
    Map<String, dynamic> query,
    LiveGiftAccount account,
  ) async {
    if (failReads) throw Exception('offline');
    if (path == LiveGiftService.catalogPath) onCatalogRead?.call();
    if (path == LiveGiftService.medalPath) lastMedalQuery = Map.of(query);
    final data = switch (path) {
      LiveGiftService.catalogPath =>
        catalogData ??
            {
              'gift_config': {
                'base_config': {
                  'list': [giftConfig(price: price)],
                },
              },
              'gift_data': {
                'bag_tab_disable': bagDisabled ? 1 : 0,
                'max_send_gift': 5000,
                'room_gift_list': {
                  'gold_list': [
                    {
                      'gift_id': 10,
                      'special': {'is_use': 1},
                      'gift_scene': {'pay_type': 'send_gift'},
                    },
                  ],
                },
              },
            },
      LiveGiftService.bagPath => {
        'gift_config': [giftConfig(price: price)],
        'list': [
          {
            'type': 1,
            'bag_id': 50,
            'gift_id': 10,
            'gift_num': stock,
            'expire_at': expires,
          },
        ],
      },
      LiveGiftService.walletPath => {
        'wallet': {'gold': balance},
      },
      LiveGiftService.medalPath => giftMessageData ?? {
        'fans_medal_info': {
          'received': fansMedal != null,
          if (fansMedal != null) 'current': fansMedal,
        },
      },
      _ => throw StateError('Unexpected read: $path'),
    };
    return {'code': 0, 'data': data};
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
    LiveGiftAccount account,
  ) async {
    postCount++;
    sentPath = path;
    sentBody = body;
    if (!postStarted.isCompleted) postStarted.complete();
    if (postGate != null) await postGate!.future;
    if (timeout) throw TimeoutException('No response after write');
    return response ??
        {
          'code': 0,
          'data': {
            'uid': account.uid,
            'gift_list': [
              {
                'gift_id': body['gift_id'],
                'gift_num': body['gift_num'],
                'receiver_uinfo': {'uid': body['ruid']},
                'extra': {
                  'wallet': {'order_id': 'test-order-1'},
                },
              },
            ],
          },
        };
  }
}

class FakeJournal implements LiveGiftJournal {
  final records = <String, Map<String, dynamic>>{};
  bool failStart = false;
  bool failFinish = false;
  @override
  Future<Map<String, dynamic>?> read(String key) async => records[key];
  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    if (failStart || (failFinish && value['state'] != 'submitting')) {
      throw Exception('disk full');
    }
    records[key] = {...value};
  }
}

// Deliberately non-const: separate logins must have distinct identities.
class FakeLoginIdentity {
  FakeLoginIdentity();
}
