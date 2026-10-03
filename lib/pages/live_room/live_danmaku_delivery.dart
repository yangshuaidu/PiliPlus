import 'dart:async';

enum LiveDeliveryState {
  sending,
  waiting,
  echoed,
  unobserved,
  rejected,
  unknown,
}

class LiveDanmakuDelivery {
  LiveDanmakuDelivery({
    required this.uid,
    required this.text,
    required this.startedAt,
    required this.connectionReady,
  });
  final int uid;
  final String text;
  final DateTime startedAt;
  final bool connectionReady;
  LiveDeliveryState state = LiveDeliveryState.sending;
  String? responseId;
  bool interrupted = false;
  String? reason;
  Timer? timer;

  String get label => switch (state) {
    LiveDeliveryState.sending => '正在发送',
    LiveDeliveryState.waiting => '接口已接受，等待弹幕回显',
    LiveDeliveryState.echoed => '已检测到自己的弹幕回显',
    LiveDeliveryState.rejected => '接口拒绝：${reason ?? '未提供原因'}',
    LiveDeliveryState.unknown => '发送结果未知，请勿重复发送',
    LiveDeliveryState.unobserved =>
      !connectionReady || interrupted
          ? '检测期间连接中断，无法判断是否被屏蔽'
          : '暂未检测到回显，可能被过滤或延迟，无法确认屏蔽',
  };
}

/// Observes only genuine live-stream events, never optimistic local messages.
/// Receiving a self echo does not prove that every other viewer can see it.
class LiveDanmakuDeliveryTracker {
  LiveDanmakuDeliveryTracker({
    required this.onChanged,
    this.timeout = const Duration(seconds: 15),
    this.clock = DateTime.now,
  });
  final void Function() onChanged;
  final Duration timeout;
  final DateTime Function() clock;
  final List<LiveDanmakuDelivery> entries = [];
  final _observedIds = <String>{};
  bool _disposed = false;

  LiveDanmakuDelivery begin(int uid, String text, {required bool connected}) {
    final entry = LiveDanmakuDelivery(
      uid: uid,
      text: text,
      startedAt: clock(),
      connectionReady: connected,
    );
    entries.insert(0, entry);
    if (entries.length > 20) entries.removeLast().timer?.cancel();
    onChanged();
    return entry;
  }

  void accepted(LiveDanmakuDelivery entry, {String? id}) {
    if (_disposed || !entries.contains(entry)) return;
    entry.responseId = id?.isNotEmpty == true ? id : null;
    if (entry.state == LiveDeliveryState.echoed) return;
    entry.state = LiveDeliveryState.waiting;
    entry.timer = Timer(timeout, () {
      if (_disposed) return;
      entry.state = LiveDeliveryState.unobserved;
      onChanged();
    });
    onChanged();
  }

  void failed(
    LiveDanmakuDelivery entry, {
    String? reason,
    bool unknown = false,
  }) {
    if (_disposed ||
        !entries.contains(entry) ||
        entry.state == LiveDeliveryState.echoed) {
      return;
    }
    entry.timer?.cancel();
    entry.reason = reason;
    entry.state = unknown
        ? LiveDeliveryState.unknown
        : LiveDeliveryState.rejected;
    onChanged();
  }

  void observe({
    required int uid,
    required String text,
    String? id,
    int? timestamp,
  }) {
    if (_disposed) return;
    if (id != null && id.isNotEmpty) {
      if (!_observedIds.add('$uid:$id')) return;
      if (_observedIds.length > 500) _observedIds.remove(_observedIds.first);
    }
    // A repeated identical send consumes a separate echo, in send order.
    for (final entry in entries.reversed) {
      if (entry.uid != uid ||
          entry.state == LiveDeliveryState.echoed ||
          entry.state == LiveDeliveryState.rejected ||
          clock().difference(entry.startedAt) > const Duration(minutes: 2)) {
        continue;
      }
      final expected = entry.responseId;
      if (expected != null && id != null && id.isNotEmpty) {
        if (expected != id) continue;
      } else if (entry.text != text) {
        continue;
      }
      if (timestamp != null &&
          timestamp > 0 &&
          timestamp < entry.startedAt.millisecondsSinceEpoch ~/ 1000 - 1) {
        continue;
      }
      entry.timer?.cancel();
      entry.state = LiveDeliveryState.echoed;
      onChanged();
      return;
    }
  }

  void connectionInterrupted() {
    for (final entry in entries) {
      if (entry.state == LiveDeliveryState.sending ||
          entry.state == LiveDeliveryState.waiting) {
        entry.interrupted = true;
      }
    }
  }

  void dispose() {
    _disposed = true;
    clear();
  }

  void clear() {
    for (final entry in entries) {
      entry.timer?.cancel();
    }
    entries.clear();
    _observedIds.clear();
  }
}
