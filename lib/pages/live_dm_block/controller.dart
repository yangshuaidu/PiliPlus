import 'package:PiliPlus/utils/accounts.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:PiliPlus/http/live.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/live/live_dm_block/shield_user_list.dart';
import 'package:PiliPlus/pages/live_room/controller.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class LiveDmBlockController extends GetxController
    with GetSingleTickerProviderStateMixin {
  final roomId = Get.parameters['roomId']!;
  LiveRoomController? _controller;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is LiveRoomController) {
      _controller = args;
    }
    tabController = TabController(length: 2, vsync: this);
    queryData();
  }

  late final TabController tabController;

  bool _isLoaded = false;
  final busy = false.obs;
  late final _account = Accounts.main;
  bool get _valid => identical(_account, Accounts.main) && _account.isLogin;
  Future<void> clearCurrent() async {
    if (busy.value || !_valid || !_isLoaded) return;
    busy.value = true;
    final words = tabController.index == 0;
    final items = words
        ? List<Object>.from(keywordList)
        : List<Object>.from(shieldUserList);
    var removed = 0;
    try {
      for (final item in items) {
        if (!_valid) break;
        final result = item is ShieldUserList
            ? await LiveHttp.liveShieldUser(
                uid: item.uid,
                roomid: roomId,
                type: 0,
              )
            : await LiveHttp.delShieldKeyword(keyword: item as String);
        if (!_valid || !result.isSuccess) {
          if (!result.isSuccess) result.toast();
          break;
        }
        item is ShieldUserList
            ? shieldUserList.remove(item)
            : keywordList.remove(item);
        removed++;
      }
      _updateLiveRoomRules();
      SmartDialog.showToast('已删除 $removed / ${items.length} 条规则');
    } finally {
      busy.value = false;
    }
  }

  final RxList<String> keywordList = <String>[].obs;
  final RxList<ShieldUserList> shieldUserList = <ShieldUserList>[].obs;

  Future<void> queryData() async {
    final res = await LiveHttp.getLiveInfoByUser(roomId);
    if (!_valid) return;
    if (res case Success(:final response)) {
      keywordList.clear();
      shieldUserList.clear();
      _isLoaded = true;
      if (response == null) return;
      if (response.keywordList case final list? when list.isNotEmpty) {
        keywordList.addAll(list);
      }
      if (response.shieldUserList case final list? when list.isNotEmpty) {
        shieldUserList.addAll(list);
      }
    } else {
      res.toast();
    }
  }

  void _updateLiveRoomRules() {
    if (_valid && _isLoaded && _controller != null) {
      _controller!.updateBlockRules(
        List<String>.from(keywordList),
        shieldUserList.map((e) => e.uid).toSet(),
      );
    }
  }

  Future<void> addShieldKeyword(bool isKeyword, String value) async {
    if (busy.value || !_valid || !_isLoaded) return;
    value = value.trim();
    if (value.isEmpty || (isKeyword && keywordList.contains(value))) return;
    if (isKeyword) {
      final res = await LiveHttp.addShieldKeyword(keyword: value);
      if (res.isSuccess) {
        if (!_valid) return;
        keywordList.insert(0, value);
        _updateLiveRoomRules();
      } else {
        res.toast();
      }
    } else {
      final res = await LiveHttp.liveShieldUser(
        uid: value,
        roomid: roomId,
        type: 1,
      );
      if (res case Success(:final response)) {
        if (!_valid) return;
        shieldUserList.insert(0, response);
        _updateLiveRoomRules();
      } else {
        res.toast();
      }
    }
  }

  Future<void> onRemove(int index, Object item) async {
    if (busy.value || !_valid) return;
    assert(item is ShieldUserList || item is String);
    if (item is ShieldUserList) {
      final res = await LiveHttp.liveShieldUser(
        uid: item.uid,
        roomid: roomId,
        type: 0,
      );
      if (res.isSuccess) {
        if (!_valid) return;
        shieldUserList.remove(item);
        _updateLiveRoomRules();
      } else {
        res.toast();
      }
    } else {
      final res = await LiveHttp.delShieldKeyword(keyword: item as String);
      if (res.isSuccess) {
        if (!_valid) return;
        keywordList.remove(item);
        _updateLiveRoomRules();
      } else {
        res.toast();
      }
    }
  }

  @override
  void onClose() {
    _updateLiveRoomRules();
    tabController.dispose();
    super.onClose();
  }
}
