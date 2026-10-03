import 'package:PiliPlus/services/live_gift_service.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

class LiveGiftPanel extends StatefulWidget {
  final LiveGiftService service;
  final String anchorName;
  const LiveGiftPanel({
    super.key,
    required this.service,
    required this.anchorName,
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
            '请先在官方直播间核对送礼记录、背包和余额。解除后可以发起新的赠送；这不会重发上次礼物，也不会把未知结果标记为成功。',
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
    final colorScheme = Theme.of(context).colorScheme;
    final selected = _selected;
    final count = int.tryParse(_quantity.text) ?? 0;
    final entries = _bag
        ? [
            for (final item in snapshot?.bag ?? <LiveBagItem>[])
              (item.gift, item),
          ]
        : [for (final gift in snapshot?.gifts ?? <LiveGift>[]) (gift, null)];
    return PopScope(
      canPop: !_busy,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height:
                (MediaQuery.sizeOf(context).height -
                    MediaQuery.viewInsetsOf(context).bottom) *
                0.85,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '直播礼物',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '刷新礼物',
                        onPressed: _busy ? null : _load,
                        icon: const Icon(Icons.refresh),
                      ),
                      IconButton(
                        tooltip: '关闭礼物',
                        onPressed: _busy ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Text(
                        '${widget.anchorName} · 房间 ${widget.service.roomId}',
                      ),
                      if (snapshot != null)
                        Text(
                          '账号 UID ${snapshot.accountUid} · 电池余额：${snapshot.wallet.gold == null ? '暂不可用' : liveBatteryAmount(snapshot.wallet.gold!)}',
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('电池礼物'),
                            selected: !_bag,
                            onSelected: _busy
                                ? null
                                : (_) => setState(() {
                                    _bag = false;
                                    _selected = null;
                                    _bagItem = null;
                                  }),
                          ),
                          ChoiceChip(
                            label: const Text('背包礼物'),
                            selected: _bag,
                            onSelected: _busy
                                ? null
                                : (_) => setState(() {
                                    _bag = true;
                                    _selected = null;
                                    _bagItem = null;
                                  }),
                          ),
                        ],
                      ),
                      if (_busy && !_confirming)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(),
                        ),
                      if (_message != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(_message!),
                        ),
                      if (_pending case final pending?)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(pending.message),
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
                            ),
                          ),
                        ),
                      for (final error
                          in snapshot?.errors.entries ??
                              <MapEntry<String, String>>[])
                        Text(
                          '${error.key}：${error.value}',
                          style: TextStyle(color: colorScheme.error),
                        ),
                      const SizedBox(height: 8),
                      if (snapshot != null && entries.isEmpty && !_busy)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            snapshot.errors.containsKey(_bag ? '背包' : '礼物')
                                ? '加载失败，请刷新重试'
                                : _bag
                                ? '背包暂无可展示的礼物'
                                : '当前房间暂无可展示的电池礼物',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = (constraints.maxWidth / 110)
                              .floor()
                              .clamp(2, 5);
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  mainAxisExtent: 142,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                            itemCount: entries.length,
                            itemBuilder: (context, index) {
                              final (gift, bag) = entries[index];
                              final available = bag?.available ?? gift.sendable;
                              final isSelected =
                                  identical(selected, gift) &&
                                  identical(_bagItem, bag);
                              return Material(
                                color: isSelected
                                    ? colorScheme.secondaryContainer
                                    : colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: _busy
                                      ? null
                                      : () {
                                          if (!available) {
                                            setState(
                                              () => _message =
                                                  gift.unavailableReason ??
                                                  '礼物已过期或不可赠送',
                                            );
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
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      children: [
                                        if (gift.imageUrl.isNotEmpty)
                                          Image.network(
                                            gift.imageUrl,
                                            height: 48,
                                            width: 48,
                                            errorBuilder: (_, _, _) =>
                                                const Icon(
                                                  Icons.card_giftcard,
                                                  size: 48,
                                                ),
                                          )
                                        else
                                          const Icon(
                                            Icons.card_giftcard,
                                            size: 48,
                                          ),
                                        const SizedBox(height: 4),
                                        Text(
                                          gift.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        Text(
                                          bag == null
                                              ? '${gift.displayPrice} 电池'
                                              : '库存 ${bag.quantity}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        if (!available)
                                          Text(
                                            '暂不可送',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: colorScheme.error,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selected != null)
                        Text(
                          '${selected.name} · ${_bagItem == null ? '合计 ${liveBatteryAmount(selected.price * count)} 电池' : '消耗 $count 个背包礼物，电池费用 0'}',
                          maxLines: 2,
                        ),
                      if (selected?.allowedQuantities case final allowed?)
                        Text(
                          '可选数量：${allowed.join('、')}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      if (_bagItem?.expiresAt case final expires?)
                        Text(
                          '到期：${expires.toLocal().toString().split('.').first}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          SizedBox(
                            width: 110,
                            child: TextField(
                              controller: _quantity,
                              enabled: !_busy && selected != null,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                              decoration: const InputDecoration(
                                labelText: '数量',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed:
                                  _busy || selected == null || _pending != null
                                  ? null
                                  : _send,
                              child: const Text('赠送'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
