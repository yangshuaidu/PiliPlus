import 'dart:convert';

import 'package:PiliPlus/models_new/live/live_activity.dart';
import 'package:PiliPlus/services/live_gift_service.dart';

class LiveActivityConfirmation {
  LiveActivityConfirmation(this.activity, this.account, this.expiresAt);
  final LiveActivity activity;
  final LiveGiftAccount account;
  final DateTime expiresAt;
}

/// Manual, free participation only. The transport has no automatic write retry.
class LiveActivityService {
  LiveActivityService(this.gifts);
  final LiveGiftService gifts;
  static const lottery = '/xlive/lottery-interface/v1';
  LiveActivityConfirmation? _confirmation;
  bool _disposed = false;
  void _guard(LiveGiftAccount account) {
    final current = gifts.currentAccount();
    if (_disposed ||
        account.uid <= 0 ||
        account.csrf.isEmpty ||
        !identical(current.identity, account.identity) ||
        current.uid != account.uid ||
        current.csrf != account.csrf) {
      throw const LiveGiftException('账号已变化或面板已关闭，请重新打开');
    }
  }

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, dynamic> query,
    LiveGiftAccount account,
  ) async {
    _guard(account);
    final response = await gifts.transport.get(path, query, account);
    _guard(account);
    if (liveInt(response['code']) != 0)
      throw LiveGiftException(
        '${response['message'] ?? response['msg'] ?? '活动信息不可用'}',
      );
    return liveMap(response['data']);
  }

  Future<LiveActivity> _fresh(
    LiveActivity activity,
    LiveGiftAccount account,
  ) async {
    if (activity.isRed) {
      final data = await _get('$lottery/lottery/getLotteryInfoWeb', {
        'roomid': gifts.roomId,
        'need_guard': true,
      }, account);
      final fresh = LiveActivity.redPackets(
        data['popularity_red_pocket'],
        gifts.now(),
      ).where((a) => a.id == activity.id).firstOrNull;
      if (fresh != null) return fresh;
    } else {
      final data = await _get('$lottery/Anchor/Check', {
        'roomid': gifts.roomId,
      }, account);
      final fresh = LiveActivity(LiveActivityKind.anchor, data, gifts.now());
      if (fresh.id == activity.id) return fresh;
    }
    throw const LiveGiftException('活动已结束或信息已变化，请刷新');
  }

  void _validate(LiveActivity activity) {
    if (!activity.freeSupported || activity.paid)
      throw const LiveGiftException('该活动需要付费或额外任务，请使用官方天选页面');
    if (!activity.active(gifts.now()) || activity.joined)
      throw const LiveGiftException('活动已结束或已经参与');
  }

  String _key(LiveActivity activity, int uid) =>
      'activity:$uid:${gifts.roomId}:${activity.key}';
  Future<LiveActivityConfirmation> prepare(LiveActivity activity) async {
    final account = gifts.currentAccount();
    final fresh = await _fresh(activity, account);
    _validate(fresh);
    final record = await gifts.journal.read(_key(fresh, account.uid));
    _guard(account);
    if (record != null &&
        record['state'] != 'failed' &&
        record['state'] != 'notSubmitted') {
      throw const LiveGiftException('该活动已提交过，请刷新参与状态或查看结果，避免重复提交');
    }
    return _confirmation = LiveActivityConfirmation(
      fresh,
      account,
      gifts.now().add(const Duration(seconds: 30)),
    );
  }

  void cancel() => _confirmation = null;
  Future<String> submit(LiveActivityConfirmation confirmation) async {
    final account = confirmation.account;
    void check() {
      _guard(account);
      if (!identical(_confirmation, confirmation) ||
          !gifts.now().isBefore(confirmation.expiresAt))
        throw const LiveGiftException('确认已失效，请重新确认');
    }

    check();
    final fresh = await _fresh(confirmation.activity, account);
    check();
    _validate(fresh);
    if (fresh.consentFingerprint != confirmation.activity.consentFingerprint)
      throw const LiveGiftException('参与条件已变化，请重新确认');
    if (!LiveGiftService.sendingAccounts.add(account.uid))
      throw const LiveGiftException('已有操作正在提交');
    var issued = false, staged = false;
    final key = _key(fresh, account.uid);
    try {
      final record = await gifts.journal.read(key);
      check();
      if (record != null &&
          !{'failed', 'notSubmitted'}.contains(record['state']))
        throw const LiveGiftException('该活动已提交，请查看结果');
      await gifts.journal.write(key, {
        'state': 'submitting',
        'activity': fresh.key,
      });
      staged = true;
      check();
      cancel();
      issued = true;
      final response = await gifts.transport.post(
        fresh.isRed
            ? '$lottery/popularityRedPocket/RedPocketDraw'
            : '$lottery/Anchor/Join',
        {
          if (fresh.isRed) ...{
            'ruid': gifts.anchorUid,
            'lot_id': fresh.id,
            'jump_from': '',
          } else ...{
            'id': fresh.id,
            'platform': 'pc',
            'jump_from_str': '',
            'live_statistics': jsonEncode({
              'pc_client': 'pcWeb',
              'jumpfrom': '-99998',
              'room_category': '0',
              'lottery_id': fresh.id,
              'lottery_type': 1,
              'trackid': '-99998',
            }),
          },
          'room_id': gifts.roomId,
          'session_id': '',
          'spm_id': fresh.isRed
              ? '444.8.red_envelope.extract'
              : '444.8.interaction.anchor_draw_auto',
          'csrf': account.csrf,
          'csrf_token': account.csrf,
        },
        account,
      );
      final code = liveInt(response['code']);
      final success = code == 0 || (!fresh.isRed && code == 9100001);
      await gifts.journal.write(key, {
        'state': success
            ? 'succeeded'
            : code == null
            ? 'unknown'
            : 'failed',
        'activity': fresh.key,
      });
      return success
          ? '平台已接受参与，请等待开奖'
          : code == null
          ? '结果未知，请刷新活动状态，不要重复提交'
          : '${response['message'] ?? response['msg'] ?? '参与失败，请核对资格'}';
    } catch (error) {
      if (issued) {
        try {
          await gifts.journal.write(key, {
            'state': 'unknown',
            'activity': fresh.key,
          });
        } catch (_) {}
        return '结果未知，请刷新活动状态，不要重复提交';
      }
      if (staged) {
        try {
          await gifts.journal.write(key, {
            'state': 'notSubmitted',
            'activity': fresh.key,
          });
        } catch (_) {}
      }
      rethrow;
    } finally {
      LiveGiftService.sendingAccounts.remove(account.uid);
    }
  }

  Future<LiveActivity> results(LiveActivity activity) async {
    final account = gifts.currentAccount();
    if (!activity.isRed) return _fresh(activity, account);
    final data = await _get(
      '$lottery/popularityRedPocket/RedPocketGetWinners',
      {'lot_id': activity.id, 'write_off_only': false},
      account,
    );
    return LiveActivity(activity.kind, {
      ...activity.data,
      ...data,
    }, gifts.now());
  }

  void dispose() {
    _disposed = true;
    cancel();
  }
}
