import 'package:PiliPlus/models_new/live/live_danmaku_style.dart';
import 'package:PiliPlus/pages/live_room/widgets/danmaku_style_panel.dart';
import 'package:PiliPlus/pages/live_room/widgets/superchat_purchase_panel.dart';
import 'package:PiliPlus/services/live_gift_service.dart';
import 'package:PiliPlus/services/live_superchat_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/live_gift_fakes.dart';
import '../support/live_superchat_fakes.dart';

LiveDanmakuStyleConfig styles() => LiveDanmakuStyleConfig.parse({
  'mode': [
    {'mode': 1, 'name': '滚动', 'status': 1},
    {'mode': 4, 'name': '底部', 'status': 0},
    {'mode': 5, 'name': '顶部', 'status': 1},
  ],
  'group': [
    {
      'name': '普通',
      'color': [
        {'color_hex': 'ffffff', 'name': '白色', 'status': 1},
        {'color_hex': 'ff0000', 'name': '红色', 'status': 0},
      ],
    },
    {
      'name': '航海',
      'color': [
        {'color_hex': '00ffff', 'name': '青色', 'status': 1},
      ],
    },
  ],
});

void main() {
  test('style permissions never infer unlock from a color or position', () {
    final config = styles();
    expect(config.permits(1, 0xffffff), isTrue);
    expect(config.permits(4, 0xffffff), isFalse);
    expect(config.permits(1, 0xff0000), isFalse);
    expect(LiveDanmakuStyleConfig.parse({}).permits(1, 0xffffff), isFalse);
  });
  testWidgets('style locks and grouped colors fit 320px mobile dialog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
          body: LiveDanmakuStylePanel(
            config: styles(),
            mode: 1,
            color: 0xffffff,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '底部'))
          .onSelected,
      isNull,
    );
    expect(find.text('航海'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.windows,
  ]) {
    testWidgets('SC configuration and cancellation at 360px on $platform', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final transport = ScTransport();
      final account = LiveGiftAccount(100, FakeLoginIdentity(), 'test');
      final gifts = LiveGiftService(
        roomId: 200,
        anchorUid: 300,
        transport: transport,
        journal: FakeJournal(),
        currentAccount: () => account,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: LiveSuperChatPurchasePanel(
              service: LiveSuperChatService(gifts),
              anchorName: '测试主播',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('20 电池 · 5 秒\n限一次'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '测试醒目留言');
      await tester.pump();
      final send = find.widgetWithText(FilledButton, '购买并发送 · 20 电池');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('确认购买醒目留言'), findsOneWidget);
      expect(find.textContaining('总费用：20 电池'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(transport.postCount, 0);
      await tester.pumpWidget(const SizedBox());
      gifts.dispose();
    });
  }
  for (final dimensions in [const Size(320, 568), const Size(740, 360)]) {
    testWidgets(
      'SC custom amount remains usable with keyboard at $dimensions',
      (tester) async {
        tester.view.physicalSize = dimensions;
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 200);
        addTearDown(tester.view.reset);
        final account = LiveGiftAccount(100, FakeLoginIdentity(), 'test');
        final transport = ScTransport();
        final gifts = LiveGiftService(
          roomId: 200,
          anchorUid: 300,
          transport: transport,
          journal: FakeJournal(),
          currentAccount: () => account,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: TargetPlatform.android),
            home: Scaffold(
              resizeToAvoidBottomInset: false,
              body: LiveSuperChatPurchasePanel(
                service: LiveSuperChatService(gifts),
                anchorName: '长名字的测试主播',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(TextField).last);
        await tester.enterText(find.byType(TextField).last, '400');
        await tester.pump();
        await tester.ensureVisible(
          find.widgetWithText(FilledButton, '购买并发送 · 400 电池'),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(transport.postCount, 0);
        await tester.pumpWidget(const SizedBox());
        gifts.dispose();
      },
    );
  }
}
