import 'package:PiliPlus/http/live.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/live/gift/live_gift.dart';
import 'package:PiliPlus/models_new/live/live_contribution_rank/item.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class LiveGuardRankPanel extends StatefulWidget {
  const LiveGuardRankPanel({
    super.key,
    required this.roomId,
    required this.ruid,
    this.embedded = false,
    this.loadRank,
  });
  final int roomId, ruid;
  final bool embedded;
  final Future<LoadingState<Map<String, dynamic>>> Function(int type, int page)?
      loadRank;
  @override
  State<LiveGuardRankPanel> createState() => _LiveGuardRankPanelState();
}

class _LiveGuardRankPanelState extends State<LiveGuardRankPanel> {
  static const _tabs = {4: '周榜', 3: '月榜', 5: '陪伴榜'};
  int _type = 4, _page = 0, _pages = 1, _generation = 0;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _own, _previous;
  int? _count;
  final _items = <Map<String, dynamic>>[];
  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    final generation = ++_generation;
    final page = reset ? 1 : _page + 1;
    setState(() {
      _busy = true;
      _error = null;
      if (reset) {
        _page = 0;
        _pages = 1;
        _items.clear();
        _own = _previous = null;
        _count = null;
      }
    });
    try {
      final result = await (widget.loadRank?.call(_type, page) ??
          LiveHttp.liveGuardRank(
            roomId: widget.roomId,
            ruid: widget.ruid,
            page: page,
            type: _type,
          ));
      if (!mounted || generation != _generation) return;
      if (result case Success(:final response)) {
        final info = liveMap(response['info']);
        setState(() {
          _page = page;
          _pages = liveInt(info['page']) ?? _pages;
          _count = liveInt(info['num']) ?? _count;
          if (page == 1 || response.containsKey('my_follow_info')) {
            _own = liveMap(response['my_follow_info']);
          }
          if (page == 1 || response.containsKey('extop')) {
            _previous = liveMaps(response['extop']).firstOrNull;
          }
          final incoming = [
            if (page == 1) ...liveMaps(response['top3']),
            ...liveMaps(response['list']),
          ];
          final known = _items
              .map((item) => LiveContributionRankItem.fromJson(item).uid)
              .whereType<int>()
              .toSet();
          for (final item in incoming) {
            final viewer = LiveContributionRankItem.fromJson(item);
            if (viewer.anonymous ||
                viewer.uid == null ||
                known.add(viewer.uid!)) {
              _items.add(item);
            }
          }
        });
      } else {
        setState(() => _error = result.toString());
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = '读取榜单失败，请重试');
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Widget _row(Map<String, dynamic> data, {String? prefix}) {
    final user = LiveContributionRankItem.fromJson(data);
    final level = liveInt(liveMap(liveMap(data['uinfo'])['guard'])['level']);
    final guard = user.anonymous
        ? null
        : const {1: '总督', 2: '提督', 3: '舰长'}[level];
    final rank = liveInt(data['rank']);
    return ListTile(
      leading: NetworkImgLayer(
        src: user.face,
        width: 42,
        height: 42,
        type: .avatar,
      ),
      title: Text(
        '${prefix == null ? '' : '$prefix · '}${user.name ?? '观众'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          ?guard,
          if (user.anonymous) '官方匿名标记',
          if (_type == 5 && data['accompany_days'] != null)
            '陪伴 ${data['accompany_days']} 天',
          if (data['score'] != null) '亲密度 ${data['score']}',
        ].join(' · '),
      ),
      trailing: Text(rank == null || rank <= 0 ? '未上榜' : '#$rank'),
      onTap: user.anonymous || user.uid == null || user.uid! <= 0
          ? null
          : () => Get.toNamed('/member?mid=${user.uid}'),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact =
          constraints.maxHeight < 360 ||
          MediaQuery.textScalerOf(context).scale(14) > 21;
      final header = <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '大航海${_count == null ? '' : ' · $_count'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: '刷新榜单',
                onPressed: _busy ? null : () => _load(reset: true),
                icon: const Icon(Icons.refresh),
              ),
              if (!widget.embedded)
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          children: [
            for (final tab in _tabs.entries)
              ChoiceChip(
                label: Text(tab.value),
                selected: _type == tab.key,
                onSelected: (_) {
                  setState(() => _type = tab.key);
                  _load(reset: true);
                },
              ),
          ],
        ),
        if (_busy) const LinearProgressIndicator(),
      ];
      final footer = <Widget>[
        if (_own?.isNotEmpty == true) _row(_own!, prefix: '我'),
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: () => PageUtils.launchURL(
              'https://live.bilibili.com/p/html/live-app-guard-info/index.html?uid=${widget.ruid}&is_live_webview=1',
            ),
            icon: const Icon(Icons.sailing),
            label: const Text('在官方页面上舰'),
          ),
        ),
      ];
      return Column(
        children: [
          if (!compact) ...header,
          Expanded(
            child: ListView(
              children: [
                if (compact) ...header,
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!),
                  ),
                if (_previous != null && _type != 5)
                  _row(_previous!, prefix: _type == 4 ? '上周 TOP1' : '上月 TOP1'),
                for (final item in _items) _row(item),
                if (!_busy && _error == null && _items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('暂无人上榜', textAlign: TextAlign.center),
                  ),
                if (_error == null && _page < _pages)
                  TextButton(
                    onPressed: _busy ? null : _load,
                    child: const Text('加载更多'),
                  ),
                if (compact) ...footer,
              ],
            ),
          ),
          if (!compact) ...footer,
        ],
      );
    },
  );
}
