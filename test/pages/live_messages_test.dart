import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:PiliPlus/models_new/live/live_danmaku/live_message_parser.dart';
import 'package:PiliPlus/pages/live_room/live_danmaku_delivery.dart';
import 'package:PiliPlus/pages/live_room/live_message_session.dart';
import 'package:PiliPlus/tcp/live.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Uint8List packet(int op, List<int> body, {int version = 1}) =>
    Uint8List.fromList([
      ...PackageHeader(
        protocolVer: version,
        operationCode: op,
        seq: 1,
      ).toBytes(body.length),
      ...body,
    ]);
Uint8List event(String cmd) => packet(5, utf8.encode(jsonEncode({'cmd': cmd})));

class TestSink implements WebSocketSink {
  final sent = <dynamic>[];
  @override
  void add(dynamic data) => sent.add(data);
  @override
  Future<void> close([int? closeCode, String? closeReason]) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestSocket implements WebSocketChannel {
  final input = StreamController<dynamic>();
  @override
  final sink = TestSink();
  @override
  Future<void> get ready => Future.value();
  @override
  Stream<dynamic> get stream => input.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('combined heartbeat, compressed packets and plain packets retain every event', () async {
    final socket = TestSocket();
    final messages = [];
    final stream = LiveMessageStream(
      streamToken: 'test',
      roomId: 1,
      uid: 2,
      servers: ['wss://example.invalid'],
      socketFactory: (_) => socket,
    );
    stream.addEventListener((_) => throw StateError('bad consumer'));
    stream.addEventListener(messages.add);
    final initialized = stream.init();
    await Future<void>.delayed(Duration.zero);
    stream.onData(packet(8, utf8.encode('{"code":0}')));
    expect(await initialized, isTrue);
    stream.onData(
      Uint8List.fromList([
        ...packet(3, [0, 0, 0, 1]),
        ...packet(
          5,
          ZLibEncoder().convert([...event('A'), ...event('B')]),
          version: 2,
        ),
        ...packet(5, utf8.encode('invalid json')),
        ...event('C'),
      ]),
    );
    expect(messages.map((e) => e['cmd']), ['A', 'B', 'C']);
    stream.close();
    await socket.input.close();
  });

  test('short and invalid headers never throw or emit', () {
    for (var length = 0; length < 16; length++) {
      expect(PackageHeaderRes.fromBytesData(Uint8List(length)), isNull);
    }
    final bad = event('A');
    ByteData.sublistView(bad).setUint32(0, 100000);
    expect(PackageHeaderRes.fromBytesData(bad), isNull);
  });

  test(
    'authentication rejection and intentional closure are terminal',
    () async {
      final socket = TestSocket();
      var disconnected = 0;
      final stream = LiveMessageStream(
        streamToken: 'test',
        roomId: 1,
        uid: 2,
        servers: ['wss://example.invalid'],
        socketFactory: (_) => socket,
        onDisconnected: () => disconnected++,
      );
      final initialized = stream.init();
      await Future<void>.delayed(Duration.zero);
      stream.onData(packet(8, utf8.encode('{"code":-101}')));
      expect(await initialized, isFalse);
      expect(disconnected, 1);
      stream.close();
      expect(disconnected, 1);
      await socket.input.close();
    },
  );

  testWidgets('session retries with a fresh generation and cancels on exit', (
    tester,
  ) async {
    final generations = <int>[];
    final states = <LiveMessageConnectionState>[];
    final session = LiveMessageSession(
      connect: (generation) async {
        generations.add(generation);
        return false;
      },
      disconnect: () {},
      onState: states.add,
      retryDelays: [const Duration(seconds: 1)],
    );
    session.start();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(generations.length, 2);
    expect(generations[0], isNot(generations[1]));
    expect(states.last, LiveMessageConnectionState.stopped);
    session.dispose();
    await tester.pump(const Duration(seconds: 30));
    expect(generations.length, 2);
  });

  test('old fields and malformed optional metadata preserve text', () {
    final first = List<dynamic>.filled(16, null);
    first[1] = 1;
    first[3] = 0xff0000;
    first[4] = 123;
    first[15] = {'extra': '{bad json'};
    final parsed = LiveMessageParser.danmaku({
      'info': [
        first,
        'hello',
        ['42', 'viewer'],
      ],
    });
    expect(parsed!.message.text, 'hello');
    expect(parsed.message.extra.mid, 42);
    expect(parsed.message.name, 'viewer');
    expect(parsed.color, 0xff0000);
  });

  test('new fields accept numeric strings and missing medal/check info', () {
    final first = List<dynamic>.filled(16, null);
    first[15] = {
      'user': {
        'uid': '42',
        'base': {'name': 'viewer'},
      },
      'extra': {'id_str': 'abc', 'dm_type': 0},
    };
    final parsed = LiveMessageParser.danmaku({
      'info': [first, 'hello'],
    });
    expect(parsed!.message.extra.id, 'abc');
    expect(parsed.message.extra.mid, 42);
  });

  test(
    'gift messages preserve quantity and do not count combo totals twice',
    () {
      final data = {
        'uid': 42,
        'uname': 'viewer',
        'giftName': '花',
        'num': 3,
        'tid': 'gift-1',
      };
      expect(
        LiveGiftMessage.parse({'cmd': 'SEND_GIFT', 'data': data})!.quantity,
        3,
      );
      expect(
        LiveGiftMessage.parse({'cmd': 'COMBO_SEND', 'data': data}),
        isNull,
      );
    },
  );

  testWidgets(
    'missing echo stays uncertain; late echo resolves and duplicates consume one each',
    (tester) async {
      final tracker = LiveDanmakuDeliveryTracker(onChanged: () {});
      final first = tracker.begin(42, 'hello', connected: true);
      tracker.accepted(first);
      await tester.pump(const Duration(seconds: 16));
      expect(first.state, LiveDeliveryState.unobserved);
      expect(first.label, contains('无法确认'));
      tracker.observe(uid: 99, text: 'hello');
      expect(first.state, LiveDeliveryState.unobserved);
      final second = tracker.begin(42, 'hello', connected: true);
      tracker.accepted(second);
      tracker.observe(uid: 42, text: 'hello');
      expect(first.state, LiveDeliveryState.echoed);
      expect(second.state, LiveDeliveryState.waiting);
      tracker.connectionInterrupted();
      await tester.pump(const Duration(seconds: 16));
      expect(second.label, contains('连接中断'));
      tracker.dispose();
    },
  );

  test('echo before HTTP response and exact response ID matching', () {
    final tracker = LiveDanmakuDeliveryTracker(onChanged: () {});
    final first = tracker.begin(42, 'hello', connected: true);
    tracker.observe(uid: 42, text: 'hello');
    tracker.accepted(first, id: '1');
    expect(first.state, LiveDeliveryState.echoed);
    final second = tracker.begin(42, 'hello', connected: true);
    tracker.accepted(second, id: '2');
    tracker.observe(uid: 42, text: 'hello', id: '1');
    expect(second.state, LiveDeliveryState.waiting);
    tracker.observe(uid: 42, text: 'hello', id: '2');
    expect(second.state, LiveDeliveryState.echoed);
    tracker.dispose();
  });
}
