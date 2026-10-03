import 'dart:async';
import 'dart:io';

import 'package:PiliPlus/models_new/live/live_danmaku/danmaku_msg.dart';
import 'package:PiliPlus/models_new/live/live_danmaku/live_emote.dart';
import 'package:PiliPlus/models_new/live/live_danmaku/live_message_parser.dart';
import 'package:PiliPlus/models_new/live/live_danmaku/live_room_notice.dart';
import 'package:PiliPlus/pages/danmaku/danmaku_model.dart';
import 'package:PiliPlus/pages/live_room/live_room_settings.dart';
import 'package:PiliPlus/pages/live_room/widgets/live_settings_panel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart';

class SettingsStore {
  final values = <String, Object>{};
  LiveRoomSettings open() => LiveRoomSettings(
    read: (key) => values[key],
    write: (key, value) async => values[key] = value,
  )..load();
}

const gift = LiveGiftMessage(
  uid: 1,
  name: '观众',
  giftName: '礼物',
  giftId: 10,
  quantity: 1,
  action: '赠送',
);

DanmakuMsg danmaku({bool lottery = false, bool emote = false}) => DanmakuMsg(
  name: '观众',
  text: '内容',
  lottery: lottery,
  uemote: emote
      ? BaseEmote.fromJson({
          'url': 'https://example.invalid/emote.gif',
          'emoticon_unique': 'official_test',
          'width': 32,
        })
      : null,
  extra: const LiveDanmaku(id: '1', mid: 1, dmType: 0, ts: 0, ct: 0),
);

Widget app(
  LiveRoomSettings settings, {
  LiveSettingsSection section = LiveSettingsSection.danmaku,
  TargetPlatform platform = TargetPlatform.android,
  double textScale = 1,
  VoidCallback? display,
}) => MaterialApp(
  theme: ThemeData(platform: platform),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => LiveSettingsPanel(
            settings: settings,
            initialSection: section,
            onDisplaySettings: display ?? () {},
            onBlockRules: () {},
          ),
        ),
        child: const Text('打开'),
      ),
    ),
  ),
);

void main() {
  test('preferences survive closing and reopening the actual Hive settings file', () async {
    final directory = await Directory.systemTemp.createTemp('piliplus-live-settings-');
    var box = await Hive.openBox<dynamic>('live-settings', path: directory.path);
    addTearDown(() async {
      if (box.isOpen) await box.close();
      await directory.delete(recursive: true);
    });
    await box.put('liveMessageFiltersV1', ['gifts']);
    final settings = LiveRoomSettings(
      read: (key) => box.get(key),
      write: (key, value) => box.put(key, value),
    )..load();
    await settings.set(LiveRoomOption.badges, false);
    await settings.set(LiveRoomOption.entryNotices, false);
    await settings.set(LiveRoomOption.giftEffects, true);
    await box.close();
    box = await Hive.openBox<dynamic>('live-settings', path: directory.path);
    final restarted = LiveRoomSettings(read: (key) => box.get(key))..load();
    expect(restarted.enabled(LiveRoomOption.badges), isFalse);
    expect(restarted.enabled(LiveRoomOption.entryNotices), isFalse);
    expect(restarted.enabled(LiveRoomOption.giftMessages), isFalse);
    expect(restarted.enabled(LiveRoomOption.giftBroadcasts), isFalse);
    expect(restarted.enabled(LiveRoomOption.giftEffects), isTrue);
  });
  test(
    'legacy blocks migrate once without restoring previously hidden gifts',
    () async {
      final store = SettingsStore();
      store.values['liveMessageFiltersV1'] = [
        'gifts',
        'lottery',
        'emotes',
        'entry',
        'superChat',
      ];
      final settings = store.open();
      for (final option in [
        LiveRoomOption.giftMessages,
        LiveRoomOption.giftEffects,
        LiveRoomOption.giftBroadcasts,
        LiveRoomOption.lotteryDanmaku,
        LiveRoomOption.lotteryNotices,
        LiveRoomOption.emotes,
        LiveRoomOption.cornerEmotes,
        LiveRoomOption.entryNotices,
        LiveRoomOption.superChats,
      ]) {
        expect(settings.enabled(option), isFalse, reason: option.name);
      }
      expect(settings.enabled(LiveRoomOption.roomNotices), isTrue);
      await settings.set(LiveRoomOption.giftEffects, true);
      final restarted = store.open();
      expect(restarted.enabled(LiveRoomOption.giftEffects), isTrue);
      expect(restarted.enabled(LiveRoomOption.giftMessages), isFalse);
      expect(restarted.enabled(LiveRoomOption.giftBroadcasts), isFalse);
    },
  );

  test(
    'unknown or malformed saved fields never disable unrelated categories',
    () {
      final store = SettingsStore();
      store.values[LiveRoomSettings.storageKey] = {
        'badges': false,
        'roomNotices': 'false',
        'futureOption': false,
      };
      final settings = store.open();
      expect(settings.enabled(LiveRoomOption.badges), isFalse);
      expect(settings.enabled(LiveRoomOption.roomNotices), isTrue);
      expect(settings.enabled(LiveRoomOption.giftEffects), isTrue);
    },
  );

  test(
    'system switch no longer suppresses entry follow share or activity notices',
    () async {
      final settings = SettingsStore().open();
      await settings.set(LiveRoomOption.roomNotices, false);
      expect(settings.allows(const LiveRoomNotice(text: '下播')), isFalse);
      for (final type in [1, 2, 3, 4, 5]) {
        final notice = LiveRoomNotice.parse({
          'cmd': 'INTERACT_WORD',
          'data': {
            'roomid': 10,
            'msg_type': type,
            'uid': 20,
            'uname': '用户',
          },
        }, 10)!;
        expect(settings.allows(notice), isTrue);
        expect(notice.entry, type == 1);
        expect(notice.follow, [2, 4, 5].contains(type));
        expect(notice.share, type == 3);
      }
      await settings.set(LiveRoomOption.followNotices, false);
      expect(
        settings.allows(const LiveRoomNotice(text: '关注', follow: true)),
        isFalse,
      );
      expect(
        settings.allows(const LiveRoomNotice(text: '进入', entry: true)),
        isTrue,
      );
      expect(
        settings.allows(const LiveRoomNotice(text: '分享', share: true)),
        isTrue,
      );
      expect(
        settings.allows(const LiveRoomNotice(text: '开奖', lottery: true)),
        isTrue,
      );
    },
  );

  test(
    'gift receipts broadcasts and effects are independent of each other',
    () async {
      final settings = SettingsStore().open();
      await settings.set(LiveRoomOption.giftMessages, false);
      expect(settings.allows(gift), isFalse);
      expect(settings.enabled(LiveRoomOption.giftEffects), isTrue);
      expect(
        settings.allows(const LiveRoomNotice(text: '广播', broadcast: true)),
        isTrue,
      );
      await settings.set(LiveRoomOption.giftBroadcasts, false);
      expect(
        settings.allows(const LiveRoomNotice(text: '广播', broadcast: true)),
        isFalse,
      );
      expect(
        settings.allows(const LiveRoomNotice(text: '进入', entry: true)),
        isTrue,
      );
      await settings.set(LiveRoomOption.giftMessages, true);
      await settings.set(LiveRoomOption.giftEffects, false);
      expect(settings.allows(gift), isTrue);
    },
  );

  test(
    'lottery danmaku filters do not hide result notices or ordinary messages',
    () async {
      final settings = SettingsStore().open();
      await settings.set(LiveRoomOption.lotteryDanmaku, false);
      expect(settings.allows(danmaku(lottery: true)), isFalse);
      expect(settings.allows(danmaku(), activityDanmaku: true), isFalse);
      expect(settings.allows(danmaku()), isTrue);
      expect(
        settings.allows(const LiveRoomNotice(text: '开奖结果', lottery: true)),
        isTrue,
      );
      await settings.set(LiveRoomOption.emotes, false);
      expect(settings.allows(danmaku(emote: true)), isFalse);
      expect(settings.allows(danmaku()), isTrue);
    },
  );

  test(
    'rapid changes are saved in order and reopen with the final value',
    () async {
      final firstSave = Completer<void>();
      final writes = <Map<String, bool>>[];
      final values = <String, Object>{};
      final settings = LiveRoomSettings(
        read: (key) => values[key],
        write: (key, value) async {
          writes.add(Map<String, bool>.from(value as Map));
          if (writes.length == 1) await firstSave.future;
          values[key] = value;
        },
      )..load();
      final first = settings.set(LiveRoomOption.entryNotices, false);
      final second = settings.set(LiveRoomOption.entryNotices, true);
      final third = settings.set(LiveRoomOption.badges, false);
      await Future<void>.delayed(Duration.zero);
      expect(writes, hasLength(1));
      firstSave.complete();
      expect(await Future.wait([first, second, third]), [true, true, true]);
      final restored = LiveRoomSettings(read: (key) => values[key])..load();
      expect(restored.enabled(LiveRoomOption.entryNotices), isTrue);
      expect(restored.enabled(LiveRoomOption.badges), isFalse);
    },
  );

  test(
    'failed save restores persisted choices and later changes still work',
    () async {
      bool fail = false;
      final values = <String, Object>{};
      final settings = LiveRoomSettings(
        read: (key) => values[key],
        write: (key, value) async {
          if (fail) throw StateError('disk unavailable');
          values[key] = value;
        },
      )..load();
      await settings.set(LiveRoomOption.roomNotices, false);
      fail = true;
      expect(await settings.set(LiveRoomOption.badges, false), isFalse);
      expect(settings.enabled(LiveRoomOption.badges), isTrue);
      expect(settings.enabled(LiveRoomOption.roomNotices), isFalse);
      expect(settings.saveError.value, isNotNull);
      fail = false;
      expect(await settings.set(LiveRoomOption.badges, false), isTrue);
      expect(settings.saveError.value, isNull);
    },
  );

  test('reset only changes the selected settings section', () async {
    final settings = SettingsStore().open();
    await settings.set(LiveRoomOption.giftMessages, false);
    await settings.set(LiveRoomOption.entryNotices, false);
    await settings.set(LiveRoomOption.emotes, false);
    await settings.reset(LiveSettingsSection.gifts);
    expect(settings.enabled(LiveRoomOption.giftMessages), isTrue);
    expect(settings.enabled(LiveRoomOption.entryNotices), isFalse);
    expect(settings.enabled(LiveRoomOption.emotes), isFalse);
  });

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.windows,
  ]) {
    testWidgets(
      'notification change persists across closing and reopening on $platform',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final store = SettingsStore();
        await tester.pumpWidget(
          app(
            store.open(),
            section: LiveSettingsSection.notifications,
            platform: platform,
          ),
        );
        await tester.tap(find.text('打开'));
        await tester.pumpAndSettle();
        final entry = find.byKey(const ValueKey('entryNotices'));
        await tester.ensureVisible(entry);
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(entry).value, isFalse);
        await tester.ensureVisible(find.byTooltip('关闭设置'));
        await tester.tap(find.byTooltip('关闭设置'));
        await tester.pumpAndSettle();
        expect(find.byType(LiveSettingsPanel), findsNothing);
        await tester.pumpWidget(
          app(
            store.open(),
            section: LiveSettingsSection.notifications,
            platform: platform,
          ),
        );
        await tester.tap(find.text('打开'));
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(entry).value, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final section in LiveSettingsSection.values) {
    testWidgets(
      '${section.title} remains scrollable on a short screen with double text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 240);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(SettingsStore().open(), section: section, textScale: 2),
        );
        await tester.tap(find.text('打开'));
        await tester.pumpAndSettle();
        final last = LiveRoomOption.values.lastWhere(
          (option) => option.section == section,
        );
        final target = find.byKey(ValueKey(last.name));
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        final toggle = find.descendant(
          of: target,
          matching: find.byType(Switch),
        );
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(target).value, isFalse);
        await tester.ensureVisible(find.text('恢复本页分类默认值'));
        await tester.tap(find.text('恢复本页分类默认值'));
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(target).value, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'the three sections and display settings have reachable independent entries',
    (tester) async {
      int display = 0;
      await tester.pumpWidget(
        app(SettingsStore().open(), display: () => display++),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('字体、透明度与显示区域'));
      expect(display, 1);
      await tester.tap(find.widgetWithText(ChoiceChip, '礼物'));
      await tester.pumpAndSettle();
      expect(find.text('礼物设置'), findsOneWidget);
      expect(find.byKey(const ValueKey('giftEffects')), findsOneWidget);
      expect(find.byKey(const ValueKey('entryNotices')), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, '通知'));
      await tester.pumpAndSettle();
      expect(find.text('通知设置'), findsOneWidget);
      expect(find.byKey(const ValueKey('entryNotices')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
