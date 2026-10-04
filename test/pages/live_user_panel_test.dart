import 'package:PiliPlus/models_new/live/live_danmaku/danmaku_msg.dart';
import 'package:PiliPlus/models_new/live/live_danmaku/live_user_badges.dart';
import 'package:PiliPlus/pages/danmaku/danmaku_model.dart';
import 'package:PiliPlus/pages/live_room/widgets/live_action_menu.dart';
import 'package:PiliPlus/pages/live_room/widgets/live_panel_surface.dart';
import 'package:PiliPlus/pages/live_room/widgets/live_user_panel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/live_profile_storage.dart';

void main() {
  setUpLiveProfileStorage();
  testWidgets('iPhone 17 at 3x opens badge details and dismisses outside', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 186, bottom: 102);
    addTearDown(tester.view.reset);
    final item = DanmakuMsg(
      name: '测试观众',
      text: '一条用于检验布局的长中文弹幕',
      extra: LiveDanmaku(mid: 123, id: '1', dmType: 0, ts: 0, ct: ''),
      badges: const LiveUserBadges(
        wealth: 37,
        medalName: '汐音',
        medalLevel: 27,
        title: '测试头衔',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showLivePanel<void>(
                  context,
                  (_) => LiveUserPanel(
                    item: item,
                    loader: (_) async => const LiveProfileInfo(
                      name: '测试观众',
                      followers: 55,
                      following: 51,
                    ),
                  ),
                ),
                child: const Text('打开资料'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开资料'));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('live-panel-surface'))).width,
      402,
    );
    expect(find.text('粉丝 55    关注 51'), findsOneWidget);
    await tester.tap(find.text('荣耀等级'));
    await tester.pumpAndSettle();
    expect(find.text('荣耀等级 37'), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('头衔'));
    await tester.pumpAndSettle();
    expect(find.text('暂未提供获取条件和有效期信息'), findsOneWidget);
    await tester.tapAt(const Offset(20, 150));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('live-panel-surface')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'room tools open from a bottom icon menu without losing actions',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      int refreshed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showLiveActionMenu(
                  context,
                  title: '更多',
                  actions: [
                    LiveMenuAction('刷新', Icons.refresh, () => refreshed++),
                  ],
                ),
                child: const Text('打开更多'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开更多'));
      await tester.pumpAndSettle();
      expect(refreshed, 0);
      await tester.tap(find.text('刷新'));
      await tester.pumpAndSettle();
      expect(refreshed, 1);
      expect(find.byKey(const ValueKey('live-panel-surface')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test('anonymous badges never retain anchor or title identifiers', () {
    final b = LiveUserBadges.parse({
      'base': {'is_mystery': true},
      'medal': {'ruid': 12},
      'title': {'title_css_id': 'title-1-1'},
    });
    expect(b.medalAnchorUid, 0);
    expect(b.titleId, isEmpty);
  });
}
