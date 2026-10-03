import 'dart:async';

import 'package:PiliPlus/models_new/live/live_activity.dart';
import 'package:PiliPlus/pages/live_room/live_room_features.dart';
import 'package:PiliPlus/services/live_activity_service.dart';
import 'package:PiliPlus/services/live_gift_gateway.dart';
import 'package:PiliPlus/services/live_gift_service.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

Future<void> showLiveActivities(
  BuildContext context,
  LiveRoomFeatures features,
  int anchorUid,
) async {
  final gifts = createLiveGiftService(
    roomId: features.roomId,
    anchorUid: anchorUid,
  );
  final service = LiveActivityService(gifts);
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (_) => LiveActivityPanel(features: features, service: service),
    );
  } finally {
    service.dispose();
    gifts.dispose();
  }
}

class LiveActivityPanel extends StatefulWidget {
  const LiveActivityPanel({
    super.key,
    required this.features,
    required this.service,
  });
  final LiveRoomFeatures features;
  final LiveActivityService service;
  @override
  State<LiveActivityPanel> createState() => _LiveActivityPanelState();
}

class _LiveActivityPanelState extends State<LiveActivityPanel> {
  Timer? _timer;
  bool _busy = false;
  String? _message;
  @override
  void initState() {
    super.initState();
    widget.features.refreshActivities();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _join(LiveActivity activity) async {
    if (_busy) return;
    if (!Accounts.main.isLogin) {
      setState(() => _message = '请先登录后参与');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final confirmation = await widget.service.prepare(activity);
      if (!mounted) return;
      final fresh = confirmation.activity;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认参与活动'),
          content: SingleChildScrollView(
            child: Text(
              '账号 UID ${confirmation.account.uid}\n直播间 ${widget.features.roomId}\n${fresh.title}\n${fresh.requirement}\n'
              '${fresh.mayFollow ? '参与会按平台规则关注主播。\n' : ''}'
              '${fresh.danmaku.isNotEmpty ? '参与附带弹幕：${fresh.danmaku}\n' : ''}'
              '本次不发送付费礼物；是否满足资格由平台核验。',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认参与'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) {
        widget.service.cancel();
        return;
      }
      final message = await widget.service.submit(confirmation);
      if (mounted) setState(() => _message = message);
      widget.features.refreshActivities();
    } catch (error) {
      if (mounted)
        setState(() => _message = LiveGiftService.errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _results(LiveActivity activity) async {
    setState(() => _busy = true);
    try {
      final result = await widget.service.results(activity);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('活动结果'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Text(
                result.winners.isEmpty
                    ? '平台尚未返回中奖名单，请开奖后刷新。'
                    : result.winners
                          .map((w) {
                            final anonymous =
                                w['is_mystery'] == true ||
                                liveInt(w['is_mystery']) == 1;
                            return '${anonymous ? '匿名观众' : w['name'] ?? w['uname'] ?? '观众'}  ${w['award_name'] ?? result.data['award_name'] ?? ''} ${w['gift_num'] ?? w['num'] ?? ''}';
                          })
                          .join('\n'),
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
      );
    } catch (error) {
      if (mounted)
        setState(() => _message = LiveGiftService.errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .72,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '红包与天选',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: '刷新活动',
                  onPressed: _busy ? null : widget.features.refreshActivities,
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '手动参与，满足条件后由平台开奖。付费或任务类天选可打开官方页面。',
              style: TextStyle(fontSize: 12),
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_message != null)
            Padding(padding: const EdgeInsets.all(12), child: Text(_message!)),
          Expanded(
            child: Obx(() {
              final items = widget.features.activities.toList();
              final error = widget.features.activityError.value;
              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(error),
                    ),
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('暂未发现正在进行的红包或天选'),
                    ),
                  for (final activity in items)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activity.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(activity.requirement),
                            if (activity.danmaku.isNotEmpty)
                              Text('附带弹幕：${activity.danmaku}'),
                            if (activity.paid)
                              Text(
                                '送礼条件：${activity.data['gift_name'] ?? '礼物'} × ${activity.data['gift_num'] ?? '—'}',
                              ),
                            Text(
                              activity.active(DateTime.now())
                                  ? '剩余 ${activity.remaining(DateTime.now())} 秒${activity.joined ? ' · 已参与' : ''}'
                                  : '等待开奖或活动已结束',
                            ),
                            Wrap(
                              spacing: 8,
                              children: [
                                FilledButton(
                                  onPressed:
                                      _busy ||
                                          activity.joined ||
                                          !activity.freeSupported ||
                                          !activity.active(DateTime.now())
                                      ? null
                                      : () => _join(activity),
                                  child: Text(activity.isRed ? '抢红包' : '参与天选'),
                                ),
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _results(activity),
                                  child: const Text('查看结果'),
                                ),
                                if (!activity.isRed)
                                  TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () => PageUtils.launchURL(
                                            'https://live.bilibili.com/p/html/live-lottery/anchor-join.html?roomid=${widget.features.roomId}',
                                          ),
                                    child: const Text('官方天选页面'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            }),
          ),
        ],
      ),
    ),
  );
}
