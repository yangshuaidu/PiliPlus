import 'dart:async';

import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/http/live.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/models_new/live/gift/live_gift.dart';
import 'package:PiliPlus/models_new/live/live_pk.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/request_utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class LivePkBar extends StatefulWidget {
  const LivePkBar({super.key, required this.state});
  final LivePkState state;
  @override
  State<LivePkBar> createState() => _LivePkBarState();
}

class _LivePkBarState extends State<LivePkBar> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final left = state.members.first;
    final right = state.members[1];
    final sum = left.score + right.score;
    final ratio = sum > 0 ? (left.score / sum).clamp(0.02, 0.98) : 0.5;
    final remaining = state.remaining(DateTime.now());
    final seconds = (remaining % 60).toString().padLeft(2, '0');
    final stale =
        DateTime.now().difference(state.receivedAt) >
        const Duration(seconds: 60);
    Widget member(LivePkMember member, {bool reverse = false}) => InkWell(
      onTap: () => showLivePkMember(context, member),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!reverse)
            NetworkImgLayer(
              src: member.face,
              width: 22,
              height: 22,
              type: .avatar,
            ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                member.name.isEmpty ? '主播 ${member.uid}' : member.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
          if (reverse)
            NetworkImgLayer(
              src: member.face,
              width: 22,
              height: 22,
              type: .avatar,
            ),
        ],
      ),
    );
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.members.length == 2)
            SizedBox(
              height: 22,
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: ColoredBox(color: Color(0xff168cf5)),
                  ),
                  FractionallySizedBox(
                    widthFactor: ratio,
                    heightFactor: 1,
                    child: const ColoredBox(color: Color(0xffed287a)),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            left.scoreText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            right.scoreText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            color: Colors.black54,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Row(
              children: [
                Expanded(child: member(left)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '${state.members.length > 2 ? '${state.members.length} 人 ' : ''}${state.phase} '
                    '${stale
                        ? '数据待更新'
                        : state.deadline == null
                        ? ''
                        : '${remaining ~/ 60}:$seconds'}',
                    style: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
                ),
                Expanded(child: member(right, reverse: true)),
                if (state.members.length > 2)
                  PopupMenuButton<int>(
                    icon: const Icon(
                      Icons.more_horiz,
                      color: Colors.white,
                      size: 18,
                    ),
                    itemBuilder: (_) => [
                      for (final (index, user) in state.members.indexed)
                        PopupMenuItem(
                          value: index,
                          child: Text('${user.name} · ${user.scoreText}'),
                        ),
                    ],
                    onSelected: (index) =>
                        showLivePkMember(context, state.members[index]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showLivePkMember(BuildContext context, LivePkMember member) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 540),
      builder: (_) => _PkMemberCard(member: member),
    );

class _PkMemberCard extends StatefulWidget {
  const _PkMemberCard({required this.member});
  final LivePkMember member;
  @override
  State<_PkMemberCard> createState() => _PkMemberCardState();
}

class _PkMemberCardState extends State<_PkMemberCard> {
  Map<String, dynamic>? _info;
  String? _error;
  int? _relation;
  bool _following = false;
  Object? _identity;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _identity = Accounts.main;
    try {
      final result = await LiveHttp.liveRoomWebInfo(widget.member.roomId);
      if (!mounted) return;
      setState(() {
        _info = result.dataOrNull;
        _error = result.isSuccess ? null : result.toString();
      });
      if (Accounts.main.isLogin && widget.member.uid > 0) {
        final relation = await UserHttp.userRelation(widget.member.uid);
        if (mounted && identical(_identity, Accounts.main)) {
          setState(() => _relation = relation.dataOrNull?.attribute);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _error = '部分主播资料暂不可用');
    }
  }

  Future<void> _follow() async {
    if (!Accounts.main.isLogin) {
      SmartDialog.showToast('请先登录');
      return;
    }
    if (!identical(_identity, Accounts.main)) {
      await _load();
      return;
    }
    if (_following || _relation == null) return;
    setState(() => _following = true);
    try {
      await RequestUtils.actionRelationMod(
        context: context,
        mid: widget.member.uid,
        isFollow: _relation == 2 || _relation == 6,
        afterMod: (value) {
          if (mounted && identical(_identity, Accounts.main)) {
            setState(() => _relation = value);
          }
        },
      );
    } finally {
      if (mounted) setState(() => _following = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    final anchor = liveMap(_info?['anchor_info']);
    final followers = liveMap(anchor['relation_info'])['attention'];
    final fansClub = liveMap(anchor['medal_info'])['fansclub'];
    final guards = liveMap(_info?['guard_info'])['count'];
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              NetworkImgLayer(
                src: member.face,
                width: 72,
                height: 72,
                type: .avatar,
              ),
              const SizedBox(height: 12),
              Text(member.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                '房间号：${member.roomId}${followers == null ? '' : ' · 粉丝：$followers'}',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  if (guards != null)
                    Chip(
                      avatar: const Icon(Icons.sailing),
                      label: Text('$guards 人加入大航海'),
                    ),
                  if (fansClub != null)
                    Chip(
                      avatar: const Icon(Icons.favorite),
                      label: Text('$fansClub 人加入粉丝团'),
                    ),
                  Chip(label: Text('本场分数 ${member.scoreText}')),
                ],
              ),
              if (member.levelIcon.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.network(
                        member.levelIcon,
                        width: 44,
                        height: 44,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.military_tech),
                      ),
                      const SizedBox(width: 8),
                      const Text('PK 段位'),
                    ],
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_error!, style: const TextStyle(fontSize: 12)),
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: member.roomId <= 0
                        ? null
                        : () {
                            Navigator.pop(context);
                            PageUtils.toLiveRoom(member.roomId);
                          },
                    child: const Text('去 TA 直播间'),
                  ),
                  OutlinedButton(
                    onPressed: member.uid <= 0
                        ? null
                        : () {
                            Navigator.pop(context);
                            Get.toNamed('/member?mid=${member.uid}');
                          },
                    child: const Text('个人空间'),
                  ),
                  if (member.uid != Accounts.main.mid)
                    OutlinedButton(
                      onPressed: _following || _relation == null
                          ? null
                          : _follow,
                      child: Text(
                        _relation == 2 || _relation == 6 ? '已关注' : '关注',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
