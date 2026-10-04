import 'dart:io';
import 'dart:ui' as ui;

import 'package:PiliPlus/models_new/live/live_danmaku/live_room_notice.dart';
import 'package:PiliPlus/models_new/live/live_room_info_h5/room_info.dart';
import 'package:PiliPlus/models_new/live/live_wealth_assets.dart';
import 'package:PiliPlus/models_new/live/live_danmaku/live_message_parser.dart';
import 'package:PiliPlus/pages/live_room/live_room_settings.dart';
import 'package:PiliPlus/pages/live_room/widgets/gift_panel.dart';
import 'package:PiliPlus/pages/live_room/widgets/live_panel_surface.dart';
import 'package:PiliPlus/pages/live_room/widgets/live_settings_panel.dart';
import 'package:PiliPlus/pages/live_room/widgets/live_user_panel.dart';
import 'package:PiliPlus/pages/live_room/widgets/red_packet_panel.dart';
import 'package:PiliPlus/pages/live_room/widgets/superchat_purchase_panel.dart';
import 'package:PiliPlus/models_new/live/live_danmaku/danmaku_msg.dart';
import 'package:PiliPlus/models_new/live/live_danmaku/live_user_badges.dart';
import 'package:PiliPlus/pages/danmaku/danmaku_model.dart';
import 'package:PiliPlus/services/live_gift_service.dart';
import 'package:PiliPlus/services/live_red_packet_service.dart';
import 'package:PiliPlus/services/live_superchat_service.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/live_gift_fakes.dart';
import '../support/live_room_actions_fakes.dart';
import '../support/live_superchat_fakes.dart';
import '../support/live_profile_storage.dart';

LiveRoomSettings settings() =>
    LiveRoomSettings(read: (_) => null, write: (_, _) async {})..load();

Map<String, dynamic> splitCatalogue() => {
  'gift_config': {
    'base_config': {
      'list': [
        {...giftConfig(), 'id': 31164, 'name': '粉丝团灯牌'},
        {...giftConfig(), 'id': 33988, 'name': '人气票'},
        {...giftConfig(), 'id': 35970, 'name': '饭团'},
        {...giftConfig(), 'id': 35930, 'name': '星星之火'},
        {...giftConfig(), 'id': 34001, 'name': '粉丝团灯牌'},
        {...giftConfig(), 'id': 34102, 'name': '人气票'},
        {...giftConfig(price: 500), 'id': 30869, 'name': '心动卡'},
        {...giftConfig(price: 10000), 'id': 34931, 'name': '友谊的小船'},
      ],
    },
  },
  'gift_data': {
    'max_send_gift': 99,
    'room_gift_list': {
      'gold_list': [
        {'gift_id': 35970},
        {'gift_id': 33988},
        {'gift_id': 31164},
        {'gift_id': 35930},
        {'gift_id': 31164}, // repeated ID in one source is still displayed once
      ],
    },
    'tab_list': [
      {
        'tab_id': 9,
        'tab_name': '粉丝团',
        'list': [
          {'gift_id': 34001},
          {'gift_id': 34102},
          {'gift_id': 30869},
        ],
      },
      {
        'tab_id': 2,
        'tab_name': '航海',
        'list': [
          {
            'gift_id': 34931,
            'special': {'is_use': 0, 'tips': '需要大航海权限'},
          },
        ],
      },
    ],
  },
};

const captureKey = ValueKey('mobile-layout-capture');

Widget preview(
  WidgetBuilder panel, {
  TargetPlatform platform = TargetPlatform.iOS,
}) => MaterialApp(
  theme: ThemeData(
    platform: platform,
    brightness: Brightness.dark,
    fontFamily: Platform.environment['CJK_TEST_FONT'] == null
        ? null
        : 'MobilePreview',
  ),
  builder: (context, child) => RepaintBoundary(key: captureKey, child: child!),
  home: Scaffold(
    backgroundColor: const Color(0xFF12121A),
    body: SafeArea(
      child: Column(
        children: [
          const ListTile(
            leading: CircleAvatar(child: Icon(Icons.person)),
            title: Text('直播布局回归样例'),
            subtitle: Text('保留画面 · 面板不盖住视频'),
          ),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              key: const ValueKey('video-region'),
              color: const Color(0xFF30324A),
              alignment: Alignment.center,
              child: const Text(
                '直播画面区域 · 16:9',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showLivePanel<void>(context, panel),
                    child: const Text('打开面板'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);

Future<void> capture(WidgetTester tester, String name) async {
  if (Platform.environment['LIVE_UI_CAPTURE'] != '1') return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(captureKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final output = Directory('build/live-ui');
    await output.create(recursive: true);
    await File('${output.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpLiveProfileStorage();
  test('mobile room skin rejects defaults and never substitutes the cover', () {
    expect(
      RoomInfo.fromJson({'cover': 'https://i0.hdslb.com/cover.jpg'})
          .appBackground,
      isNull,
    );
    expect(customLiveBackground(''), isNull);
    expect(
      customLiveBackground(
        'https://i0.hdslb.com/bfs/live/785922a49980e1aa3239249c8360909488940d7d.jpg',
      ),
      isNull,
    );
    expect(
      customLiveBackground('http://i0.hdslb.com/bfs/live/custom.jpg'),
      'https://i0.hdslb.com/bfs/live/custom.jpg',
    );
    expect(customLiveBackground('file:///tmp/background.jpg'), isNull);
  });
  test('official wealth images preserve the complete per-level artwork', () {
    expect(liveWealthAssets.length, 80);
    expect(
      liveWealthAssets[37],
      endsWith('fe08f62c736f93362b307d02f13beff0bd630d61.png'),
    );
    expect(liveWealthAssets[0], isNull);
  });
  test(
    'fan progress belongs to this anchor and missing thresholds stay unknown',
    () {
      Map<String, dynamic> info(int uid, {int? next}) => {
        'fans_medal_info': {
          'received': true,
          'current': {
            'medal': {
              'target_id': uid,
              'medal_name': '测试勋章',
              'level': 27,
              'intimacy': 722,
              if (next != null) 'next_intimacy': next,
            },
          },
        },
      };
      expect(
        LiveMedalProgress.fromGiftMessage(info(301, next: 2000), 300),
        isNull,
      );
      final medal = LiveMedalProgress.fromGiftMessage(
        info(300, next: 2000),
        300,
      )!;
      expect(medal.remaining, 1278);
      expect(medal.fraction, .361);
      expect(
        LiveMedalProgress.fromGiftMessage(info(300), 300)!.fraction,
        isNull,
      );
      expect(
        LiveMedalProgress.fromGiftMessage(info(300, next: 0), 300)!.remaining,
        isNull,
      );
      expect(
        LiveMedalProgress.fromGiftMessage(info(300, next: 100), 300)!.fraction,
        1,
      );
    },
  );
  setUpAll(() async {
    final path = Platform.environment['CJK_TEST_FONT'];
    if (path != null) {
      TestWidgetsFlutterBinding.ensureInitialized();
      final loader = FontLoader('MobilePreview');
      loader.addFont(
        File(path).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
      await loader.load();
      final icons = FontLoader('MaterialIcons');
      icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
  });

  test('broadcast scope, guard, likes, room status and moderation are independently filtered', () async {
    final prefs = settings();
    final foreign = LiveRoomNotice.parse({
      'cmd': 'NOTICE_MSG',
      'real_roomid': 20,
      'msg_common': '另一直播间的广播',
      'msg_self': '本房间文本',
    }, 10)!;
    final own = LiveRoomNotice.parse({
      'cmd': 'NOTICE_MSG',
      'real_roomid': 10,
      'msg_common': '全站文本',
      'msg_self': '本房间广播',
    }, 10)!;
    expect(foreign.kind, LiveNoticeKind.globalBroadcast);
    expect(own.kind, LiveNoticeKind.roomBroadcast);
    expect(own.text, '本房间广播');
    await prefs.set(LiveRoomOption.globalBroadcasts, false);
    expect(prefs.allows(foreign), isFalse);
    expect(prefs.allows(own), isTrue);
    for (final (cmd, data, option) in [
      ('USER_TOAST_MSG', {'toast_msg': '开通大航海'}, LiveRoomOption.guardMessages),
      ('LIKE_INFO_V3_CLICK', {'like_text': '点赞了'}, LiveRoomOption.likeNotices),
      ('ROOM_CHANGE', {'title': '新标题'}, LiveRoomOption.roomStatusNotices),
      ('WARNING', {'msg': '房间警告'}, LiveRoomOption.moderationNotices),
      ('HOT_RANK_CHANGED', {'rank_desc': '榜单变化'}, LiveRoomOption.rankNotices),
    ]) {
      final notice = LiveRoomNotice.parse({'cmd': cmd, 'data': data}, 10)!;
      expect(prefs.allows(notice), isTrue, reason: cmd);
      await prefs.set(option, false);
      expect(prefs.allows(notice), isFalse, reason: cmd);
      expect(prefs.allows(own), isTrue);
    }
    final guard = LiveGiftMessage.parse({
      'cmd': 'GUARD_BUY',
      'data': {
        'username': '观众',
        'gift_name': '舰长',
        'num': 1,
      },
    })!;
    expect(prefs.allows(guard), isFalse);
    await prefs.set(LiveRoomOption.guardMessages, true);
    await prefs.set(LiveRoomOption.giftMessages, false);
    expect(prefs.allows(guard), isTrue);
  });

  test('split switches inherit hidden legacy categories without changing explicit new choices', () {
    final prefs = LiveRoomSettings(
      read: (key) => key == LiveRoomSettings.storageKey
          ? {
              'giftBroadcasts': false,
              'roomNotices': false,
              'likeNotices': true,
            }
          : null,
    )..load();
    expect(prefs.enabled(LiveRoomOption.globalBroadcasts), isFalse);
    expect(prefs.enabled(LiveRoomOption.guardMessages), isFalse);
    expect(prefs.enabled(LiveRoomOption.roomStatusNotices), isFalse);
    expect(prefs.enabled(LiveRoomOption.moderationNotices), isFalse);
    expect(prefs.enabled(LiveRoomOption.likeNotices), isTrue);
    expect(prefs.enabled(LiveRoomOption.entryNotices), isTrue);
  });

  for (final size in [
    const Size(402, 874),
    const Size(393, 852),
    const Size(360, 640),
  ]) {
    testWidgets(
      'gift panel preserves portrait video and separates same-name IDs at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final transport = FakeTransport()
          ..catalogData = splitCatalogue()
          ..fansMedal = {
            'medal': {
              'target_id': 300,
              'medal_name': '测试勋章',
              'level': 27,
              'intimacy': 722,
              'next_intimacy': 2000,
            },
          };
        final account = LiveGiftAccount(100, FakeLoginIdentity(), 'test-csrf');
        final service = LiveGiftService(
          roomId: 200,
          anchorUid: 300,
          transport: transport,
          journal: FakeJournal(),
          currentAccount: () => account,
        );
        addTearDown(service.dispose);
        await tester.pumpWidget(
          preview((_) => LiveGiftPanel(service: service, anchorName: '测试主播')),
        );
        await tester.tap(find.text('打开面板'));
        await tester.pumpAndSettle();
        final panel = tester.getRect(
          find.byKey(const ValueKey('live-panel-surface')),
        );
        final video = tester.getRect(
          find.byKey(const ValueKey('video-region')),
        );
        expect(panel.top, greaterThanOrEqualTo(video.bottom));
        expect(panel.height, lessThanOrEqualTo(496));
        expect(find.byKey(const ValueKey('live-gift-31164-0')), findsOneWidget);
        expect(find.byKey(const ValueKey('live-gift-34001-0')), findsNothing);
        expect(find.text('粉丝团灯牌'), findsOneWidget);
        expect(find.text('人气票'), findsOneWidget);
        expect(find.text('升级还需 1278 亲密度'), findsOneWidget);
        await capture(tester, 'ios-gifts-${size.width.toInt()}');
        await tester.tap(find.byKey(const ValueKey('gift-tab-粉丝团')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('live-gift-31164-0')), findsNothing);
        expect(find.byKey(const ValueKey('live-gift-34001-0')), findsOneWidget);
        expect(find.text('饭团'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('gift-tab-航海')));
        await tester.pumpAndSettle();
        expect(find.text('友谊的小船'), findsOneWidget);
        expect(find.text('粉丝团灯牌'), findsNothing);
        expect(transport.postCount, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'iOS settings preserve portrait video and expose the global broadcast switch',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final prefs = settings();
      await tester.pumpWidget(
        preview(
          (_) => LiveSettingsPanel(
            settings: prefs,
            initialSection: LiveSettingsSection.notifications,
            onDisplaySettings: () {},
            onBlockRules: () {},
          ),
        ),
      );
      await tester.tap(find.text('打开面板'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('live-panel-surface'))).dy,
        greaterThanOrEqualTo(
          tester.getBottomRight(find.byKey(const ValueKey('video-region'))).dy,
        ),
      );
      final global = find.byKey(const ValueKey('globalBroadcasts'));
      await tester.ensureVisible(global);
      await tester.pumpAndSettle();
      await tester.tap(global);
      await tester.pumpAndSettle();
      expect(prefs.enabled(LiveRoomOption.globalBroadcasts), isFalse);
      expect(prefs.enabled(LiveRoomOption.giftBroadcasts), isTrue);
      await capture(tester, 'ios-notifications');
      expect(tester.takeException(), isNull);
    },
  );

  test('landscape panel leaves at least half the screen for the video', () {
    final panel = livePanelSize(const MediaQueryData(size: Size(740, 360)));
    expect(panel.width, lessThanOrEqualTo(370));
    expect(panel.height, lessThanOrEqualTo(360));
  });

  for (final kind in ['profile', 'red-packet', 'superchat']) {
    testWidgets('iPhone 17 safe-area $kind panel fits and dismisses outside', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1206, 2622);
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(top: 186, bottom: 102);
      addTearDown(tester.view.reset);
      final transport = kind == 'superchat'
          ? ScTransport()
          : ActivityTransport();
      final account = LiveGiftAccount(100, FakeLoginIdentity(), 'test');
      final gifts = LiveGiftService(
        roomId: 200,
        anchorUid: 300,
        transport: transport,
        journal: FakeJournal(),
        currentAccount: () => account,
      );
      await tester.pumpWidget(
        preview(
          (_) => switch (kind) {
            'profile' => LiveUserPanel(
              item: DanmakuMsg(
                name: '测试观众',
                text: '测试弹幕',
                extra: const LiveDanmaku(
                  mid: 123,
                  id: '1',
                  dmType: 0,
                  ts: 0,
                  ct: '',
                ),
                badges: const LiveUserBadges(
                  wealth: 37,
                  medalName: '汐音',
                  medalLevel: 27,
                  title: '测试头衔',
                ),
              ),
              loader: (_) async => const LiveProfileInfo(
                name: '测试观众',
                followers: 55,
                following: 51,
              ),
            ),
            'red-packet' => LiveRedPacketPanel(
              service: LiveRedPacketService(gifts),
              anchorName: '测试主播',
            ),
            _ => LiveSuperChatPurchasePanel(
              service: LiveSuperChatService(gifts),
              anchorName: '测试主播',
            ),
          },
        ),
      );
      await tester.tap(find.text('打开面板'));
      await tester.pumpAndSettle();
      final panel = find.byKey(const ValueKey('live-panel-surface'));
      expect(tester.getSize(panel).width, 402);
      expect(
        tester.getTopLeft(panel).dy,
        greaterThanOrEqualTo(
          tester.getBottomRight(find.byKey(const ValueKey('video-region'))).dy,
        ),
      );
      expect(tester.takeException(), isNull);
      await capture(tester, 'ios17-$kind');
      await tester.tapAt(const Offset(20, 150));
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(transport.postCount, 0);
      await tester.pumpWidget(const SizedBox());
      gifts.dispose();
    });
  }
}
