import 'dart:convert';

import 'package:PiliPlus/models_new/live/gift/live_gift.dart';
import 'package:PiliPlus/models_new/live/gift/live_gift_parser.dart';

export 'package:PiliPlus/models_new/live/gift/live_gift.dart';

/// Gift protocol and confirmation rules adapted from PiliPlus PR #3145.
/// Transport and persistence are injected so transaction tests never send gifts.
class LiveGiftAccount {
  final int uid;
  final Object identity;
  final String csrf;
  const LiveGiftAccount(this.uid, this.identity, this.csrf);
}

abstract interface class LiveGiftTransport {
  Future<Map<String, dynamic>> get(
    String path,
    Map<String, dynamic> query,
    LiveGiftAccount account,
  );
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
    LiveGiftAccount account,
  );
}

/// Contains operation metadata only, never cookies or tokens.
abstract interface class LiveGiftJournal {
  Future<Map<String, dynamic>?> read(String key);
  Future<void> write(String key, Map<String, dynamic> value);
}

class LiveGiftService {
  static const catalogPath = '/xlive/web-room/v1/giftPanel/roomGiftList';
  static const bagPath = '/xlive/web-room/v1/gift/bag_list';
  static const walletPath = '/xlive/web-room/v1/index/getInfoByUser';
  static const medalPath = '/xlive/web-room/v1/giftPanel/giftMessageV2';
  static const sendGoldPath = '/xlive/revenue/v2/gift/sendGoldMultiUser';
  static const sendBagPath = '/xlive/revenue/v2/gift/sendBagMultiUser';

  /// Shared with native red packets and SC so paid writes cannot overlap per account.
  static final Set<int> sendingAccounts = {};
  static int _nonce = 0;

  final int roomId;
  final int anchorUid;
  final int? areaId;
  final int? parentAreaId;
  final LiveGiftTransport transport;
  final LiveGiftJournal journal;
  final LiveGiftAccount Function() currentAccount;
  final DateTime Function() now;
  final Map<String, LiveGiftConfirmation> _confirmations = {};
  bool _disposed = false;

  LiveGiftService({
    required this.roomId,
    required this.anchorUid,
    required this.transport,
    required this.journal,
    required this.currentAccount,
    this.areaId,
    this.parentAreaId,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  String _key(int uid) => '$uid:$roomId:$anchorUid';

  void _guard(LiveGiftAccount account) {
    if (_disposed) throw const LiveGiftException('礼物面板已关闭，请重新打开');
    final current = currentAccount();
    if (current.uid <= 0 || current.csrf.isEmpty) {
      throw const LiveGiftException('请先登录有效账号');
    }
    if (current.uid != account.uid ||
        !identical(current.identity, account.identity) ||
        current.csrf != account.csrf) {
      throw const LiveGiftException('账号已变化，请刷新礼物面板');
    }
    if (roomId <= 0 || anchorUid <= 0) {
      throw const LiveGiftException('房间或主播信息尚未加载');
    }
  }

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, dynamic> query,
    LiveGiftAccount account,
  ) async {
    _guard(account);
    final response = await transport.get(path, query, account);
    _guard(account);
    if (liveInt(response['code']) != 0 || response['data'] is! Map) {
      throw LiveGiftException(response['message']?.toString() ?? '接口数据不可用');
    }
    return liveMap(response['data']);
  }

  Future<LiveGiftSnapshot> loadPanel() async {
    final account = currentAccount();
    _guard(account);
    final errors = <String, String>{};
    Future<Map<String, dynamic>> read(
      String label,
      String path,
      Map<String, dynamic> query,
    ) async {
      try {
        return await _get(path, query, account);
      } catch (error) {
        errors[label] = errorMessage(error);
        return {};
      }
    }

    final data = await Future.wait([
      read('礼物', catalogPath, {
        'room_id': roomId,
        'ruid': anchorUid,
        'platform': 'pc',
        'source': 'live',
        'build': 0,
        if (areaId != null) 'area_id': areaId,
        if (parentAreaId != null) 'area_parent_id': parentAreaId,
      }),
      read('背包', bagPath, {
        'room_id': roomId,
        'mobi_app': 'web',
        't': now().millisecondsSinceEpoch,
      }),
      read('余额', walletPath, {'room_id': roomId, 'not_mock_enter_effect': 1}),
    ]);
    _guard(account);
    final wallet = liveMap(data[2]['wallet']);
    final bagDisabled =
        liveInt(liveMap(data[0]['gift_data'])['bag_tab_disable']) == 1;
    if (bagDisabled) errors['背包'] = '当前直播间不支持背包赠送';
    final gifts = LiveGiftParser.gifts(
      data[0],
      roomId,
      anchorUid,
    ).where((gift) => gift.coinType == 'gold').toList(growable: false);
    LiveGift? medalGift;
    for (final gift in gifts) {
      if (gift.sendable && gift.priceKnown && !gift.isRedPacket) {
        medalGift = gift;
        break;
      }
    }
    LiveMedalProgress? medal;
    if (medalGift != null) {
      // Official gift-panel GET exposes current and projected progress together.
      // Reading this endpoint does not create an order or send the selected gift.
      final detail = await read('粉丝勋章', medalPath, {
        'target_id': anchorUid,
        'room_id': roomId,
        'price': medalGift.price,
        'coin_type': medalGift.coinType,
        'gift_id': medalGift.id,
        'gift_type': 0,
        'platform': 'pc',
        'anchor_guest': '',
      });
      _guard(account);
      medal = LiveMedalProgress.fromGiftMessage(detail, anchorUid);
    }
    return LiveGiftSnapshot(
      accountIdentity: account.identity,
      accountUid: account.uid,
      gifts: gifts,
      groups: LiveGiftParser.groups(data[0]),
      bag: bagDisabled
          ? const []
          : LiveGiftParser.bag(data[1], roomId, anchorUid, now()),
      wallet: LiveWallet(gold: liveInt(wallet['gold'])),
      medal: medal,
      errors: errors,
    );
  }

  Future<LiveGiftResult?> pending() async {
    final account = currentAccount();
    _guard(account);
    final record = await journal.read(_key(account.uid));
    _guard(account);
    if (record == null || record['acknowledged'] == true) return null;
    final state = record['state'];
    if (state != 'submitting' && state != 'unknown') return null;
    return LiveGiftResult(
      sendingAccounts.contains(account.uid)
          ? LiveActionState.submitting
          : LiveActionState.unknown,
      '上次操作 ${record['gift_name']} × ${record['quantity']} 结果尚未确认。'
      '请核对官方礼物／红包／SC 记录、背包和余额，不要直接重发。',
      record['operation_id']?.toString() ?? '',
    );
  }

  Future<void> _ensureNoPending(LiveGiftAccount account) async {
    if (sendingAccounts.contains(account.uid) || await pending() != null) {
      throw const LiveGiftException('已有正在提交或结果待核对的礼物');
    }
    _guard(account);
  }

  /// Explicit acknowledgement unlocks future gifts; it does not mark success.
  Future<void> acknowledgeUnknown(String operationId) async {
    final account = currentAccount();
    _guard(account);
    final record = await journal.read(_key(account.uid));
    _guard(account);
    if (sendingAccounts.contains(account.uid) ||
        record == null ||
        record['operation_id'] != operationId ||
        !{'unknown', 'submitting'}.contains(record['state'])) {
      throw const LiveGiftException('操作状态已变化，请刷新');
    }
    await journal.write(_key(account.uid), {...record, 'acknowledged': true});
  }

  Future<LiveGiftConfirmation> prepare(
    LiveGift gift,
    int quantity, {
    LiveBagItem? bagItem,
    required Object expectedAccountIdentity,
  }) async {
    final account = currentAccount();
    _guard(account);
    if (!identical(expectedAccountIdentity, account.identity)) {
      throw const LiveGiftException('账号已变化，请刷新后重新选择');
    }
    await _ensureNoPending(account);
    final snapshot = await loadPanel();
    _guard(account);
    final (fresh, bag) = _validate(snapshot, gift.id, quantity, bagItem?.bagId);
    final confirmation = LiveGiftConfirmation(
      gift: fresh,
      quantity: quantity,
      bagItem: bag,
      accountUid: account.uid,
      accountIdentity: account.identity,
      roomId: roomId,
      anchorUid: anchorUid,
      expiresAt: now().add(const Duration(seconds: 60)),
      operationId: '${now().microsecondsSinceEpoch}-${++_nonce}',
    );
    _confirmations.clear();
    _confirmations[confirmation.operationId] = confirmation;
    return confirmation;
  }

  (LiveGift, LiveBagItem?) _validate(
    LiveGiftSnapshot snapshot,
    int giftId,
    int quantity,
    int? bagId,
  ) {
    LiveBagItem? bag;
    LiveGift? gift;
    if (bagId != null) {
      bag = snapshot.bag
          .where((item) => item.bagId == bagId && item.giftId == giftId)
          .firstOrNull;
      if (bag == null || !bag.available || quantity > bag.quantity) {
        throw const LiveGiftException('背包库存或有效期已变化，请刷新');
      }
      gift = bag.gift;
    } else {
      gift = snapshot.gifts.where((item) => item.id == giftId).firstOrNull;
    }
    if (gift == null ||
        !gift.sendable ||
        gift.isRedPacket ||
        gift.id == 13000) {
      throw LiveGiftException(gift?.unavailableReason ?? '礼物已下架或不可用');
    }
    if (quantity < 1 || quantity > gift.maxQuantity || quantity > 5000) {
      throw const LiveGiftException('数量超过当前允许范围');
    }
    if (gift.allowedQuantities case final allowed?
        when !allowed.contains(quantity)) {
      throw LiveGiftException('此礼物支持的数量：${allowed.join('、')}');
    }
    if (bag == null) {
      final balance = snapshot.wallet.gold;
      if (gift.coinType != 'gold' || balance == null) {
        throw const LiveGiftException('无法核验电池价格或余额，请刷新');
      }
      if (balance < gift.price * quantity) {
        throw const LiveGiftException('电池余额不足，请在官方渠道充值');
      }
    }
    return (gift, bag);
  }

  void cancelConfirmation() => _confirmations.clear();

  void _guardConfirmation(LiveGiftAccount account, LiveGiftConfirmation value) {
    _guard(account);
    if (!identical(_confirmations[value.operationId], value) ||
        !identical(value.accountIdentity, account.identity) ||
        value.accountUid != account.uid ||
        value.roomId != roomId ||
        value.anchorUid != anchorUid ||
        !now().isBefore(value.expiresAt)) {
      throw const LiveGiftException('确认已失效或已提交，请重新确认');
    }
  }

  Future<LiveGiftResult> submit(LiveGiftConfirmation value) async {
    final account = currentAccount();
    var locked = false;
    var issued = false;
    Map<String, dynamic>? record;
    try {
      _guardConfirmation(account, value);
      await _ensureNoPending(account);
      final snapshot = await loadPanel();
      _guardConfirmation(account, value);
      final (fresh, _) = _validate(
        snapshot,
        value.gift.id,
        value.quantity,
        value.bagItem?.bagId,
      );
      if (fresh.price != value.gift.price ||
          fresh.coinType != value.gift.coinType) {
        throw const LiveGiftException('礼物价格已变化，请重新确认');
      }
      locked = sendingAccounts.add(account.uid);
      if (!locked) throw const LiveGiftException('正在提交礼物，请等待');
      // Another panel may have completed with an unknown result while the
      // catalogue was being refreshed. Check again under the account lock.
      final latest = await journal.read(_key(account.uid));
      _guardConfirmation(account, value);
      if (latest != null &&
          latest['acknowledged'] != true &&
          {'submitting', 'unknown'}.contains(latest['state'])) {
        throw const LiveGiftException('已有送礼结果待核对，请先核对官方记录');
      }
      record = {
        'state': 'submitting',
        'operation_id': value.operationId,
        'account_uid': account.uid,
        'room_id': roomId,
        'anchor_uid': anchorUid,
        'gift_id': value.gift.id,
        'gift_name': value.gift.name,
        'quantity': value.quantity,
        'total_price': value.totalPrice,
        'bag_id': value.bagItem?.bagId,
        'updated_at': now().toUtc().toIso8601String(),
      };
      // Flush the marker before sending, so a crash cannot invite an auto replay.
      await journal.write(_key(account.uid), record);
      _guardConfirmation(account, value);
      _confirmations.remove(value.operationId);
      issued = true;
      final response = await transport.post(
        value.bagItem == null ? sendGoldPath : sendBagPath,
        requestBody(value, account.csrf),
        account,
      );
      final code = liveInt(response['code']);
      final receipt = code == 0
          ? LiveGiftParser.giftReceipt(liveMap(response['data']), value)
          : null;
      final result = code != null && code != 0
          ? LiveGiftResult(
              LiveActionState.failed,
              response['message']?.toString() ?? '服务器拒绝送礼（$code）',
              value.operationId,
            )
          : receipt != null
          ? LiveGiftResult(
              LiveActionState.succeeded,
              '赠送成功',
              value.operationId,
              receiptId: receipt,
            )
          : LiveGiftResult(
              LiveActionState.unknown,
              '已提交但未取得匹配的送礼回执，请核对官方记录，不要重发',
              value.operationId,
            );
      await journal.write(_key(account.uid), {
        ...record,
        'state': result.state.name,
        'receipt_id': receipt,
      });
      return result;
    } catch (error) {
      final result = LiveGiftResult(
        issued ? LiveActionState.unknown : LiveActionState.notSubmitted,
        issued ? '送礼结果未知，请核对官方记录、背包和余额，不要重发' : errorMessage(error),
        value.operationId,
      );
      if (record != null) {
        try {
          await journal.write(_key(account.uid), {
            ...record,
            'state': result.state.name,
          });
        } catch (_) {
          // A previously durable submitting record continues to block retries.
        }
      }
      return result;
    } finally {
      if (locked) sendingAccounts.remove(account.uid);
    }
  }

  static Map<String, dynamic> requestBody(
    LiveGiftConfirmation value,
    String csrf,
  ) => {
    'uid': value.accountUid,
    'gift_id': value.gift.id,
    'ruid': value.anchorUid,
    'send_ruid': value.anchorUid,
    'gift_num': value.quantity,
    'coin_type': value.gift.coinType,
    if (value.bagItem != null) 'bag_id': value.bagItem!.bagId,
    'platform': 'pc',
    'biz_code': 'Live',
    'biz_id': value.roomId,
    'price': value.bagItem == null ? value.gift.price : 0,
    'receive_users': jsonEncode([
      {'uid': value.anchorUid},
    ]),
    'statistics': jsonEncode({
      'platform': 5,
      'pc_client': 'pcWeb',
      'appId': 100,
    }),
    'live_statistics': jsonEncode({'pc_client': 'pcWeb', 'source_event': 0}),
    'web_location': '444.8',
    'csrf': csrf,
    'csrf_token': csrf,
  };

  static String errorMessage(Object error) =>
      error is LiveGiftException ? error.message : '读取或保存礼物信息失败，请稍后刷新';

  void dispose() {
    _disposed = true;
    cancelConfirmation();
  }
}
