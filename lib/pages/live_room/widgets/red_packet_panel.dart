import 'package:PiliPlus/pages/live_room/widgets/live_panel_surface.dart';
import 'package:PiliPlus/models_new/live/gift/live_red_packet.dart';
import 'package:PiliPlus/services/live_gift_service.dart';
import 'package:PiliPlus/services/live_red_packet_service.dart';
import 'package:html/parser.dart' as html;
import 'package:material_ui/material_ui.dart';

class LiveRedPacketPanel extends StatefulWidget {
  const LiveRedPacketPanel({
    super.key,
    required this.service,
    required this.anchorName,
  });
  final LiveRedPacketService service;
  final String anchorName;
  @override
  State<LiveRedPacketPanel> createState() => _LiveRedPacketPanelState();
}

class _LiveRedPacketPanelState extends State<LiveRedPacketPanel> {
  LiveRedPacketType _type = LiveRedPacketType.gift;
  LiveRedPacketConfig? _config;
  LiveRedPacketPackage? _package;
  Object? _identity;
  int? _duration, _count, _requirement;
  ({int id, String text})? _danmaku;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    widget.service.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _config = null;
      _package = null;
      _message = null;
      _duration = _count = _requirement = null;
      _danmaku = null;
    });
    try {
      final identity = widget.service.gifts.currentAccount().identity;
      final config = await widget.service.load(_type);
      if (!mounted) return;
      setState(() {
        _identity = identity;
        _config = config;
        _duration = config.durations.firstOrNull;
        _requirement = config.requirements.keys.firstOrNull;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _message = LiveGiftService.errorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final package = _package;
    if (_busy || package == null || _duration == null || _identity == null) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final selection = LiveRedPacketSelection(
        type: _type,
        package: package,
        duration: _duration!,
        count: _count ?? 0,
        requirement: _requirement ?? package.defaultRequirement,
        requirementText: _config!.requirements[_requirement] ?? '',
        danmakuId: _danmaku?.id ?? 0,
        danmakuText: _danmaku?.text ?? '',
      );
      final confirmation = await widget.service.prepare(selection, _identity!);
      if (!mounted) return;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('确认发送${_type.label}'),
          content: SingleChildScrollView(
            child: Text(
              '账号 UID：${confirmation.uid}\n主播：${widget.anchorName}\n房间：${widget.service.gifts.roomId}\n\n'
              '${package.title}\n费用：${liveBatteryAmount(package.price)} 电池\n'
              '开奖时间：${_duration == 0 ? '平台默认' : '${_duration! ~/ 60} 分钟'}\n'
              '${_type == LiveRedPacketType.battery ? '红包数量：$_count\n参与条件：${_config!.requirements[_requirement]}\n' : ''}'
              '${_type == LiveRedPacketType.guard ? '参与限制：以官方上舰红包规则为准，已在本房间开通大航海的观众不可参与。\n' : ''}'
              '${_danmaku != null ? '附带弹幕：${_danmaku!.text}\n' : ''}\n发送后无法撤回。',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认发送'),
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
      setState(
        () => _message =
            identical(
              confirmation.identity,
              widget.service.gifts.currentAccount().identity,
            )
            ? result.message
            : '账号已变化，请切回原账号核对红包记录',
      );
    } catch (error) {
      if (mounted) {
        setState(() => _message = LiveGiftService.errorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rules() async {
    setState(() => _busy = true);
    try {
      final raw = await widget.service.rules();
      final document = html.parse(
        raw.replaceAll(
          RegExp(r'</(p|div|li|h[1-6])>', caseSensitive: false),
          '\n',
        ),
      );
      document
          .querySelectorAll('script,style')
          .forEach((node) => node.remove());
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('官方红包规则'),
          content: SingleChildScrollView(
            child: SelectableText(document.body?.text.trim() ?? '暂无规则'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _message = LiveGiftService.errorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _history() async {
    setState(() => _busy = true);
    try {
      var page = 1;
      var data = await widget.service.history(_type, page);
      final records = [...liveMaps(data['item'])];
      var loading = false;
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: Text('${_type.label}记录'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (records.isEmpty) const Text('暂无记录'),
                    for (final record in records)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${record['rname'] ?? '主播'} · 红包 ${record['lot_id'] ?? '—'}',
                        ),
                        subtitle: Text(
                          '发送时间：${_formatTime(record['send_time'])}\n'
                          '领取：${record['receive_num'] ?? '—'} / ${record['award_num'] ?? record['total_num'] ?? '—'}\n'
                          '费用：${_formatPrice(record['gold_num'] ?? record['total_battery'])}',
                        ),
                      ),
                    if (page < (liveInt(data['total_page']) ?? page))
                      TextButton(
                        onPressed: loading
                            ? null
                            : () async {
                                update(() => loading = true);
                                try {
                                  final next = await widget.service.history(
                                    _type,
                                    page + 1,
                                  );
                                  if (!context.mounted) return;
                                  update(() {
                                    page++;
                                    data = next;
                                    records.addAll(liveMaps(next['item']));
                                  });
                                } catch (error) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.maybeOf(
                                      context,
                                    )?.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          LiveGiftService.errorMessage(error),
                                        ),
                                      ),
                                    );
                                  }
                                } finally {
                                  if (context.mounted) {
                                    update(() => loading = false);
                                  }
                                }
                              },
                        child: Text(loading ? '加载中…' : '更多记录'),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ],
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _message = LiveGiftService.errorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _formatTime(dynamic value) {
    final seconds = liveInt(value);
    return seconds == null
        ? '—'
        : DateTime.fromMillisecondsSinceEpoch(seconds * 1000)
              .toString()
              .split('.')
              .first;
  }

  static String _formatPrice(dynamic value) {
    final gold = liveInt(value);
    return gold == null ? '—' : '${liveBatteryAmount(gold)} 电池';
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    final batteryReady =
        _type != LiveRedPacketType.battery ||
        (_count != null && _requirement != null);
    return PopScope(
      canPop: !_busy,
      child: LivePanelSurface(
        child: SizedBox(
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      '发红包',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _history,
                    child: const Text('记录'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _rules,
                    child: const Text('规则'),
                  ),
                  IconButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final type in LiveRedPacketType.values)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(type.label),
                          selected: _type == type,
                          onSelected: _busy
                              ? null
                              : (_) {
                                  setState(() {
                                    _type = type;
                                    _message = null;
                                  });
                                  _load();
                                },
                        ),
                      ),
                  ],
                ),
              ),
              if (_busy) const LinearProgressIndicator(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_message != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_message!),
                      ),
                    if (config != null && config.packages.isEmpty)
                      const Text('当前账号暂无可用红包套餐'),
                    for (final package
                        in config?.packages ?? <LiveRedPacketPackage>[])
                      Card(
                        color: identical(_package, package)
                            ? Theme.of(context).colorScheme.secondaryContainer
                            : null,
                        child: ListTile(
                          onTap: _busy || !package.enabled
                              ? null
                              : () => setState(() {
                                  _package = package;
                                  _count = package.counts.firstOrNull;
                                  _danmaku = package.danmaku.firstOrNull;
                                  _requirement =
                                      config!.requirements.containsKey(
                                        package.defaultRequirement,
                                      )
                                      ? package.defaultRequirement
                                      : config.requirements.keys.firstOrNull;
                                }),
                          leading:
                              package.awards.firstOrNull?.image.isNotEmpty ==
                                  true
                              ? Image.network(
                                  package.awards.first.image,
                                  width: 42,
                                  height: 42,
                                  errorBuilder: (_, _, _) =>
                                      const Icon(Icons.redeem),
                                )
                              : const Icon(Icons.redeem),
                          title: Text(package.title),
                          subtitle: Text(
                            '${liveBatteryAmount(package.price)} 电池'
                            '${package.tips.isNotEmpty ? '\n${package.tips}' : ''}'
                            '${package.enabled ? '' : '\n当前不可发送'}',
                          ),
                          trailing: identical(_package, package)
                              ? const Icon(Icons.check_circle)
                              : null,
                        ),
                      ),
                    if (config != null) ...[
                      const SizedBox(height: 12),
                      const Text('开奖时间'),
                      if (config.durations.isEmpty)
                        const Text('接口未返回可用时长，暂不能发送'),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final duration in config.durations)
                            ChoiceChip(
                              label: Text(
                                duration == 0 ? '平台默认' : '${duration ~/ 60} 分钟',
                              ),
                              selected: _duration == duration,
                              onSelected: _busy
                                  ? null
                                  : (_) => setState(() => _duration = duration),
                            ),
                        ],
                      ),
                    ],
                    if (_type == LiveRedPacketType.battery &&
                        _package != null) ...[
                      const Text('红包数量'),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final count in _package!.counts)
                            ChoiceChip(
                              label: Text('$count 个'),
                              selected: _count == count,
                              onSelected: _busy
                                  ? null
                                  : (_) => setState(() => _count = count),
                            ),
                        ],
                      ),
                      const Text('参与条件'),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final requirement
                              in config!.requirements.entries)
                            ChoiceChip(
                              label: Text(requirement.value),
                              selected: _requirement == requirement.key,
                              onSelected: _busy
                                  ? null
                                  : (_) => setState(
                                      () => _requirement = requirement.key,
                                    ),
                            ),
                        ],
                      ),
                      if (config.requirements.isEmpty)
                        const Text('接口未返回参与条件，暂不能发送'),
                    ],
                    if (_package?.danmaku.isNotEmpty == true) ...[
                      const SizedBox(height: 12),
                      const Text('红包附带弹幕'),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final danmaku in _package!.danmaku)
                            ChoiceChip(
                              label: Text(danmaku.text),
                              selected: _danmaku?.id == danmaku.id,
                              onSelected: _busy
                                  ? null
                                  : (_) => setState(() => _danmaku = danmaku),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed:
                          _busy ||
                              _package == null ||
                              _duration == null ||
                              !batteryReady
                          ? null
                          : _send,
                      child: Text(
                        _package == null
                            ? '选择红包套餐'
                            : '发红包 · ${liveBatteryAmount(_package!.price)} 电池',
                      ),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _load,
                      child: const Text('刷新套餐'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
