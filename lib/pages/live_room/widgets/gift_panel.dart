import 'package:PiliPlus/pages/live_room/widgets/live_panel_surface.dart';
import 'package:PiliPlus/services/live_gift_service.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

class LiveGiftPanel extends StatefulWidget {
  final LiveGiftService service;
  final String anchorName;
  final VoidCallback? onRecharge;
  final Future<void> Function()? onRedPacket;
  const LiveGiftPanel({
    super.key,
    required this.service,
    required this.anchorName,
    this.onRecharge,
    this.onRedPacket,
  });
  @override
  State<LiveGiftPanel> createState() => _LiveGiftPanelState();
}

class _LiveGiftPanelState extends State<LiveGiftPanel> {
  final _quantity = TextEditingController(text: '1');
  LiveGiftSnapshot? _snapshot;
  LiveGift? _selected;
  LiveBagItem? _bagItem;
  LiveGiftResult? _pending;
  bool _bag = false;
  String? _groupId = 'room';
  bool _priceDescending = false;
  bool _busy = false;
  bool _confirming = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    widget.service.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _load({String? message}) async {
    setState(() {
      _busy = true;
      _message = message;
    });
    try {
      final snapshot = await widget.service.loadPanel();
      final pending = await widget.service.pending();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        if (!snapshot.groups.any((group) => group.id == _groupId)) {
          _groupId = 'room';
        }
        _pending = pending;
        _selected = null;
        _bagItem = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _snapshot = null;
        _message = LiveGiftService.errorMessage(error);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final gift = _selected;
    final snapshot = _snapshot;
    if (_busy || gift == null || snapshot == null) return;
    final count = int.tryParse(_quantity.text);
    if (count == null || count < 1 || count > gift.maxQuantity) {
      setState(() => _message = '请输入 1–${gift.maxQuantity} 的整数数量');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    String? outcome;
    try {
      final confirmation = await widget.service.prepare(
        gift,
        count,
        bagItem: _bagItem,
        expectedAccountIdentity: snapshot.accountIdentity,
      );
      if (!mounted) return;
      setState(() => _confirming = true);
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认赠送礼物'),
          content: SingleChildScrollView(
            child: Text(
              '账号 UID：${confirmation.accountUid}\n'
              '主播：${widget.anchorName}（UID ${confirmation.anchorUid}）\n'
              '直播间：${confirmation.roomId}\n\n'
              '${confirmation.gift.name} × ${confirmation.quantity}\n'
              '${confirmation.bagItem == null ? '单价：${confirmation.gift.displayPrice} 电池\n合计：${confirmation.displayTotalPrice} 电池' : '使用背包库存：${confirmation.quantity} 个\n电池费用：0'}\n\n'
              '赠送后无法撤回。请核对主播、数量和费用。',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认赠送'),
            ),
          ],
        ),
      );
      if (mounted) setState(() => _confirming = false);
      if (!mounted || approved != true) {
        widget.service.cancelConfirmation();
        return;
      }
      final result = await widget.service.submit(confirmation);
      // A result from a previous account must not appear in the new account UI.
      if (!mounted) return;
      outcome =
          identical(
            widget.service.currentAccount().identity,
            confirmation.accountIdentity,
          )
          ? result.message
          : '账号已变化，送礼结果保留在原账号，请切回后核对';
    } catch (error) {
      outcome = LiveGiftService.errorMessage(error);
    } finally {
      if (mounted) {
        _confirming = false;
        if (outcome != null) {
          await _load(message: outcome);
        } else {
          setState(() => _busy = false);
        }
      }
    }
  }

  Future<void> _acknowledge() async {
    final pending = _pending;
    if (_busy || pending == null) return;
    final identity = widget.service.currentAccount().identity;
    setState(() => _busy = true);
    try {
      setState(() => _confirming = true);
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('已核对官方记录？'),
          content: const Text(
            '请先核对官方送礼记录、红包记录、背包和余额。解除后可以发起新的赠送；这不会重发上次操作，也不会把未知结果标记为成功。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('尚未核对'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('我已核对，解除限制'),
            ),
          ],
        ),
      );
      if (mounted) setState(() => _confirming = false);
      if (!mounted || approved != true) return;
      if (!identical(identity, widget.service.currentAccount().identity)) {
        throw const LiveGiftException('账号已变化，请重新核对');
      }
      await widget.service.acknowledgeUnknown(pending.operationId);
      if (mounted) await _load(message: '已解除限制，上次送礼结果仍保留为未知');
    } catch (error) {
      if (mounted) {
        setState(() => _message = LiveGiftService.errorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _confirming = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final gifts = snapshot?.gifts ?? <LiveGift>[];
    final groups = [
      for (final group in snapshot?.groups ?? <LiveGiftGroup>[])
        if (group.id == 'room' ||
            gifts.any((gift) => group.giftIds.contains(gift.id)))
          group,
    ];
    final selectedGroup =
        groups.where((g) => g.id == _groupId).firstOrNull ??
        groups.where((g) => g.id == 'room').firstOrNull;
    // The room list and each official tab are distinct catalogues. A null
    // selection must never turn the default tab into their combined union.
    final entries = _bag
        ? [
            for (final item in snapshot?.bag ?? <LiveBagItem>[])
              (item.gift, item),
          ]
        : [
            for (final gift in gifts)
              if (selectedGroup?.giftIds.contains(gift.id) == true)
                (gift, null),
          ];
    if (!_bag) {
      final order = {for (final (i, gift) in gifts.indexed) gift.id: i};
      entries.sort((a, b) {
        if (a.$1.priceKnown != b.$1.priceKnown) return a.$1.priceKnown ? -1 : 1;
        final price = a.$1.price.compareTo(b.$1.price);
        return price != 0
            ? (_priceDescending ? -price : price)
            : order[a.$1.id]!.compareTo(order[b.$1.id]!);
      });
    }
    return PopScope(
      canPop: !_busy,
      child: LivePanelSurface(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '赠送礼物',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  PopupMenuButton<bool>(
                    tooltip: '按电池价格排序',
                    enabled: !_busy && !_bag,
                    initialValue: _priceDescending,
                    onSelected: (value) =>
                        setState(() => _priceDescending = value),
                    icon: const Icon(Icons.swap_vert, size: 20),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: false, child: Text('价格从低到高')),
                      PopupMenuItem(value: true, child: Text('价格从高到低')),
                    ],
                  ),
                  IconButton(
                    tooltip: '刷新礼物',
                    onPressed: _busy ? null : _load,
                    icon: const Icon(Icons.refresh, size: 20),
                  ),
                  IconButton(
                    tooltip: '关闭礼物',
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 32 + MediaQuery.textScalerOf(context).scale(14),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    for (final group in groups)
                      _tab(
                        group.id == 'room' ? '礼物' : group.name,
                        !_bag && selectedGroup?.id == group.id,
                        () => _selectGroup(group.id),
                      ),
                    _tab(
                      '包裹',
                      _bag,
                      () => setState(() {
                        _bag = true;
                        _selected = null;
                        _bagItem = null;
                        _message = null;
                      }),
                    ),
                  ],
                ),
              ),
            ),
            if (_busy && !_confirming)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
                  final columns = scale > 1.4 ? 3 : 4;
                  return CustomScrollView(
                    key: ValueKey(
                      'gift-scroll-${_bag ? 'bag' : selectedGroup?.id}',
                    ),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_message != null)
                                Text(
                                  _message!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              if (_pending case final pending?) ...[
                                Text(
                                  pending.message,
                                  style: const TextStyle(height: 1.4),
                                ),
                                TextButton(
                                  onPressed:
                                      _busy ||
                                          pending.state ==
                                              LiveActionState.submitting
                                      ? null
                                      : _acknowledge,
                                  child: const Text('已核对官方记录'),
                                ),
                              ],
                              for (final error
                                  in snapshot?.errors.entries ??
                                      <MapEntry<String, String>>[])
                                Text(
                                  '${error.key}：${error.value}',
                                  style: const TextStyle(
                                    color: Colors.orangeAccent,
                                    height: 1.4,
                                  ),
                                ),
                              if (snapshot != null && entries.isEmpty && !_busy)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 24,
                                  ),
                                  child: Text(
                                    snapshot.errors.containsKey(
                                          _bag ? '背包' : '礼物',
                                        )
                                        ? '加载失败，请刷新重试'
                                        : _bag
                                        ? '包裹暂无礼物'
                                        : '当前分类暂无礼物',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        sliver: SliverGrid.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisExtent: 68 + 34 * scale,
                                crossAxisSpacing: 4,
                                mainAxisSpacing: 4,
                              ),
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final (gift, bag) = entries[index];
                            final available = bag?.available ?? gift.sendable;
                            final selected =
                                identical(_selected, gift) &&
                                identical(_bagItem, bag);
                            return Material(
                              key: ValueKey(
                                'live-gift-${gift.id}-${bag?.bagId ?? 0}',
                              ),
                              color: selected
                                  ? liveAccent.withValues(alpha: .16)
                                  : Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: selected
                                      ? liveAccent
                                      : Colors.transparent,
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: _busy
                                    ? null
                                    : () {
                                        if (gift.isRedPacket &&
                                            widget.onRedPacket != null) {
                                          _openRedPacket();
                                        } else if (!available) {
                                          setState(() {
                                            _selected = gift;
                                            _bagItem = bag;
                                            _quantity.text = '1';
                                            _message = null;
                                          });
                                        } else {
                                          setState(() {
                                            _selected = gift;
                                            _bagItem = bag;
                                            _quantity.text = '1';
                                            _message = null;
                                          });
                                        }
                                      },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                    vertical: 4,
                                  ),
                                  child: Column(
                                    children: [
                                      Stack(
                                        children: [
                                          if (gift.imageUrl.isNotEmpty)
                                            Image.network(
                                              gift.imageUrl,
                                              height: 52,
                                              width: 52,
                                              errorBuilder: (_, _, _) =>
                                                  const Icon(
                                                    Icons.card_giftcard,
                                                    size: 52,
                                                  ),
                                            )
                                          else
                                            const Icon(
                                              Icons.card_giftcard,
                                              size: 52,
                                              color: liveAccent,
                                            ),
                                          if (!available && !gift.isRedPacket)
                                            const Positioned(
                                              right: 0,
                                              bottom: 0,
                                              child: Tooltip(
                                                message: '暂不可送',
                                                child: Icon(
                                                  Icons.lock_outline,
                                                  size: 14,
                                                  color: Colors.white54,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        gift.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          height: 1.35,
                                        ),
                                      ),
                                      Text(
                                        bag != null
                                            ? '库存 ${bag.quantity}'
                                            : gift.isRedPacket
                                            ? '发红包'
                                            : gift.priceKnown
                                            ? '${gift.displayPrice} 电池'
                                            : '价格未知',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          height: 1.35,
                                          color: Colors.white54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _tab(String label, bool selected, VoidCallback onTap) => Semantics(
    key: ValueKey('gift-tab-$label'),
    selected: selected,
    child: TextButton(
      onPressed: _busy ? null : onTap,
      style: TextButton.styleFrom(
        foregroundColor: selected ? liveAccent : Colors.white60,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              height: 1.2,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 16,
            height: 2,
            decoration: BoxDecoration(
              color: selected ? liveAccent : Colors.transparent,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _footer() {
    final selected = _selected;
    final count = int.tryParse(_quantity.text) ?? 0;
    final bag = _bagItem;
    final allowed = selected?.allowedQuantities;
    final unavailable = selected == null
        ? '请选择礼物'
        : !(bag?.available ?? selected.sendable)
        ? selected.unavailableReason ?? '当前礼物暂不可赠送'
        : count < 1 || count > selected.maxQuantity
        ? '请输入 1–${selected.maxQuantity} 的整数数量'
        : allowed != null && !allowed.contains(count)
        ? '请选择支持的赠送数量'
        : bag != null && count > bag.quantity
        ? '包裹数量不足'
        : bag == null && selected.coinType == 'gold' &&
            (_snapshot?.wallet.gold == null || selected.price * count > _snapshot!.wallet.gold!)
        ? '余额不足或暂时无法核验余额'
        : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected != null)
            Text(
              unavailable ?? '${selected.name} · ${_bagItem == null ? '合计 ${liveBatteryAmount(selected.price * count)} 电池' : '消耗 $count 个包裹礼物'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Colors.white70,
              ),
            ),
          if (selected?.allowedQuantities case final allowed?)
            Text(
              '可选数量：${allowed.join('、')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, height: 1.4),
            ),
          if (_bagItem?.expiresAt case final expires?)
            Text(
              '到期：${expires.toLocal().toString().split('.').first}',
              style: const TextStyle(fontSize: 11, height: 1.4),
            ),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _busy ? null : widget.onRecharge,
                    icon: const Icon(Icons.battery_charging_full, size: 16),
                    label: Text(
                      '${_snapshot?.wallet.gold == null ? '' : '${liveBatteryAmount(_snapshot!.wallet.gold!)} · '}充值',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  ),
                ),
              ),
              SizedBox(
                width: 62,
                child: TextField(
                  controller: _quantity,
                  enabled: !_busy && selected != null,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    hintText: '数量',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy || unavailable != null || _pending != null
                    ? null
                    : _send,
                style: FilledButton.styleFrom(
                  backgroundColor: liveAccent,
                  foregroundColor: Colors.white,
                ),
                child: const Text('赠送'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openRedPacket() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _selected = null;
      _bagItem = null;
    });
    try {
      await widget.onRedPacket?.call();
    } finally {
      if (mounted) await _load();
    }
  }

  void _selectGroup(String? id) {
    setState(() {
      _bag = false;
      _groupId = id;
      _selected = null;
      _bagItem = null;
      _message = null;
    });
  }
}
