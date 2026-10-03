import 'package:PiliPlus/pages/live_room/widgets/red_packet_panel.dart';
import 'package:PiliPlus/services/live_gift_service.dart';
import 'package:PiliPlus/services/live_red_packet_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/live_gift_fakes.dart';
import '../support/live_room_actions_fakes.dart';

void main() {
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
    await tester.ensureVisible(find.text('发红包 · 10 电池'));
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
