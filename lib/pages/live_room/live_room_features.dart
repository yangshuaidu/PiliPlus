import 'dart:async';

import 'package:PiliPlus/http/live.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/live/gift/live_gift.dart';
import 'package:PiliPlus/models_new/live/live_pk.dart';
import 'package:PiliPlus/models_new/live/live_activity.dart';
import 'package:get/get.dart';

/// Read-side room features share one lifecycle with the authenticated message
/// session. Writes stay in explicit user-action services and panels.
class LiveRoomFeatures {
  LiveRoomFeatures(this.roomId);
  final int roomId;
  final pk = Rxn<LivePkState>();
  final webInfo = <String, dynamic>{}.obs;
  final error = RxnString();
  final activities = <LiveActivity>[].obs;
  final activityError = RxnString();
  bool _readingActivities = false;
  int _pkTimestamp = 0;
  final _endedPkIds = <int>{};
  Timer? _timer;
  int _generation = 0;
  bool _disposed = false, _reading = false, _readingPk = false;
  DateTime? _lastPkRead;

  void start() {
    if (_disposed || _timer != null) return;
    refresh();
    refreshActivities();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      refresh();
      refreshActivities();
    });
  }

  void stop() {
    ++_generation;
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    _disposed = true;
    stop();
  }

  Future<void> refresh() async {
    if (_disposed || _reading) return;
    _reading = true;
    final generation = _generation;
    try {
      final result = await LiveHttp.liveRoomWebInfo(roomId);
      if (_disposed || generation != _generation) return;
      if (result case Success(:final response)) {
        error.value = null;
        webInfo.assignAll(response);
        final modern = liveMap(response['pk_info_v2']);
        final legacy = liveMap(response['battle_info']);
        final data = modern.isNotEmpty ? modern : legacy;
        final state = LivePkState.parse(data, roomId, DateTime.now());
        if (state != null) {
          _mergePk(state);
        } else {
          final id = liveInt(
            liveMap(modern['pk_basic'])['pk_id'] ?? legacy['pk_id'],
          );
          if (id != null && id > 0) {
            refreshPk(id, legacy: modern.isEmpty);
          } else if (pk.value != null &&
              DateTime.now().difference(pk.value!.receivedAt) >
                  const Duration(seconds: 30))
            pk.value = null;
        }
      } else {
        error.value = result.toString();
      }
    } catch (_) {
      if (!_disposed && generation == _generation) error.value = '扩展信息暂不可用';
    } finally {
      _reading = false;
    }
  }

  void _mergePk(LivePkState state) {
    if (_endedPkIds.contains(state.id) ||
        state.serverTimestamp < _pkTimestamp) {
      return;
    }
    _pkTimestamp = state.serverTimestamp;
    if (state.status >= 1000) _endPk(state.id);
    pk.value = state.status >= 1000 ? null : state;
  }

  void _endPk(int id) {
    _endedPkIds.add(id);
    if (_endedPkIds.length > 100) _endedPkIds.remove(_endedPkIds.first);
    if (pk.value?.id == id) pk.value = null;
  }

  Future<void> refreshActivities() async {
    if (_disposed || _readingActivities) return;
    _readingActivities = true;
    final generation = _generation;
    try {
      final results = await Future.wait([
        LiveHttp.liveActivityInfo(roomId),
        LiveHttp.liveActivityInfo(roomId, anchor: true),
      ]);
      if (_disposed || generation != _generation) return;
      activityError.value = null;
      final now = DateTime.now();
      if (results[0] case Success(:final response)) {
        final red = LiveActivity.redPackets(
          response['popularity_red_pocket'],
          now,
        );
        for (final activity in red) {
          _upsertActivity(activity);
        }
      } else {
        activityError.value = '红包信息暂不可用，可手动刷新';
      }
      if (results[1] case Success(:final response)) {
        final anchor = LiveActivity(LiveActivityKind.anchor, response, now);
        if (anchor.id > 0) _upsertActivity(anchor);
      } else {
        activityError.value = '部分活动信息暂不可用，可手动刷新';
      }
      activities.removeWhere(
        (a) =>
            now.difference(a.receivedAt) > const Duration(minutes: 15) &&
            !a.active(now),
      );
    } catch (_) {
      if (!_disposed && generation == _generation)
        activityError.value = '活动信息暂不可用，可手动刷新';
    } finally {
      _readingActivities = false;
    }
  }

  void _upsertActivity(LiveActivity activity) {
    if (activity.id <= 0) return;
    final index = activities.indexWhere((a) => a.key == activity.key);
    if (index < 0) {
      activities.insert(0, activity);
    } else {
      activities[index] = activity;
    }
    if (activities.length > 20) activities.removeLast();
  }

  Future<void> refreshPk(int id, {bool legacy = false}) async {
    if (_disposed ||
        _readingPk ||
        (_lastPkRead != null &&
            DateTime.now().difference(_lastPkRead!) <
                const Duration(seconds: 3))) {
      return;
    }
    _lastPkRead = DateTime.now();
    _readingPk = true;
    final generation = _generation;
    try {
      final result = await LiveHttp.livePkInfo(
        roomId,
        id,
        legacy: legacy,
        pkVersion: liveInt(liveMap(webInfo['room_info'])['pk_status']),
      );
      if (_disposed || generation != _generation) return;
      if (result case Success(:final response)) {
        final state = LivePkState.parse(response, roomId, DateTime.now());
        if (state != null && state.id == id) _mergePk(state);
      }
    } catch (_) {
    } finally {
      _readingPk = false;
    }
  }

  void onEvent(dynamic event) {
    if (_disposed) return;
    final root = liveMap(event);
    final data = liveMap(root['data']);
    final cmd = '${root['cmd']}'.split(':').first;
    if (cmd.startsWith('POPULARITY_RED_POCKET')) {
      if (cmd.endsWith('WINNER_LIST')) {
        final previous = activities
            .where((a) => a.isRed && a.id == liveInt(data['lot_id']))
            .firstOrNull;
        if (previous != null)
          _upsertActivity(
            LiveActivity(previous.kind, {
              ...previous.data,
              ...data,
              'lot_status': 2,
            }, DateTime.now()),
          );
      } else {
        for (final activity in LiveActivity.redPackets(data, DateTime.now())) {
          _upsertActivity(activity);
        }
      }
    } else if (cmd.startsWith('ANCHOR_LOT_')) {
      final previous = activities
          .where((a) => !a.isRed && a.id == liveInt(data['id']))
          .firstOrNull;
      if (previous != null) {
        _upsertActivity(
          LiveActivity(previous.kind, {
            ...previous.data,
            ...data,
            if (cmd == 'ANCHOR_LOT_END') 'lot_status': 1,
            if (cmd == 'ANCHOR_LOT_AWARD') 'lot_status': 2,
          }, DateTime.now()),
        );
      }
      refreshActivities();
    }
    if (cmd == 'PK_INFO') {
      final basic = liveMap(data['pk_basic']);
      final id = liveInt(basic['pk_id']);
      if (id != null && (liveInt(basic['status']) ?? 0) >= 1000) {
        _endPk(id);
        return;
      }
      final state = LivePkState.parse(data, roomId, DateTime.now());
      if (state != null) _mergePk(state);
    } else if (cmd.startsWith('PK_BATTLE_') || cmd.startsWith('PK_')) {
      final id = liveInt(root['pk_id'] ?? data['pk_id']);
      if (id == null || id <= 0) return;
      if (cmd == 'PK_BATTLE_PUNISH_END' || cmd == 'PK_MIC_END') {
        _endPk(id);
      } else {
        refreshPk(id, legacy: true);
      }
    }
  }
}
