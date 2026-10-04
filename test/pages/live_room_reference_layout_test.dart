import 'dart:io';
import 'package:PiliPlus/pages/live_room/widgets/mobile_room_layout.dart';
import 'package:PiliPlus/pages/live_room/widgets/room_header.dart';
import 'package:PiliPlus/pages/live_room/widgets/room_composer.dart';
import 'package:PiliPlus/pages/live_room/widgets/chat_line.dart';
import 'package:PiliPlus/pages/live_room/widgets/wealth_badge.dart';
import 'package:PiliPlus/pages/live_room/widgets/gift_panel.dart';
import 'package:PiliPlus/pages/live_room/widgets/live_panel_surface.dart';
import 'package:PiliPlus/services/live_gift_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import '../support/live_gift_fakes.dart';
import '../support/live_profile_storage.dart';
import 'live_mobile_layout_test.dart' show capture, captureKey, splitCatalogue;

void main() {
  setUpLiveProfileStorage();
  final fixtures = <String, MemoryImage>{};
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final name in ['room-background.jpg', 'anchor-avatar.jpg', 'live-frame.jpg', 'wealth-37.png']) {
      fixtures[name] = MemoryImage(File('test/fixtures/live_ui/$name').readAsBytesSync());
    }
    final font = Platform.environment['CJK_TEST_FONT'];
    if (font != null) {
      final loader = FontLoader('MobilePreview')
        ..addFont(File(font).readAsBytes().then(ByteData.sublistView));
      await loader.load();
      await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  for (final scenario in ['horizontal', 'portrait', 'default', 'narrow']) {
    testWidgets('production mobile controls and source layout: $scenario', (tester) async {
      final narrow = scenario == 'narrow';
      final size = narrow ? const Size(360, 640) : const Size(402, 874);
      final portrait = scenario == 'portrait';
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      tester.view.padding = narrow ? const FakeViewPadding(top: 72, bottom: 72)
        : const FakeViewPadding(top: 186, bottom: 102);
      addTearDown(tester.view.reset);
      final transport = FakeTransport()
        ..catalogData = splitCatalogue()
        ..fansMedal = {'medal': {'target_id': 300, 'medal_name': '测试勋章',
          'level': 27, 'intimacy': 722, 'next_intimacy': 2000}};
      final account = LiveGiftAccount(100, FakeLoginIdentity(), 'test');
      final service = LiveGiftService(roomId: 200, anchorUid: 300,
        transport: transport, journal: FakeJournal(), currentAccount: () => account);
      addTearDown(service.dispose);
      bool clean = false;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, platform: TargetPlatform.iOS,
          fontFamily: Platform.environment['CJK_TEST_FONT'] == null ? null : 'MobilePreview'),
        builder: (context, child) => RepaintBoundary(key: captureKey, child: child!),
        home: Material(child: StatefulBuilder(builder: (context, setState) {
          final safe = MediaQuery.paddingOf(context);
          Widget avatar() => ClipOval(child: Image(image: fixtures['anchor-avatar.jpg']!, fit: BoxFit.cover));
          return Stack(children: [
            Positioned.fill(child: LiveRoomBackdrop(image: scenario == 'default' ? null : fixtures['room-background.jpg'])),
            LiveMobileRoomLayout(
              portraitSource: portrait, aspectRatio: portrait ? 9 / 16 : 16 / 9,
              padding: safe, cleanScreen: clean, onCleanScreen: () => setState(() => clean = !clean),
              header: AppBar(toolbarHeight: 62, leadingWidth: 32, titleSpacing: 0,
                backgroundColor: Colors.transparent, foregroundColor: Colors.white,
                leading: const Icon(Icons.chevron_left),
                title: LiveAnchorChip(avatar: avatar(), name: '我妻幼雪Yukiko', subtitle: '直播间布局样例',
                  followed: false, onProfile: () {}, onFollow: () {}),
                actions: [
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: LiveAudienceButton(avatars: [avatar(), avatar(), avatar()], count: '387', onTap: () {})),
                  IconButton(onPressed: () {}, constraints: const BoxConstraints.tightFor(width: 30, height: 40),
                    padding: EdgeInsets.zero, icon: const Icon(Icons.more_vert, size: 20)),
                ]),
              videoBuilder: (_) => portrait
                ? const ColoredBox(color: Color(0xFF28313B), child: Center(child: Text('竖屏直播源 · 测试帧')))
                : Image(image: fixtures['live-frame.jpg']!, fit: BoxFit.contain),
              chat: ListView.separated(padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                itemCount: 9, separatorBuilder: (_, _) => const SizedBox(height: 2),
                itemBuilder: (_, i) => LiveChatLine(content: TextSpan(children: [
                  WidgetSpan(alignment: PlaceholderAlignment.middle,
                    child: Padding(padding: const EdgeInsets.only(right: 4),
                      child: LiveWealthBadge(level: 37, image: fixtures['wealth-37.png']))),
                  TextSpan(text: '测试观众${i + 1}: ', style: const TextStyle(color: Color(0xFFA5DFEA))),
                  TextSpan(text: i.isEven ? '晚上好，今天也来看直播啦' : '这条消息用于检查聊天行距和换行。'),
                ]))),
              composer: LiveRoomComposer(bottomPadding: safe.bottom, onCompose: () {}, onEmoji: () {},
                likeButton: const CircleAvatar(backgroundColor: Color(0x70263041),
                  child: Icon(Icons.thumb_up_off_alt, size: 19, color: Colors.white)),
                onGift: () => showLivePanel<void>(context, (_) => LiveGiftPanel(service: service, anchorName: '测试主播'))),
            ),
          ]);
        })),
      ));
      await tester.runAsync(() async {
        final context = tester.element(find.byType(LiveMobileRoomLayout));
        await Future.wait(fixtures.values.map((image) => precacheImage(image, context)));
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final video = tester.getRect(find.byKey(const ValueKey('live-source-video')));
      if (portrait) {
        expect(video.size, size);
      } else {
        expect(video.width / video.height, closeTo(16 / 9, .001));
        expect(video.top, narrow ? 94 : 132);
      }
      expect(tester.getSize(find.byKey(const ValueKey('live-audience-count'))), const Size(28, 28));
      final firstLine = tester.getRect(find.byType(LiveChatLine).first);
      expect(firstLine.height, lessThan(50));
      await capture(tester, 'room-$scenario');
      if (portrait) {
        await tester.tap(find.byTooltip('清屏'));
        await tester.pumpAndSettle();
        expect(find.byType(LiveRoomComposer), findsNothing);
        expect(find.byTooltip('退出清屏'), findsOneWidget);
        expect(tester.getRect(find.byKey(const ValueKey('live-source-video'))), video);
      } else {
        await tester.tap(find.byTooltip('礼物'));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.byKey(const ValueKey('live-panel-surface'))).dy,
          greaterThanOrEqualTo(video.bottom));
        expect(find.text('升级还需 1278 亲密度'), findsOneWidget);
        await capture(tester, 'room-$scenario-gifts');
      }
      expect(transport.postCount, 0);
      expect(tester.takeException(), isNull);
    });
  }
}
