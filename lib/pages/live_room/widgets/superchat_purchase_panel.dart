import 'package:PiliPlus/pages/live_room/widgets/live_panel_surface.dart';
import 'package:PiliPlus/models_new/live/live_superchat/purchase.dart';
import 'package:PiliPlus/services/live_gift_gateway.dart';
import 'package:PiliPlus/services/live_gift_service.dart';
import 'package:PiliPlus/services/live_superchat_service.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_ui/material_ui.dart';

Future<void> showLiveSuperChatPurchase(
  BuildContext context, {
  required int roomId,
  required int? anchorUid,
  required String anchorName,
  int? areaId,
  int? parentAreaId,
}) async {
  if (!Accounts.main.isLogin) {
    SmartDialog.showToast('请先登录后购买醒目留言');
    return;
  }
  if (anchorUid == null || anchorUid <= 0 || roomId <= 0) {
    SmartDialog.showToast('主播信息尚未加载');
    return;
  }
  final gifts = createLiveGiftService(
    roomId: roomId,
    anchorUid: anchorUid,
    areaId: areaId,
    parentAreaId: parentAreaId,
  );
  final service = LiveSuperChatService(gifts);
  try {
    await showLivePanel<void>(
      context,
      (_) =>
          LiveSuperChatPurchasePanel(service: service, anchorName: anchorName),
    );
  } finally {
    service.dispose();
    gifts.dispose();
  }
}

class LiveSuperChatPurchasePanel extends StatefulWidget {
  const LiveSuperChatPurchasePanel({
    super.key,
    required this.service,
    required this.anchorName,
  });
  final LiveSuperChatService service;
  final String anchorName;
  @override
  State<LiveSuperChatPurchasePanel> createState() =>
      _LiveSuperChatPurchasePanelState();
}

class _LiveSuperChatPurchasePanelState
    extends State<LiveSuperChatPurchasePanel> {
  final _text = TextEditingController(), _custom = TextEditingController();
  LiveScConfig? _config;
  LiveGiftResult? _pending;
  List<LiveScImage> _images = [];
  LiveScImage? _image;
  Object? _identity;
  int _gold = 0;
  bool _busy = false, _customSelected = false, _animate = false;
  String? _message, _receipt;
  String _translated = '', _translationKey = '';
  LiveScTier? get _tier => _config?.tierForGold(_gold);
  int get _total => _gold + (_animate ? _config?.animationGold ?? 0 : 0);
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    _custom.dispose();
    widget.service.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final identity = widget.service.gifts.currentAccount().identity;
      final config = await widget.service.load();
      final pending = await widget.service.gifts.pending();
      if (!mounted) return;
      if (!identical(
        identity,
        widget.service.gifts.currentAccount().identity,
      )) {
        throw const LiveGiftException('账号已变化，请重新打开');
      }
      setState(() {
        _config = config;
        _identity = identity;
        _pending = pending;
        _gold = config.tiers.where((t) => t.enabled).firstOrNull?.gold ?? 0;
        _customSelected = false;
        _custom.clear();
        _image = null;
        _images = [];
        _animate = false;
        _translated = '';
        _translationKey = '';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _message = LiveGiftService.errorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _translate() async {
    if (_busy || _text.text.trim().isEmpty) return;
    final source = _text.text;
    setState(() => _busy = true);
    try {
      final result = await widget.service.translate(source);
      if (mounted && _text.text == source) {
        setState(() {
          _translated = result.text;
          _translationKey = result.key;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = LiveGiftService.errorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadImages() async {
    setState(() => _busy = true);
    try {
      final images = await widget.service.images();
      if (mounted) {
        setState(() {
          _images = images;
          _image = images.firstOrNull;
          _animate = _image != null;
          if (images.isEmpty) _message = '平台暂未返回可用的定制动画素材';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = LiveGiftService.errorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final tier = _tier, config = _config;
    if (_busy ||
        tier == null ||
        config == null ||
        _identity == null ||
        _pending != null) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (_animate && _image == null) {
        throw const LiveGiftException('请选择定制动画素材');
      }
      final selection = LiveScSelection(
        tier: tier,
        message: _text.text,
        gold: _gold,
        goodsId: config.goodsId,
        translationKey: _translationKey,
        translatedText: _translated,
        imageId: _animate ? _image!.id : 0,
        imageGold: _animate ? config.animationGold : 0,
      );
      final confirmation = await widget.service.prepare(selection, _identity!);
      if (!mounted) return;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认购买醒目留言'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '账号 UID：${confirmation.uid}\n主播：${widget.anchorName}\n房间：${widget.service.gifts.roomId}\n展示时长：${tier.seconds} 秒\n留言费用：${liveBatteryAmount(selection.gold)} 电池${selection.imageId > 0 ? '\n动画附加费：${liveBatteryAmount(selection.imageGold)} 电池' : ''}\n总费用：${liveBatteryAmount(selection.totalGold)} 电池\n',
                ),
                Text(selection.message),
                if (selection.translatedText.isNotEmpty)
                  Text('\n日语译文：${selection.translatedText}'),
                if (selection.imageId > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Image.network(
                      _image!.url,
                      width: 80,
                      height: 80,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.image_not_supported),
                    ),
                  ),
                if (tier.description.isNotEmpty) Text('\n${tier.description}'),
                const Text('\n平台可能审核留言；购买后无法在此撤回。'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认购买并发送'),
            ),
          ],
        ),
      );
      if (!mounted || accepted != true) {
        widget.service.cancel();
        return;
      }
      final result = await widget.service.submit(confirmation);
      if (!mounted) return;
      final sameAccount = identical(
        _identity,
        widget.service.gifts.currentAccount().identity,
      );
      setState(() {
        _message = sameAccount ? result.message : '账号已变化，请切回原账号核对 SC 订单';
        _receipt = sameAccount ? result.receiptId : null;
      });
      final pending = await widget.service.gifts.pending();
      if (mounted) setState(() => _pending = pending);
      if (sameAccount && result.state == LiveActionState.succeeded) {
        _text.clear();
        _translationKey = '';
        _translated = '';
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = LiveGiftService.errorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkReceipt() async {
    final id = _receipt;
    if (id == null || _busy) return;
    setState(() => _busy = true);
    try {
      final data = await widget.service.receipt(id);
      if (mounted) {
        setState(
          () => _message =
              '订单 $id\n${data['message'] ?? data['message_trans'] ?? '平台已返回留言信息'}\n留言编号：${data['id'] ?? '暂未返回'}；审核状态：${data['status'] ?? '暂未返回'}',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = '订单 $id 查询失败：${LiveGiftService.errorMessage(error)}',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _acknowledge() async {
    final pending = _pending;
    if (pending == null || _busy) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('已核对官方订单和余额？'),
        content: const Text('解除限制不会判断上次购买是否成功，也不会重发。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('我已核对，解除限制'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.service.gifts.acknowledgeUnknown(pending.operationId);
      if (mounted) setState(() => _pending = null);
    } catch (error) {
      if (mounted) {
        setState(() => _message = LiveGiftService.errorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _config, tier = _tier;
    return PopScope(
      canPop: !_busy,
      child: LivePanelSurface(
        child: SizedBox(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 6),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '醒目留言 SC',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '刷新',
                      onPressed: _busy ? null : _load,
                      icon: const Icon(Icons.refresh),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              if (_busy) const LinearProgressIndicator(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.anchorName} · 房间 ${widget.service.gifts.roomId}',
                      ),
                      if (_message != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: SelectableText(_message!),
                        ),
                      if (_receipt != null)
                        TextButton(
                          onPressed: _busy ? null : _checkReceipt,
                          child: const Text('查询本次订单留言'),
                        ),
                      if (_pending != null) ...[
                        Text(_pending!.message),
                        TextButton(
                          onPressed: _busy ? null : _acknowledge,
                          child: const Text('已核对官方记录'),
                        ),
                      ],
                      if (config != null) ...[
                        if (config.notice.isNotEmpty) Text(config.notice),
                        if (config.banReason.isNotEmpty)
                          Text(
                            config.banReason,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        if (config.tiers.isEmpty)
                          const Text('平台暂未返回本房间可购买的 SC 档位'),
                        const Text(
                          '选择留言档位',
                          style: TextStyle(fontSize: 12, color: Colors.white60),
                        ),
                        const SizedBox(height: 6),
                        LayoutBuilder(
                          builder: (context, limits) {
                            final columns =
                                MediaQuery.textScalerOf(context).scale(12) > 17
                                ? 2
                                : 3;
                            return Wrap(
                              spacing: 8,
                              runSpacing: 5,
                              children: [
                                for (final option in config.tiers)
                                  SizedBox(
                                    width:
                                        (limits.maxWidth - (columns - 1) * 8) /
                                        columns,
                                    child: LiveChoiceChip(
                                      selected:
                                          !_customSelected &&
                                          _gold == option.gold,
                                      onSelected: !_busy && option.enabled
                                          ? (_) => setState(() {
                                              _gold = option.gold;
                                              _customSelected = false;
                                            })
                                          : null,
                                      label: Text(
                                        '${liveBatteryAmount(option.gold)} 电池 · ${option.seconds} 秒${option.badge.isEmpty ? '' : '\n${option.badge}'}',
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _text,
                          enabled: !_busy,
                          maxLines: 2,
                          maxLength: tier?.limit,
                          style: const TextStyle(fontSize: 14, height: 1.35),
                          decoration: const InputDecoration(
                            labelText: '留言内容',
                            hintText: '写下想对主播说的话…',
                            isDense: true,
                            contentPadding: EdgeInsets.all(12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(8),
                              ),
                            ),
                          ),
                          onChanged: (_) => setState(() {
                            _translated = '';
                            _translationKey = '';
                          }),
                        ),
                        if (config.translation)
                          Row(
                            children: [
                              TextButton(
                                onPressed: _busy ? null : _translate,
                                child: const Text('中译日'),
                              ),
                              if (_translationKey.isNotEmpty)
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => setState(() {
                                          _translationKey = '';
                                          _translated = '';
                                        }),
                                  child: const Text('取消翻译'),
                                ),
                            ],
                          ),
                        if (_translated.isNotEmpty) Text(_translated),
                        const SizedBox(height: 8),
                        if (tier?.description.isNotEmpty == true)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(tier!.description),
                          ),
                        if (config.customPrice)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: TextField(
                              controller: _custom,
                              enabled: !_busy,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                labelText: '自定义电池数量',
                                helperText: '平台要求为 10 的整数倍',
                              ),
                              onChanged: (text) => setState(() {
                                _customSelected = text.isNotEmpty;
                                _gold = (int.tryParse(text) ?? 0) * 100;
                              }),
                            ),
                          ),
                        if (config.customAnimation) ...[
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('定制留言弹幕动画'),
                            subtitle: Text(
                              '附加 ${liveBatteryAmount(config.animationGold)} 电池',
                            ),
                            value: _animate,
                            onChanged: _busy
                                ? null
                                : (value) {
                                    if (value && _images.isEmpty) {
                                      _loadImages();
                                    } else {
                                      setState(() => _animate = value);
                                    }
                                  },
                          ),
                          if (_animate)
                            Wrap(
                              spacing: 8,
                              runSpacing: 5,
                              children: [
                                for (final image in _images)
                                  InkWell(
                                    onTap: _busy
                                        ? null
                                        : () => setState(() => _image = image),
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: _image?.id == image.id
                                              ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: Image.network(
                                        image.url,
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, _, _) => const Icon(
                                          Icons.image_not_supported,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                        TextButton.icon(
                          onPressed: _busy
                              ? null
                              : () => PageUtils.launchURL(
                                  'https://link.bilibili.com/p/live-h5-recharge/',
                                ),
                          icon: const Icon(Icons.battery_charging_full),
                          label: const Text('前往官方充值'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              LivePaymentFooter(
                amount: '本次金额 ${liveBatteryAmount(_total)} 电池',
                actionKey: const ValueKey('live-superchat-next'),
                onNext:
                    !_busy &&
                        _pending == null &&
                        tier != null &&
                        tier.enabled &&
                        config != null &&
                        config.banReason.isEmpty &&
                        _text.text.trim().isNotEmpty
                    ? _send
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
