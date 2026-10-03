import 'package:PiliPlus/services/live_gift_service.dart';

import 'live_gift_fakes.dart';

class ActivityTransport extends FakeTransport {
  int fee = 1000;
  String requirement = '全部观众';
  bool batteryDefaults = false;
  Map<String, dynamic> anchor = {
    'id': 90,
    'lot_status': 0,
    'status': 1,
    'time': 300,
    'join_type': 0,
    'require_type': 1,
    'require_text': '关注主播',
    'danmu': '参与测试',
    'award_name': '奖品',
  };
  Map<String, dynamic> red = {
    'lot_id': 80,
    'lot_status': 1,
    'current_time': 1000,
    'end_time': 1300,
    'danmu': '红包测试',
    'rp_type': 1,
  };
  @override
  Future<Map<String, dynamic>> get(
    String path,
    Map<String, dynamic> query,
    LiveGiftAccount account,
  ) async {
    if (path.endsWith('/RedPocketDetail')) {
      final battery = query['rp_type'] == 3;
      return {
        'code': 0,
        'data': {
          if (!batteryDefaults) 'duration_options': [300, 600],
          if (!batteryDefaults)
            'join_requirement_options': [
              {'value': 0, 'text': requirement},
            ],
          if (battery)
            'battery': {
              'grades': [
                {
                  'id': 11,
                  'total_battery': fee,
                  'num_options': [10, 20],
                },
              ],
            }
          else
            'item': [
              {
                'id': 11,
                'gold_num': fee,
                'can': 1,
                'award_total_num': 10,
                'danmu': [
                  {'id': 7, 'danmu': '红包测试'},
                ],
                'award_info': [
                  {'award_id': 1, 'award_num': 10},
                ],
              },
            ],
        },
      };
    }
    if (path.endsWith('/Anchor/Check')) return {'code': 0, 'data': anchor};
    if (path.endsWith('/getLotteryInfoWeb'))
      return {
        'code': 0,
        'data': {
          'popularity_red_pocket': {
            'list': [red],
          },
        },
      };
    return super.get(path, query, account);
  }
}
