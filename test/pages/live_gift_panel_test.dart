import 'package:PiliPlus/pages/live_room/widgets/gift_panel.dart';
import 'package:PiliPlus/services/live_gift_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/live_gift_fakes.dart';

Future<void> openGiftPanel(WidgetTester tester, LiveGiftService service) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: LiveGiftPanel(service: service, anchorName: '测试主播'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late FakeTransport transport;
  late LiveGiftService service;

  setUp(() {
    transport = FakeTransport();
    final account = LiveGiftAccount(100, FakeLoginIdentity(), 'test-csrf');
    service = LiveGiftService(
      roomId: 200,
      anchorUid: 300,
      transport: transport,
      journal: FakeJournal(),
      currentAccount: () => account,
    );
  });
  tearDown(() => service.dispose());

  testWidgets(
    'paid confirmation shows account, recipient, quantity and exact charge',
    (tester) async {
      await openGiftPanel(tester, service);
      await tester.tap(find.text('测试礼物'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '2');
      await tester.tap(find.text('赠送'));
      await tester.pumpAndSettle();
      expect(find.text('确认赠送礼物'), findsOneWidget);
      expect(find.textContaining('账号 UID：100'), findsOneWidget);
      expect(find.textContaining('测试主播（UID 300）'), findsOneWidget);
      expect(find.textContaining('测试礼物 × 2'), findsOneWidget);
      expect(find.textContaining('合计：2 电池'), findsOneWidget);
      expect(transport.postCount, 0);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(transport.postCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('bag gift requires confirmation and has zero battery cost', (
    tester,
  ) async {
    await openGiftPanel(tester, service);
    await tester.tap(find.text('背包礼物'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('测试礼物'));
    await tester.pump();
    await tester.tap(find.text('赠送'));
    await tester.pumpAndSettle();
    expect(find.textContaining('使用背包库存：1 个'), findsOneWidget);
    expect(find.textContaining('电池费用：0'), findsOneWidget);
    expect(transport.postCount, 0);
    await tester.tap(find.text('确认赠送'));
    await tester.pumpAndSettle();
    expect(transport.postCount, 1);
    expect(transport.sentPath, LiveGiftService.sendBagPath);
    expect(find.text('赠送成功'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty input does not send or open a confirmation', (
    tester,
  ) async {
    await openGiftPanel(tester, service);
    await tester.tap(find.text('测试礼物'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('赠送'));
    await tester.pumpAndSettle();
    expect(find.text('确认赠送礼物'), findsNothing);
    expect(transport.postCount, 0);
    expect(find.textContaining('请输入'), findsOneWidget);
  });

  testWidgets('gift panel fits a small portrait viewport with keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.reset);
    await openGiftPanel(tester, service);
    await tester.tap(find.text('测试礼物'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
