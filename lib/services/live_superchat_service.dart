import 'dart:convert';

import 'package:PiliPlus/models_new/live/live_superchat/purchase.dart';
import 'package:PiliPlus/services/live_gift_service.dart';

class LiveSuperChatService {
  LiveSuperChatService(this.gifts);
  final LiveGiftService gifts;
  static const configPath = '/av/v1/SuperChat/config';
  static const orderPath = '/xlive/revenue/v1/order/createOrder';
  static const imagePath = '/xlive/general-interface/v1/superChat/queryImage';
  static int _nonce = 0;
  bool _disposed = false;
  LiveScConfirmation? _confirmation;
  ({String message, String key, String text, Object identity})? _translation;
  String _journalKey(int uid) => '$uid:${gifts.roomId}:${gifts.anchorUid}';
  Map<String, dynamic> get _room => {
    'room_id': gifts.roomId,
    'ruid': gifts.anchorUid,
    'parent_area_id': gifts.parentAreaId ?? 0,
    'area_id': gifts.areaId ?? 0,
  };

  void _guard(LiveGiftAccount account) {
    final current = gifts.currentAccount();
    if (_disposed ||
        account.uid <= 0 ||
        account.csrf.isEmpty ||
        current.uid != account.uid ||
        current.csrf != account.csrf ||
        !identical(current.identity, account.identity)) {
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
    if (liveInt(response['code']) != 0 || response['data'] is! Map) {
      throw LiveGiftException(
        '${response['message'] ?? response['msg'] ?? '醒目留言数据不可用'}',
      );
    }
    return liveMap(response['data']);
  }

  Future<LiveScConfig> load() async =>
      LiveScConfig(await _get(configPath, _room, gifts.currentAccount()));
  Future<List<LiveScImage>> images() async =>
      LiveScImage.parse(await _get(imagePath, _room, gifts.currentAccount()));
  Future<({String key, String text})> translate(String message) async {
    final account = gifts.currentAccount();
    final config = await load();
    _guard(account);
    if (!config.translation) throw const LiveGiftException('当前直播间不支持中译日');
    final data = await _get('/av/v1/SuperChat/messageTranslate', {
      ..._room,
      'msg': message,
    }, account);
    final key = '${data['trans_skey'] ?? ''}',
        text = '${data['message_trans'] ?? ''}';
    if (key.isEmpty || text.isEmpty) {
      throw const LiveGiftException('未收到有效的翻译结果');
    }
    _translation = (
      message: message,
      key: key,
      text: text,
      identity: account.identity,
    );
    return (key: key, text: text);
  }

  Future<void> _validate(
    LiveScSelection selection,
    LiveGiftAccount account,
  ) async {
    final config = await load();
    _guard(account);
    if (config.banReason.isNotEmpty) throw LiveGiftException(config.banReason);
    final tier = config.tierForGold(selection.gold);
    if (tier == null ||
        !tier.enabled ||
        tier.fingerprint != selection.tier.fingerprint ||
        config.goodsId != selection.goodsId) {
      throw const LiveGiftException('SC 档位、价格或购买权限已变化，请刷新');
    }
    if (selection.gold <= 0 ||
        selection.gold > 100000000 ||
        selection.gold % 1000 != 0 ||
        (!config.customPrice && selection.gold != tier.gold)) {
      throw const LiveGiftException('自定义金额须为 10 电池的整数倍，且不超过平台上限');
    }
    if (selection.message.trim().isEmpty ||
        selection.message.length > tier.limit) {
      throw LiveGiftException('请输入 1 至 ${tier.limit} 字的留言');
    }
    if (selection.translationKey.isNotEmpty) {
      final translated = _translation;
      if (!config.translation ||
          translated == null ||
          translated.message != selection.message ||
          translated.key != selection.translationKey ||
          translated.text != selection.translatedText ||
          !identical(translated.identity, account.identity)) {
        throw const LiveGiftException('原文或账号已变化，请重新翻译');
      }
    }
    if (selection.imageId > 0) {
      if (!config.customAnimation ||
          config.animationGold < 0 ||
          config.animationGold != selection.imageGold) {
        throw const LiveGiftException('定制动画费用或权限已变化，请刷新');
      }
      final items = await images();
      _guard(account);
      if (!items.any((image) => image.id == selection.imageId)) {
        throw const LiveGiftException('定制动画素材已变化，请重新选择');
      }
    } else if (selection.imageGold != 0) {
      throw const LiveGiftException('未选择动画素材');
    }
    final data = await _get(LiveGiftService.walletPath, {
      'room_id': gifts.roomId,
      'not_mock_enter_effect': 1,
    }, account);
    final gold = liveInt(liveMap(data['wallet'])['gold']);
    if (gold == null || gold < selection.totalGold) {
      throw const LiveGiftException('余额不足或暂时无法核验余额');
    }
  }

  Future<LiveScConfirmation> prepare(
    LiveScSelection selection,
    Object identity,
  ) async {
    final account = gifts.currentAccount();
    _guard(account);
    if (!identical(account.identity, identity)) {
      throw const LiveGiftException('账号已变化，请刷新');
    }
    if (await gifts.pending() != null ||
        LiveGiftService.sendingAccounts.contains(account.uid)) {
      throw const LiveGiftException('存在待核对或正在提交的交易，请先核对记录');
    }
    await _validate(selection, account);
    _guard(account);
    return _confirmation = LiveScConfirmation(
      selection,
      account.uid,
      account.identity,
      'sc-${gifts.now().microsecondsSinceEpoch}-${++_nonce}',
      gifts.now().add(const Duration(seconds: 60)),
    );
  }

  void cancel() => _confirmation = null;
  void _check(LiveScConfirmation confirmation, LiveGiftAccount account) {
    _guard(account);
    if (!identical(_confirmation, confirmation) ||
        confirmation.uid != account.uid ||
        !identical(confirmation.identity, account.identity) ||
        !gifts.now().isBefore(confirmation.expiresAt)) {
      throw const LiveGiftException('购买确认已失效，请重新确认');
    }
  }

  Future<LiveGiftResult> submit(LiveScConfirmation confirmation) async {
    final account = gifts.currentAccount();
    final selection = confirmation.selection;
    var locked = false, issued = false;
    Map<String, dynamic>? record;
    try {
      _check(confirmation, account);
      locked = LiveGiftService.sendingAccounts.add(account.uid);
      if (!locked) throw const LiveGiftException('已有操作正在提交');
      await _validate(selection, account);
      _check(confirmation, account);
      final pending = await gifts.pending();
      _check(confirmation, account);
      if (pending != null) throw const LiveGiftException('上次交易结果待核对，请先核对记录');
      record = {
        'state': 'submitting',
        'operation_id': confirmation.operationId,
        'account_uid': account.uid,
        'room_id': gifts.roomId,
        'anchor_uid': gifts.anchorUid,
        'gift_name': '醒目留言 SC',
        'quantity': 1,
        'total_price': selection.totalGold,
        'updated_at': gifts.now().toUtc().toIso8601String(),
      };
      await gifts.journal.write(_journalKey(account.uid), record);
      _check(confirmation, account);
      cancel();
      issued = true;
      final response = await gifts.transport.post(orderPath, {
        'context_id': gifts.roomId,
        'context_type': 1,
        'ruid': gifts.anchorUid,
        'parent_area_id': gifts.parentAreaId ?? 0,
        'area_id': gifts.areaId ?? 0,
        'goods_id': selection.goodsId,
        'goods_num': 1,
        'pay_gold': selection.totalGold,
        'platform': 'pc',
        'mobile_app': '',
        'biz_extra': jsonEncode({
          'msg': selection.message,
          'level': selection.tier.level,
          'biz_id': selection.tier.id,
          'trans_key': selection.translationKey,
          'sc_image_id': selection.imageId,
        }),
        'statistics': jsonEncode({
          'platform': 5,
          'pc_client': 'pcWeb',
          'appId': 100,
        }),
        'csrf': account.csrf,
        'csrf_token': account.csrf,
      }, account);
      final code = liveInt(response['code']), data = liveMap(response['data']);
      final id = '${data['order_id'] ?? ''}', status = liveInt(data['status']);
      final matches =
          id.isNotEmpty &&
          id != '0' &&
          (data['uid'] == null || liveInt(data['uid']) == account.uid) &&
          (data['ruid'] == null || liveInt(data['ruid']) == gifts.anchorUid) &&
          (data['pay_gold'] == null ||
              liveInt(data['pay_gold']) == selection.totalGold);
      final state = code != null && code != 0
          ? LiveActionState.failed
          : code == 0 && matches && {2, 4, 5}.contains(status)
          ? LiveActionState.succeeded
          : LiveActionState.unknown;
      final message = state == LiveActionState.succeeded
          ? status == 4
                ? 'SC 已购买，正在审核（订单 $id）'
                : status == 2
                ? 'SC 已购买，等待平台派发（订单 $id）'
                : 'SC 已购买并派发（订单 $id）'
          : state == LiveActionState.failed
          ? '${response['message'] ?? response['msg'] ?? '平台拒绝了购买请求'}'
          : 'SC 结果待核对，请检查订单和余额，不要重复购买';
      await gifts.journal.write(_journalKey(account.uid), {
        ...record,
        'state': state.name,
        'receipt_id': id,
        'order_status': status,
      });
      return LiveGiftResult(
        state,
        message,
        confirmation.operationId,
        receiptId: matches ? id : null,
      );
    } catch (error) {
      final state = issued
          ? LiveActionState.unknown
          : LiveActionState.notSubmitted;
      if (record != null) {
        try {
          await gifts.journal.write(_journalKey(account.uid), {
            ...record,
            'state': state.name,
          });
        } catch (_) {}
      }
      return LiveGiftResult(
        state,
        issued
            ? 'SC 结果未知，请检查订单和余额，不要重复购买'
            : LiveGiftService.errorMessage(error),
        confirmation.operationId,
      );
    } finally {
      if (locked) LiveGiftService.sendingAccounts.remove(account.uid);
    }
  }

  Future<Map<String, dynamic>> receipt(String orderId) => _get(
    '/av/v1/SuperChat/getMessage',
    {'order_id': orderId},
    gifts.currentAccount(),
  );
  void dispose() {
    _disposed = true;
    _translation = null;
    cancel();
  }
}
