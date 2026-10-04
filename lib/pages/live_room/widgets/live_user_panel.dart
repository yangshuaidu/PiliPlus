import 'package:PiliPlus/common/widgets/dialog/report_member.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/http/live.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/member.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/models_new/live/live_danmaku/danmaku_msg.dart';
import 'package:PiliPlus/models_new/live/live_danmaku/live_user_badges.dart';
import 'package:PiliPlus/pages/live_room/controller.dart';
import 'package:PiliPlus/pages/live_room/widgets/live_action_menu.dart';
import 'package:PiliPlus/pages/live_room/widgets/live_panel_surface.dart';
import 'package:PiliPlus/pages/video/widgets/header_control.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/request_utils.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class LiveProfileInfo {
  const LiveProfileInfo({this.name = '', this.face = '', this.followers, this.following, this.relation});
  final String name, face;
  final int? followers, following, relation;
}

Future<LiveProfileInfo> loadLiveProfile(int uid) async {
  String name = '', face = '';
  int? followers, following, relation;
  await Future.wait([
    () async { try {
      final result = await MemberHttp.memberCardInfo(mid: uid);
      if (result case Success(:final response)) { name = response.card?.name ?? ''; face = response.card?.face ?? ''; followers = response.follower; }
    } catch (_) {} }(),
    () async { try {
      final result = await MemberHttp.memberStat(mid: uid);
      if (result case Success(:final response)) { following = response['following'] is int ? response['following'] as int : null; followers ??= response['follower'] is int ? response['follower'] as int : null; }
    } catch (_) {} }(),
    if (Accounts.main.isLogin) () async { try {
      final result = await UserHttp.userRelation(uid);
      if (result case Success(:final response)) relation = response.attribute;
    } catch (_) {} }(),
  ]);
  return LiveProfileInfo(name: name, face: face, followers: followers, following: following, relation: relation);
}

Future<void> showLiveUserPanel(BuildContext context, LiveRoomController controller, DanmakuMsg item) async {
  if (item.extra.mid <= 0 || item.badges.anonymous) return;
  final action = await showLivePanel<String>(context, (_) => LiveUserPanel(item: item));
  if (!context.mounted) return;
  switch (action) {
    case 'more': await showLiveMessageActions(context, controller, item, userMenu: true);
    case 'reply': controller.onAtUser(item);
    case 'space': Get.toNamed('/member?mid=${item.extra.mid}');
  }
}

class LiveUserPanel extends StatefulWidget {
  const LiveUserPanel({super.key, required this.item, this.loader = loadLiveProfile});
  final DanmakuMsg item;
  final Future<LiveProfileInfo> Function(int) loader;
  @override State<LiveUserPanel> createState() => _LiveUserPanelState();
}

class _LiveUserPanelState extends State<LiveUserPanel> {
  LiveProfileInfo? _info;
  int? _relation;
  String _page = 'profile';
  bool _loading = true, _following = false;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { final info = await widget.loader(widget.item.extra.mid); if (mounted) setState(() { _info = info; _relation = info.relation; }); }
    catch (_) { if (mounted) setState(() => _info = const LiveProfileInfo()); }
    finally { if (mounted) setState(() => _loading = false); }
  }
  String get name => _info?.name.isNotEmpty == true ? _info!.name : widget.item.name;
  void _change(String page) => setState(() => _page = page);
  bool _login() { if (Accounts.main.isLogin) return true; SmartDialog.showToast('请先登录'); return false; }
  Future<void> _follow() async {
    if (!_login() || _following || _relation == null) return;
    setState(() => _following = true);
    try { await RequestUtils.actionRelationMod(context: context, mid: widget.item.extra.mid, isFollow: _relation == 2 || _relation == 6,
      afterMod: (value) { if (mounted) setState(() => _relation = value); }); }
    finally { if (mounted) setState(() => _following = false); }
  }
  @override Widget build(BuildContext context) {
    final b = widget.item.badges;
    return LivePanelSurface(child: Column(children: [
      LiveSheetHeading(title: switch (_page) { 'wealth' => '荣耀等级', 'medal' => '粉丝勋章', 'title' => '头衔信息', _ => '用户资料' },
        onBack: _page == 'profile' ? null : () => _change('profile')),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 16), child: _page == 'profile'
        ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              InkWell(onTap: () => Navigator.pop(context, 'space'), customBorder: const CircleBorder(), child: SizedBox.square(dimension: 64,
                child: _info?.face.isNotEmpty == true ? NetworkImgLayer(src: _info!.face, width: 64, height: 64, type: .avatar)
                  : const CircleAvatar(backgroundColor: Color(0xFF51485E), child: Icon(Icons.person_outline, color: Colors.white, size: 30)))),
              const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
                const SizedBox(height: 7), Text('粉丝 ${_info?.followers ?? '—'}    关注 ${_info?.following ?? '—'}', style: const TextStyle(color: Colors.white60, fontSize: 13)),
              ])),
            ]),
            if (_loading) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator(minHeight: 2)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: _entry('荣耀等级', '${b.wealth}', Icons.diamond_outlined, 'wealth', const Color(0xFF353045))),
              const SizedBox(width: 8), Expanded(child: _entry('粉丝团', b.medalName.isEmpty ? '未佩戴' : '${b.medalName} ${b.medalLevel}', Icons.favorite_outline, 'medal', const Color(0xFF3A2C38))),
            ]),
            const SizedBox(height: 10),
            _entry('头衔', b.title.isEmpty && b.titleImage.isEmpty ? '未佩戴' : b.title.isEmpty ? '已佩戴头衔' : b.title, Icons.workspace_premium_outlined, 'title', const Color(0xFF2A2833)),
            const SizedBox(height: 20),
            Row(children: [
              _round('更多', Icons.more_horiz, () => Navigator.pop(context, 'more')),
              const SizedBox(width: 8), _round('私信', Icons.mail_outline, () {
                if (!_login()) return;
                Navigator.pop(context);
                Get.toNamed('/whisperDetail', arguments: {'talkerId': widget.item.extra.mid, 'mid': widget.item.extra.mid, 'name': name, 'face': _info?.face ?? ''});
              }),
              const SizedBox(width: 8), _round('@TA', Icons.alternate_email, () { if (_login()) Navigator.pop(context, 'reply'); }),
              const SizedBox(width: 10), Expanded(child: FilledButton(onPressed: _following || widget.item.extra.mid == Accounts.main.mid || (Accounts.main.isLogin && _relation == null) ? null : _follow,
                style: FilledButton.styleFrom(backgroundColor: liveAccent, foregroundColor: const Color(0xFF2A1420), minimumSize: const Size(0, 46)),
                child: Text(_relation == 2 || _relation == 6 ? '已关注' : '+ 关注'))),
            ]),
            if (!_loading && _info?.face.isEmpty != false) TextButton(onPressed: () => Navigator.pop(context, 'space'), child: const Text('查看个人空间')),
          ])
        : _detail(b))),
    ]));
  }
  Widget _round(String label, IconData icon, VoidCallback action) => Material(color: const Color(0xFF2A2833), shape: const CircleBorder(),
    child: IconButton(tooltip: label, onPressed: action, icon: Icon(icon, size: 22)));
  Widget _entry(String label, String value, IconData icon, String page, Color color) => Material(color: color, borderRadius: BorderRadius.circular(12),
    child: InkWell(onTap: () => _change(page), borderRadius: BorderRadius.circular(12), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
      child: Row(children: [Icon(icon, size: 18, color: Colors.white70), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white60)),
      ])), const Icon(Icons.chevron_right, size: 17, color: Colors.white54)]))));
  Widget _detail(LiveUserBadges b) {
    if (_page == 'wealth') return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 15), const Icon(Icons.diamond_outlined, size: 48, color: Color(0xFFD0B3EA)),
      const SizedBox(height: 12), Text('荣耀等级 ${b.wealth}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 24)),
      const SizedBox(height: 8), Text(name, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
      const SizedBox(height: 24), ListTile(title: const Text('查看官方等级权益'), trailing: const Icon(Icons.open_in_new), onTap: () => PageUtils.launchURL('https://live.bilibili.com/p/html/wealth-rights-and-interests-pc/index.html')),
    ]);
    if (_page == 'medal') return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 12), Text(b.medalName.isEmpty ? '暂未佩戴粉丝勋章' : '${b.medalName}  ${b.medalLevel} 级', style: const TextStyle(fontSize: 22)),
      const SizedBox(height: 18), if (b.medalAnchorName.isNotEmpty) Text('勋章主播  ${b.medalAnchorName}'),
      if (b.medalAnchorUid > 0) ListTile(contentPadding: EdgeInsets.zero, title: const Text('查看勋章主播'), trailing: const Icon(Icons.chevron_right),
        onTap: () { Navigator.pop(context); Get.toNamed('/member?mid=${b.medalAnchorUid}'); }),
      const SizedBox(height: 14), const Text('粉丝团人数与直播状态以主播页面为准', style: TextStyle(fontSize: 12, color: Colors.white60)),
    ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 16), if (b.titleImage.isNotEmpty) Center(child: Image.network(b.titleImage, height: 52, fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.workspace_premium, size: 42))),
      const SizedBox(height: 12), Text(b.title.isEmpty ? '暂未提供头衔信息' : b.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22)),
      const SizedBox(height: 20), const Text('当前佩戴的直播头衔'),
      const SizedBox(height: 10), const Text('暂未提供获取条件和有效期信息', style: TextStyle(color: Colors.white60, fontSize: 13)),
    ]);
  }
}

Future<void> showLiveMessageActions(BuildContext context, LiveRoomController controller, DanmakuMsg item, {bool userMenu = false}) async {
  final selected = await showLivePanel<String>(context, (context) => LivePanelSurface(child: Column(children: [
    LiveSheetHeading(title: userMenu ? '用户操作' : '弹幕操作'),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10), child: DecoratedBox(
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .05), borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
        Text(item.text, maxLines: 3, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.4)),
        const SizedBox(height: 6), Text(item.name, style: const TextStyle(fontSize: 12, color: Colors.white60)),
      ])))),
    Expanded(child: ListView(children: [
      if (!userMenu) ListTile(leading: const Icon(Icons.reply), title: const Text('回复弹幕'), onTap: () => Navigator.pop(context, 'reply')),
      ListTile(leading: const Icon(Icons.flag_outlined), title: const Text('举报弹幕'), onTap: () => Navigator.pop(context, 'report')),
      if (userMenu) ...[
        ListTile(leading: const Icon(Icons.account_circle_outlined), title: const Text('举报头像'), onTap: () => Navigator.pop(context, 'avatar')),
        ListTile(leading: const Icon(Icons.badge_outlined), title: const Text('举报昵称'), onTap: () => Navigator.pop(context, 'name')),
        ListTile(leading: const Icon(Icons.copy_outlined), title: const Text('复制弹幕'), onTap: () => Navigator.pop(context, 'copy')),
      ],
      ListTile(leading: const Icon(Icons.person_off_outlined), title: const Text('屏蔽用户'), onTap: () => Navigator.pop(context, 'block')),
    ])),
  ])));
  if (!context.mounted || selected == null) return;
  if (selected == 'copy') { Utils.copyText(item.text); return; }
  if (!controller.isLogin) { controller.toastNotLogin(); return; }
  switch (selected) {
    case 'reply': controller.onAtUser(item);
    case 'report': HeaderControl.reportLiveDanmaku(context, roomId: controller.roomId, msg: item.text, extra: item.extra);
    case 'avatar': showMemberReportDialog(context, name: item.name, mid: item.extra.mid, initialReason: '头像违规');
    case 'name': showMemberReportDialog(context, name: item.name, mid: item.extra.mid, initialReason: '昵称违规');
    case 'block':
      final result = await LiveHttp.liveShieldUser(uid: item.extra.mid, roomid: controller.roomId, type: 1);
      if (result.isSuccess) { controller.addShieldUser(item.extra.mid); SmartDialog.showToast('已屏蔽此用户'); } else { result.toast(); }
  }
}
