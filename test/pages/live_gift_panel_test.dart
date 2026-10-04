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

Map<String, dynamic> groupedCatalogue() => {
  'gift_config': {
    'base_config': {
      'list': [
        {...giftConfig(price: 100), 'id': 10, 'name': '低价A'},
        {...giftConfig(price: 29900), 'id': 11, 'name': '高价'},
        {...giftConfig(price: 100), 'id': 12, 'name': '同价B'},
        {...giftConfig(), 'id': 13, 'name': '未知价', 'price': null},
        {...giftConfig(price: 50000), 'id': 14, 'name': '航海礼物'},
      ],
    },
  },
  'gift_data': {
    'max_send_gift': 99,
    'room_gift_list': {
      'gold_list': [
        {'gift_id': 11},
        {'gift_id': 10},
        {'gift_id': 12},
        {'gift_id': 13},
      ],
    },
    'tab_list': [
      {
        'tab_id': 11,
        'tab_name': '互动',
        'position': 2,
        'list': [
          {'gift_id': 11},
        ],
      },
      {
        'tab_id': 9,
        'tab_name': '粉丝团',
        'position': 4,
        'list': [
          {'gift_id': 12},
        ],
      },
      {
        'tab_id': 2,
        'tab_name': '航海',
        'position': 5,
        'list': [
          {
            'gift_id': 14,
            'special': {'is_use': 0, 'tips': '需要大航海权限'},
          },
        ],
      },
    ],
  },
};

List<String> visibleGiftNames(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(of: find.byType(SliverGrid), matching: find.byType(Text)),
    )
    .map((text) => text.data)
    .whereType<String>()
    .where(
      (name) => {'低价A', '高价', '同价B', '未知价', '航海礼物'}.contains(name),
    )
    .toList();

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
    'battery prices sort numerically, stably, with unknown prices last',
    (tester) async {
      transport.catalogData = groupedCatalogue();
      await openGiftPanel(tester, service);
      expect(visibleGiftNames(tester), ['低价A', '同价B', '高价', '未知价']);
      await tester.tap(find.byTooltip('按电池价格排序'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('价格从高到低').last);
      await tester.pumpAndSettle();
      expect(visibleGiftNames(tester), ['高价', '低价A', '同价B', '未知价']);
      expect(transport.postCount, 0);
      expect(find.text('价格未知'), findsOneWidget);
    },
  );

  testWidgets(
    'official group filters clear a hidden selection and retain restrictions',
    (tester) async {
      transport.catalogData = groupedCatalogue();
      await openGiftPanel(tester, service);
      await tester.tap(find.text('低价A'));
      await tester.pump();
      await tester.tap(find.text('粉丝团'));
      await tester.pumpAndSettle();
      expect(visibleGiftNames(tester), ['同价B']);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '赠送'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('航海'));
      await tester.pumpAndSettle();
      expect(visibleGiftNames(tester), ['航海礼物']);
      expect(find.byTooltip('暂不可送'), findsOneWidget);
      await tester.tap(find.text('航海礼物'));
      await tester.pumpAndSettle();
      expect(find.text('需要大航海权限'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '赠送'))
            .onPressed,
        isNull,
      );
      expect(transport.postCount, 0);
    },
  );

  testWidgets(
    'refresh removes a stale group and returns to the room catalogue',
    (
      tester,
    ) async {
      transport.catalogData = groupedCatalogue();
      await openGiftPanel(tester, service);
      await tester.tap(find.text('互动'));
      await tester.pumpAndSettle();
      expect(visibleGiftNames(tester), ['高价']);
      transport.catalogData = null;
      await tester.tap(find.byTooltip('刷新礼物'));
      await tester.pumpAndSettle();
      expect(find.text('测试礼物'), findsOneWidget);
      expect(find.text('互动'), findsNothing);
      expect(
        tester
            .widget<Semantics>(find.byKey(const ValueKey('gift-tab-礼物')))
            .properties
            .selected,
        isTrue,
      );
    },
  );

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
    await tester.tap(find.text('包裹'));
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
    await tester.ensureVisible(find.text('测试礼物'));
    await tester.pumpAndSettle();
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
    await tester.ensureVisible(find.text('测试礼物'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('测试礼物'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '赠送'))
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'official groups remain usable in a small viewport with keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.reset);
      transport.catalogData = groupedCatalogue();
      await openGiftPanel(tester, service);
      await tester.ensureVisible(find.text('粉丝团'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('粉丝团'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('同价B'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('同价B'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '赠送'))
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
      expect(transport.postCount, 0);
    },
  );
}
