import 'package:PiliPlus/services/live_gift_service.dart';
import 'package:PiliPlus/services/live_superchat_service.dart';

import 'live_gift_fakes.dart';

class ScTransport extends FakeTransport {
  Map<String, dynamic> config = {
    'goods_id': 12,
    'custom_gold': true,
    'trans_status': 1,
    'user_ban_info': {'limited': false},
    'price_configs': [
      {
        'id': 1,
        'level': 0,
        'price': 2,
        'second': 5,
        'limit': 50,
        'type_detail': {'can_buy': true, 'button_text': '限一次'},
      },
      {'id': 2, 'level': 1, 'price': 30, 'second': 60, 'limit': 50},
    ],
    'customize_dm': {'switch': 1, 'amount': 99000},
  };
  bool readImage = false;
  void Function()? onConfig;
  @override
  Future<Map<String, dynamic>> get(
    String path,
    Map<String, dynamic> query,
    LiveGiftAccount account,
  ) async {
    if (path == LiveSuperChatService.configPath) {
      onConfig?.call();
      return {'code': 0, 'data': config};
    }
    if (path == LiveSuperChatService.imagePath) {
      readImage = true;
      return {
        'code': 0,
        'data': {
          'list': [
            {'id': 7, 'origin_url': 'https://example.com/animation.gif'},
          ],
        },
      };
    }
    if (path.endsWith('/messageTranslate'))
      return {
        'code': 0,
        'data': {'trans_skey': 'test-key', 'message_trans': 'こんにちは'},
      };
    return super.get(path, query, account);
  }
}
