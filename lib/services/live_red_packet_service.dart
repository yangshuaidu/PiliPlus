import 'dart:convert';

import 'package:PiliPlus/models_new/live/gift/live_red_packet.dart';
import 'package:PiliPlus/services/live_gift_service.dart';

class LiveRedPacketService {
  LiveRedPacketService(this.gifts);
  final LiveGiftService gifts;
  static const prefix = '/xlive/lottery-interface/v1/popularityRedPocket';
  static int _nonce = 0;
  LiveRedPacketConfirmation? _confirmation;
  bool _disposed = false;
  String _key(int uid) => '$uid:${gifts.roomId}:${gifts.anchorUid}';

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
        '${response['message'] ?? response['msg'] ?? '红包数据不可用'}',
      );
    }
    return liveMap(response['data']);
  }

  Future<LiveRedPacketConfig> load(LiveRedPacketType type) async {
    final account = gifts.currentAccount();
    final data = await _get('$prefix/RedPocketDetail', {
      'room_id': gifts.roomId,
      'ruid': gifts.anchorUid,
      'platform': 'pc',
      'rp_type': type.id,
    }, account);
    return LiveRedPacketConfig.parse(type, data);
  }

  Future<Map<String, dynamic>> history(LiveRedPacketType type, int page) =>
      _get('$prefix/RedPocketHistory', {
        'page': page,
        'page_size': 20,
        'rp_type': type.id,
      }, gifts.currentAccount());

  Future<String> rules() async =>
      '${(await _get('/xlive/general-interface/v1/reward/GetDocContent', {'id': 3136}, gifts.currentAccount()))['content'] ?? ''}';

  Future<void> _validate(
    LiveRedPacketSelection selection,
    LiveGiftAccount account,
  ) async {
    final config = await load(selection.type);
    _guard(account);
    final fresh = config.packages
        .where((p) => p.id == selection.package.id)
        .firstOrNull;
    if (fresh == null ||
        !fresh.enabled ||
        fresh.fingerprint != selection.package.fingerprint ||
        !config.durations.contains(selection.duration)) {
      throw const LiveGiftException('红包套餐、价格或时长已变化，请刷新后重新选择');
    }
    if (selection.type == LiveRedPacketType.battery &&
        (!fresh.counts.contains(selection.count) ||
            !config.requirements.containsKey(selection.requirement) ||
            config.requirements[selection.requirement] !=
                selection.requirementText)) {
      throw const LiveGiftException('红包数量或参与条件不可用');
    }
    if (selection.danmakuText.isNotEmpty &&
        !fresh.danmaku.any(
          (d) => d.id == selection.danmakuId && d.text == selection.danmakuText,
        )) {
      throw const LiveGiftException('红包附带弹幕已变化，请刷新');
    }
    if (fresh.danmaku.isNotEmpty && selection.danmakuText.isEmpty) {
      throw const LiveGiftException('请选择红包附带弹幕');
    }
    final wallet = await _get(LiveGiftService.walletPath, {
      'room_id': gifts.roomId,
      'not_mock_enter_effect': 1,
    }, account);
    final gold = liveInt(liveMap(wallet['wallet'])['gold']);
    if (gold == null || gold < fresh.price) {
      throw const LiveGiftException('余额不足或暂时无法核验余额');
    }
  }

  Future<LiveRedPacketConfirmation> prepare(
    LiveRedPacketSelection selection,
    Object identity,
  ) async {
    final account = gifts.currentAccount();
    _guard(account);
    if (!identical(identity, account.identity)) {
      throw const LiveGiftException('账号已变化，请刷新');
    }
    if (await gifts.pending() != null ||
        LiveGiftService.sendingAccounts.contains(account.uid)) {
      throw const LiveGiftException('存在提交中或结果待核对的操作，请先核对官方记录');
    }
    await _validate(selection, account);
    _guard(account);
    return _confirmation = LiveRedPacketConfirmation(
      selection,
      account.uid,
      account.identity,
      'red-${gifts.now().microsecondsSinceEpoch}-${++_nonce}',
      gifts.now().add(const Duration(seconds: 60)),
    );
  }

  void cancel() => _confirmation = null;
  void _check(LiveRedPacketConfirmation confirmation, LiveGiftAccount account) {
    _guard(account);
    if (!identical(_confirmation, confirmation) ||
        !identical(confirmation.identity, account.identity) ||
        confirmation.uid != account.uid ||
        !gifts.now().isBefore(confirmation.expiresAt)) {
      throw const LiveGiftException('红包确认已失效，请重新确认');
    }
  }

  Future<LiveGiftResult> submit(LiveRedPacketConfirmation confirmation) async {
    final account = gifts.currentAccount();
    var locked = false;
    var issued = false;
    Map<String, dynamic>? record;
    final selection = confirmation.selection;
    try {
      _check(confirmation, account);
      await _validate(selection, account);
      _check(confirmation, account);
      locked = LiveGiftService.sendingAccounts.add(account.uid);
      if (!locked) throw const LiveGiftException('已有操作正在提交');
      final latest = await gifts.journal.read(_key(account.uid));
      _check(confirmation, account);
      if (latest != null &&
          latest['acknowledged'] != true &&
          {'submitting', 'unknown'}.contains(latest['state'])) {
        throw const LiveGiftException('上次操作结果待核对，请先核对官方记录');
      }
      record = {
        'state': 'submitting',
        'operation_id': confirmation.operationId,
        'account_uid': account.uid,
        'room_id': gifts.roomId,
        'anchor_uid': gifts.anchorUid,
        'gift_name': selection.type.label,
        'quantity': 1,
        'total_price': selection.package.price,
        'rp_type': selection.type.id,
        'updated_at': gifts.now().toUtc().toIso8601String(),
      };
      await gifts.journal.write(_key(account.uid), record);
      _check(confirmation, account);
      cancel();
      issued = true;
      final response = await gifts.transport.post('$prefix/SendRedPocket', {
        'ruid': gifts.anchorUid,
        'room_id': gifts.roomId,
        'red_pocket_id': selection.type == LiveRedPacketType.battery
            ? 0
            : selection.package.id,
        'danmu_id': selection.danmakuId,
        'danmu_msg': selection.danmakuText,
        'context_type': 1,
        'context_id': gifts.roomId,
        'parent_area_id': gifts.parentAreaId ?? 0,
        'area_id': gifts.areaId ?? 0,
        'platform': 'pc',
        'mobile_app': '',
        'build': '0',
        'statistics': jsonEncode({
          'platform': 5,
          'pc_client': 'pcWeb',
          'appId': 100,
        }),
        'duration': selection.duration,
        if (selection.type == LiveRedPacketType.battery)
          'battery_info': jsonEncode({
            'total_battery': selection.package.price,
            'award_num': selection.count,
            'join_requirement': selection.requirement,
          }),
        'csrf': account.csrf,
        'csrf_token': account.csrf,
      }, account);
      final code = liveInt(response['code']);
      final lot = liveMap(liveMap(response['data'])['lot_info']);
      final lotId = liveInt(lot['lot_id']);
      final receiptMatches =
          lotId != null &&
          lotId > 0 &&
          (lot['room_id'] == null || liveInt(lot['room_id']) == gifts.roomId) &&
          (lot['sender_uid'] == null ||
              liveInt(lot['sender_uid']) == account.uid);
      final state = code != null && code != 0
          ? LiveActionState.failed
          : code == 0 && receiptMatches
          ? LiveActionState.succeeded
          : LiveActionState.unknown;
      final result = LiveGiftResult(
        state,
        state == LiveActionState.succeeded
            ? '红包已发出（编号 $lotId）'
            : state == LiveActionState.failed
            ? '${response['message'] ?? response['msg'] ?? '服务器拒绝红包'}'
            : '红包结果未知，请核对红包记录和余额，不要重发',
        confirmation.operationId,
        receiptId: receiptMatches ? '$lotId' : null,
      );
      await gifts.journal.write(_key(account.uid), {
        ...record,
        'state': state.name,
        'receipt_id': result.receiptId,
      });
      return result;
    } catch (error) {
      final result = LiveGiftResult(
        issued ? LiveActionState.unknown : LiveActionState.notSubmitted,
        issued ? '红包结果未知，请核对红包记录和余额，不要重发' : LiveGiftService.errorMessage(error),
        confirmation.operationId,
      );
      if (record != null) {
        try {
          await gifts.journal.write(_key(account.uid), {
            ...record,
            'state': result.state.name,
          });
        } catch (_) {}
      }
      return result;
    } finally {
      if (locked) LiveGiftService.sendingAccounts.remove(account.uid);
    }
  }

  void dispose() {
    _disposed = true;
    cancel();
  }
}
