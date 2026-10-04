import 'dart:async';

import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/live/live_contribution_rank/item.dart';
import 'package:PiliPlus/models_new/live/live_contribution_rank/data.dart';
import 'package:PiliPlus/pages/live_room/contribution_rank/controller.dart';
import 'package:PiliPlus/pages/live_room/contribution_rank/view.dart';
import 'package:PiliPlus/pages/live_room/widgets/guard_rank_panel.dart';
import 'package:PiliPlus/pages/live_room/widgets/live_panel_surface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Map<String, dynamic> ranks(String name, {int pages = 1}) => {
  'info': {'page': pages, 'num': 2},
  'top3': [
    {
      'uid': 99,
      'name': 'hidden-name',
      'face': 'https://example.invalid/hidden-face.png',
      'rank': 1,
      'uinfo': {
        'base': {'is_mystery': 1},
        'guard': {'level': 3},
      },
    },
  ],
  'list': [
    {'uid': 8, 'name': name, 'rank': 2},
  ],
  'my_follow_info': {
    'rank': 6,
    'uinfo': {
      'uid': 9,
      'base': {'name': '测试账号很长的昵称需要在手机上正常显示'},
      'guard': {'level': 2},
    },
  },
};

Future<void> mount(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(360, 640),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('dark panel chips remain legible over a light app chip theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(
          chipTheme: const ChipThemeData(
            backgroundColor: Colors.white,
            labelStyle: TextStyle(color: Colors.black),
          ),
        ),
        home: Scaffold(
          body: LivePanelSurface(
            child: LiveChoiceChip(
              label: const Text('月榜'),
              selected: false,
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    final theme = Theme.of(tester.element(find.text('月榜')));
    final fill = Color.alphaBlend(
      theme.chipTheme.backgroundColor!,
      livePanelBackground,
    );
    final label = Color.alphaBlend(theme.chipTheme.labelStyle!.color!, fill);
    expect(
      (label.computeLuminance() + .05) / (fill.computeLuminance() + .05),
      greaterThan(4.5),
    );
    expect(tester.takeException(), isNull);
  });

  test(
    'contribution pagination preserves own rank until the next first page',
    () {
      final controller = ContributionRankController(
        ruid: 10,
        roomId: 20,
        type: .online_rank,
      );
      addTearDown(controller.onClose);
      final own = LiveContributionRankItem(uid: 1, rank: 9);
      controller.getDataList(LiveContributionRankData(own: own));
      controller.page = 2;
      controller.getDataList(LiveContributionRankData());
      expect(controller.own.value, same(own));
      controller.page = 1;
      controller.getDataList(LiveContributionRankData());
      expect(controller.own.value, isNull);
    },
  );

  test(
    'contribution rank retains server position and distinguishes missing rank',
    () {
      final item = LiveContributionRankItem.fromJson({
        'uid': '8',
        'name': '观众',
        'rank': '17',
        'score': '123',
      });
      expect(item.rank, 17);
      expect(item.score, 123);
      expect(LiveContributionRankItem.fromJson({}).rank, isNull);
      expect(LiveContributionRankItem.fromJson({'rank': -1}).rank, -1);
    },
  );

  testWidgets('own rank and long name fit 320px at double text scale', (
    tester,
  ) async {
    await mount(
      tester,
      LiveOwnRankTile(
        item: LiveContributionRankItem(
          name: '很长的观众昵称需要在窄屏和大字体下正确显示',
          rank: 17,
          score: 123456,
        ),
        online: true,
      ),
      size: const Size(320, 240),
      scale: 2,
    );
    await tester.pumpAndSettle();
    expect(find.text('名次 #17 · 贡献 123456'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'own rank shows online 100 plus, unranked and unavailable states',
    (tester) async {
      for (final entry in [
        (rank: -1, online: true, label: '100+'),
        (rank: -1, online: false, label: '未上榜'),
        (rank: null, online: true, label: '—'),
      ]) {
        await mount(
          tester,
          LiveOwnRankTile(
            item: LiveContributionRankItem(name: '观众', rank: entry.rank),
            online: entry.online,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('名次 ${entry.label} · 贡献 —'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  for (final compact in [false, true]) {
    testWidgets(
      'guard rank retains own footer and anonymity, compact=$compact',
      (tester) async {
        await mount(
          tester,
          LiveGuardRankPanel(
            roomId: 10,
            ruid: 20,
            embedded: true,
            loadRank: (_, _) async => Success(ranks('正常观众')),
          ),
          size: compact ? const Size(320, 240) : const Size(360, 640),
          scale: compact ? 2 : 1,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (compact) {
          final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
          expect(scroll.position.maxScrollExtent, greaterThan(0));
          // Re-evaluate the extent as the lazy list builds its remaining rows.
          for (var attempt = 0; attempt < 5; attempt++) {
            scroll.position.jumpTo(scroll.position.maxScrollExtent);
            await tester.pumpAndSettle();
            if (find.text('在官方页面上舰').hitTestable().evaluate().isNotEmpty) {
              break;
            }
          }
        }
        expect(find.textContaining('我 · 测试账号'), findsOneWidget);
        expect(find.text('#6'), findsOneWidget);
        expect(find.text('提督'), findsOneWidget);
        expect(find.text('在官方页面上舰'), findsOneWidget);
        expect(find.text('在官方页面上舰').hitTestable(), findsOneWidget);
        expect(find.text('hidden-name'), findsNothing);
        expect(find.text('舰长'), findsNothing);
        expect(
          tester
              .widgetList<NetworkImgLayer>(find.byType(NetworkImgLayer))
              .every((image) => image.src?.contains('hidden-face') != true),
          isTrue,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('late weekly response cannot overwrite selected monthly rank', (
    tester,
  ) async {
    final weekly = Completer<LoadingState<Map<String, dynamic>>>();
    await mount(
      tester,
      LiveGuardRankPanel(
        roomId: 10,
        ruid: 20,
        embedded: true,
        loadRank: (type, _) =>
            type == 4 ? weekly.future : Future.value(Success(ranks('月榜观众'))),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('月榜'));
    await tester.pumpAndSettle();
    expect(find.text('月榜观众'), findsOneWidget);
    weekly.complete(Success(ranks('过期周榜观众')));
    await tester.pumpAndSettle();
    expect(find.text('月榜观众'), findsOneWidget);
    expect(find.text('过期周榜观众'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'guard pagination preserves own footer when later pages omit it',
    (tester) async {
      await mount(
        tester,
        LiveGuardRankPanel(
          roomId: 10,
          ruid: 20,
          embedded: true,
          loadRank: (_, page) async => Success(
            page == 1
                ? ranks('第一页', pages: 2)
                : {
                    'list': [
                      {'uid': 10, 'name': '第二页', 'rank': 3},
                    ],
                  },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('加载更多'));
      await tester.pumpAndSettle();
      expect(find.text('第二页'), findsOneWidget);
      expect(find.textContaining('我 · 测试账号'), findsOneWidget);
      expect(find.text('#6'), findsOneWidget);
      expect(find.text('大航海 · 2'), findsOneWidget);
      expect(find.text('加载更多'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed tab refresh does not expose previous pagination', (
    tester,
  ) async {
    final calls = <(int, int)>[];
    await mount(
      tester,
      LiveGuardRankPanel(
        roomId: 10,
        ruid: 20,
        embedded: true,
        loadRank: (type, page) async {
          calls.add((type, page));
          return type == 3
              ? const Error('月榜暂不可用')
              : Success(ranks('周榜观众', pages: 3));
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('加载更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('月榜'));
    await tester.pumpAndSettle();
    expect(find.text('月榜暂不可用'), findsOneWidget);
    expect(find.text('加载更多'), findsNothing);
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(calls, [(4, 1), (4, 2), (3, 1), (3, 1)]);
    expect(tester.takeException(), isNull);
  });
}
