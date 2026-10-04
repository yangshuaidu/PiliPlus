import 'package:PiliPlus/pages/live_room/widgets/red_packet_panel.dart';
import 'package:PiliPlus/services/live_gift_service.dart';
import 'package:PiliPlus/services/live_red_packet_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/live_gift_fakes.dart';
import '../support/live_room_actions_fakes.dart';

class RecoveringRedTransport extends ActivityTransport {
  bool limited = true;
  @override
  Future<Map<String, dynamic>> get(
    String path,
    Map<String, dynamic> query,
    LiveGiftAccount account,
  ) {
    if (limited && path.endsWith('/RedPocketDetail')) {
      return Future.value({'code': -1, 'message': '红包数量超过限制'});
    }
    return super.get(path, query, account);
  }
}

void main() {
  testWidgets('successful refresh clears a previous server limit error', (
    tester,
  ) async {
    final transport = RecoveringRedTransport();
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
        home: Scaffold(
          body: LiveRedPacketPanel(
            service: LiveRedPacketService(gifts),
            anchorName: '测试主播',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('红包数量超过限制'), findsOneWidget);
    transport.limited = false;
    await tester.tap(find.text('刷新套餐'));
    await tester.pumpAndSettle();
    expect(find.text('红包数量超过限制'), findsNothing);
    expect(find.byType(ListTile), findsWidgets);
    expect(transport.postCount, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    gifts.dispose();
  });

  testWidgets('native red packet tabs and confirmation fit narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transport = ActivityTransport();
    final account = LiveGiftAccount(100, FakeLoginIdentity(), 'test');
    final gifts = LiveGiftService(
      roomId: 200,
      anchorUid: 300,
      transport: transport,
      journal: FakeJournal(),
      currentAccount: () => account,
    );
    final service = LiveRedPacketService(gifts);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveRedPacketPanel(service: service, anchorName: '测试主播'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('礼物红包'), findsOneWidget);
    expect(find.text('上舰红包'), findsOneWidget);
    expect(find.text('电池红包'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('电池红包'));
    await tester.pumpAndSettle();
    expect(find.textContaining('10 电池'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('发红包 · 10 电池'), 120,
      scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('发红包 · 10 电池'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('确认发送电池红包'), findsOneWidget);
    expect(find.textContaining('账号 UID：100'), findsOneWidget);
    expect(find.textContaining('费用：10 电池'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(transport.postCount, 0);
    await tester.pumpWidget(const SizedBox());
    gifts.dispose();
  });
}
