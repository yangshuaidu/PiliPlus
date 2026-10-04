import 'package:PiliPlus/pages/live_room/widgets/superchat_purchase_panel.dart';
import 'package:PiliPlus/pages/live_room/live_room_settings.dart';
import 'package:PiliPlus/models_new/live/live_danmaku/live_user_badges.dart';
import 'package:PiliPlus/models_new/live/live_danmaku/live_message_parser.dart';
import 'package:PiliPlus/pages/live_room/live_message_session.dart';
import 'package:PiliPlus/pages/live_room/live_danmaku_delivery.dart';
import 'package:PiliPlus/pages/live_room/live_room_features.dart';
import 'package:PiliPlus/pages/live_room/live_gift_effects.dart';
import 'package:PiliPlus/models_new/live/live_danmaku/live_room_notice.dart';
import 'package:PiliPlus/models_new/live/live_contribution_rank/item.dart';
import 'package:PiliPlus/models/common/live/live_contribution_rank_type.dart';

import 'dart:async' show Timer, StreamSubscription;
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:PiliPlus/common/widgets/dialog/report.dart';
import 'package:PiliPlus/common/widgets/flutter/text_field/controller.dart';
import 'package:PiliPlus/http/live.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/utils/request_utils.dart';
import 'package:PiliPlus/models/common/super_chat_type.dart';
import 'package:PiliPlus/models/common/video/live_quality.dart';
import 'package:PiliPlus/models_new/live/live_danmaku/danmaku_msg.dart';
import 'package:PiliPlus/models_new/live/live_dm_info/data.dart';
import 'package:PiliPlus/models_new/live/live_room_info_h5/data.dart';
import 'package:PiliPlus/models_new/live/live_room_play_info/codec.dart';
import 'package:PiliPlus/models_new/live/live_room_play_info/stream.dart';
import 'package:PiliPlus/models_new/live/live_superchat/item.dart';
import 'package:PiliPlus/pages/common/publish/publish_route.dart';
import 'package:PiliPlus/pages/danmaku/danmaku_model.dart';
import 'package:PiliPlus/pages/live_room/send_danmaku/view.dart';
import 'package:PiliPlus/pages/video/widgets/header_control.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/data_source.dart';
import 'package:PiliPlus/plugin/pl_player/utils/danmaku_options.dart';
import 'package:PiliPlus/services/service_locator.dart';
import 'package:PiliPlus/tcp/live.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/android/bindings.g.dart';
import 'package:PiliPlus/utils/connectivity_utils.dart';
import 'package:PiliPlus/utils/danmaku_utils.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/extension/iterable_ext.dart';
import 'package:PiliPlus/utils/extension/rx_ext.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/num_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/theme_utils.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:PiliPlus/utils/video_utils.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kReleaseMode;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

const int _kMaxChatCount = 500;
const int _kTrimCount = _kMaxChatCount + 50;
const int _kSafeTrimIndex = 200;

class LiveRoomController extends GetxController {
  LiveRoomController(this.heroTag);
  final String heroTag;

  int roomId = Get.arguments;
  int? ruid;
  DanmakuController<DanmakuExtra>? danmakuController;
  final plPlayerController = PlPlayerController.getInstance(
    isLive: true,
  );

  final isLoaded = false.obs;
  final playbackMessage = RxnString();
  bool get usePortraitOverlay => isPortrait.value;
  final sourceAspectRatio = (16 / 9).obs;
  final cleanScreen = false.obs;
  final roomInfoH5 = Rxn<RoomInfoH5Data>();
  final anchorRelation = RxnInt();
  final followingAnchor = false.obs;

  Future<void> followAnchor(BuildContext context) async {
    if (!Accounts.main.isLogin) {
      toastNotLogin();
      return;
    }
    final uid = ruid;
    if (uid == null || followingAnchor.value) return;
    final account = Accounts.main;
    followingAnchor.value = true;
    try {
      final relation = await UserHttp.userRelation(uid);
      if (!context.mounted || !identical(account, Accounts.main)) return;
      if (relation case Success(:final response)) {
        anchorRelation.value = response.attribute;
        await RequestUtils.actionRelationMod(
          context: context,
          mid: uid,
          isFollow: response.attribute == 2 || response.attribute == 6,
          afterMod: (value) {
            if (identical(account, Accounts.main)) anchorRelation.value = value;
          },
        );
      } else {
        relation.toast();
      }
    } finally {
      followingAnchor.value = false;
    }
  }

  final liveTime = Rxn<int>();
  Timer? liveTimeTimer;

  void startLiveTimer() {
    if (liveTime.value != null) {
      liveTimeTimer ??= Timer.periodic(
        const Duration(minutes: 5),
        (_) => liveTime.refresh(),
      );
    }
  }

  void cancelLiveTimer() {
    liveTimeTimer?.cancel();
    liveTimeTimer = null;
  }

  Widget get timeWidget => Obx(() {
    final liveTime = this.liveTime.value;
    String text = '';
    if (liveTime != null) {
      final duration = DurationUtils.formatDurationBetween(
        liveTime * 1000,
        DateTime.now().millisecondsSinceEpoch,
      );
      text += duration.isEmpty ? '刚刚开播' : '开播$duration';
    }
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        color: Colors.white,
      ),
    );
  });

  // dm
  LiveDmInfoData? dmInfo;
  List<RichTextItem>? savedDanmaku;
  int builtLength = 0;
  final messages = <dynamic>[].obs;
  bool get shouldRefresh => builtLength != messages.length;
  late final fsSC = Rxn<SuperChatItem>();
  late final RxList<SuperChatItem> superChatMsg = <SuperChatItem>[].obs;
  final disableAutoScroll = false.obs;
  bool autoScroll = true;
  LiveMessageStream? _msgStream;
  final messageConnectionState = LiveMessageConnectionState.suspended.obs;
  final deliveryRevision = 0.obs;
  late final roomFeatures = LiveRoomFeatures(roomId);
  late final giftEffects = LiveGiftEffects(
    loadCatalog: () => LiveHttp.liveGiftMaterials(roomId, ruid ?? 0),
  );
  final settings = LiveRoomSettings.shared;
  Worker? _settingsWorker;
  bool _showEmotes = true, _showLotteryDanmaku = true, _showSuperChats = true;
  final cornerEmoteUrl = Rxn<String>();
  Timer? _cornerEmoteTimer;
  void _applySettings() {
    if (_closed) return;
    giftEffects.setEnabled(settings.enabled(LiveRoomOption.giftEffects));
    final emotes = settings.enabled(LiveRoomOption.emotes);
    final lottery = settings.enabled(LiveRoomOption.lotteryDanmaku);
    if (!settings.enabled(LiveRoomOption.cornerEmotes) || !emotes) {
      _cornerEmoteTimer?.cancel();
      cornerEmoteUrl.value = null;
    }
    if ((!emotes && _showEmotes) || (!lottery && _showLotteryDanmaku)) {
      danmakuController?.clear();
    }
    _showEmotes = emotes;
    _showLotteryDanmaku = lottery;
    final superChats = settings.enabled(LiveRoomOption.superChats);
    if (!superChats) {
      superChatMsg.clear();
      fsSC.value = null;
    } else if (!_showSuperChats && showSuperChat) {
      getSuperChatMsg();
    }
    _showSuperChats = superChats;
    messages.refresh();
  }

  Future<void> setDanmakuVisible(bool value) async {
    final previous = plPlayerController.enableShowLiveDanmaku.value;
    plPlayerController.enableShowLiveDanmaku.value = value;
    if (plPlayerController.tempPlayerConf) return;
    try {
      await GStorage.setting.put(SettingBoxKey.enableShowLiveDanmaku, value);
    } catch (_) {
      if (plPlayerController.enableShowLiveDanmaku.value == value) {
        plPlayerController.enableShowLiveDanmaku.value = previous;
      }
      SmartDialog.showToast('弹幕开关未保存，请重试');
    }
  }

  bool messageVisible(dynamic message) {
    if (message is DanmakuMsg && isBlocked(message.text, message.extra.mid)) {
      return false;
    }
    if (message is LiveGiftMessage &&
        isBlocked(message.giftName, message.uid)) {
      return false;
    }
    if (message is LiveRoomNotice && isBlocked(message.text, message.uid)) {
      return false;
    }
    if (message is SuperChatItem && isBlocked(message.message, message.uid)) {
      return false;
    }
    return settings.allows(
      message,
      activityDanmaku:
          message is DanmakuMsg &&
          roomFeatures.activities.any(
            (a) => a.danmaku.isNotEmpty && a.danmaku == message.text,
          ),
    );
  }

  final Set<String> _receivedNoticeIds = {};
  late final deliveryTracker = LiveDanmakuDeliveryTracker(
    onChanged: () {
      if (!_closed) deliveryRevision.value++;
    },
  );
  bool _closed = false;
  int? _messageRoom;
  Object? _messageAccount;
  final Set<String> _receivedGiftIds = {};
  late final _messageSession = LiveMessageSession(
    connect: _connectMessages,
    disconnect: _releaseMessageStream,
    onState: (state) {
      if (!_closed) messageConnectionState.value = state;
      if (state != LiveMessageConnectionState.connected) {
        deliveryTracker.connectionInterrupted();
        roomFeatures.stop();
        giftEffects.clear();
      } else {
        roomFeatures.start();
      }
    },
  );

  List<String> _keywordList = const [];
  Set<int> _shieldUids = const {};

  late final ScrollController scrollController;
  late final RxInt pageIndex = 0.obs;
  PageController? pageController;

  int? currentQn = PlatformUtils.isMobile ? null : Pref.liveQuality;
  final currentQnDesc = ''.obs;
  final RxBool isPortrait = false.obs;
  late List<({int code, String desc})> acceptQnList = [];

  late final bool isLogin;
  late final int mid;

  String? videoUrl;
  bool? isPlaying;
  late bool isFullScreen = false;

  final superChatType = Pref.superChatType;
  late final showSuperChat = superChatType != SuperChatType.disable;

  final headerKey = GlobalKey<TimeBatteryMixin>();

  final RxString title = ''.obs;

  final RxnString onlineCount = RxnString();
  final topViewers = <LiveContributionRankItem>[].obs;
  DateTime? _lastViewerRefresh;
  bool _viewersLoading = false;

  Future<void> refreshTopViewers() async {
    final anchor = ruid ?? roomInfoH5.value?.roomInfo?.uid;
    if (_closed ||
        anchor == null ||
        _viewersLoading ||
        (_lastViewerRefresh != null &&
            DateTime.now().difference(_lastViewerRefresh!) <
                const Duration(seconds: 30))) {
      return;
    }
    _viewersLoading = true;
    _lastViewerRefresh = DateTime.now();
    final room = roomId;
    try {
      final result = await LiveHttp.liveContributionRank(
        ruid: anchor,
        roomId: room,
        page: 1,
        type: LiveContributionRankType.online_rank,
      );
      if (_closed || room != roomId) return;
      if (result case Success(:final response)) {
        topViewers.assignAll((response.item ?? []).take(3));
        if (response.countText?.isNotEmpty == true) {
          onlineCount.value = response.countText;
        } else if (response.count != null)
          onlineCount.value = NumUtils.numFormat(response.count);
      }
    } catch (_) {
    } finally {
      _viewersLoading = false;
    }
  }

  final RxnString watchedShow = RxnString();
  Widget get watchedWidget => Obx(() {
    if (watchedShow.value case final watchedShow?) {
      return Text(
        watchedShow,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.white,
        ),
      );
    }
    return const SizedBox.shrink();
  });

  int chatSimpleIndex = 0;
  int _trimDmIndex = 0;
  int get trimDmIndex => _trimDmIndex;
  void _trimDm() {
    final trimCount = messages.length - _trimDmIndex;
    if (trimCount > _kTrimCount) {
      final endIndex = messages.length - _kMaxChatCount;
      final canTrim = (chatSimpleIndex - endIndex) > _kSafeTrimIndex;
      if (canTrim) {
        messages.fillRangeOnly(_trimDmIndex, endIndex);
        _trimDmIndex = endIndex;
      }
    }
  }

  StreamSubscription? _sizeSub;

  void _onSizeChanged((int, int) value) {
    if (value.$1 <= 0 || value.$2 <= 0) return;
    sourceAspectRatio.value = value.$1 / value.$2;
    final isVertical = value.$2 > value.$1;
    isPortrait.value = isVertical;
    plPlayerController.isVertical = isVertical;
  }

  void _startSizeSub() {
    _stopSizeSub();
    _sizeSub = plPlayerController.videoPlayerController?.stream.size.listen(
      _onSizeChanged,
    );
  }

  void _stopSizeSub() {
    _sizeSub?.cancel();
    _sizeSub = null;
  }

  @override
  void onInit() {
    super.onInit();
    settings.load();
    _applySettings();
    _settingsWorker = ever(settings.revision, (_) => _applySettings());
    scrollController = ScrollController()..addListener(listener);
    final account = Accounts.main;
    isLogin = account.isLogin;
    mid = account.mid;
    queryLiveUrl(autoFullScreenFlag: true);
    queryLiveInfoH5();
    if (Accounts.heartbeat.isLogin && !Pref.historyPause) {
      VideoHttp.roomEntryAction(roomId: roomId);
    }
    if (showSuperChat) {
      pageController = PageController();
    }
  }

  Future<void>? playerInit({
    bool autoplay = true,
    bool autoFullScreenFlag = false,
  }) {
    if (videoUrl == null) {
      return null;
    }
    return plPlayerController.setDataSource(
      NetworkSource(videoSource: videoUrl!, audioSource: null),
      isLive: true,
      autoplay: autoplay,
      isVertical: isPortrait.value,
      autoFullScreenFlag: autoFullScreenFlag,
    );
  }

  Future<void> queryLiveUrl({bool autoFullScreenFlag = false}) async {
    playbackMessage.value = null;
    currentQn ??= await ConnectivityUtils.isWiFi
        ? Pref.liveQuality
        : Pref.liveQualityCellular;
    final res = await LiveHttp.liveRoomInfo(
      roomId: roomId,
      qn: currentQn,
      onlyAudio: plPlayerController.onlyPlayAudio.value,
    );
    if (res case Success(:final response)) {
      if (response.liveStatus != 1) {
        playbackMessage.value = '主播尚未开播';
        await plPlayerController.pause();
        return;
      }
      final playurl = response.playurlInfo?.playurl;
      if (playurl == null) {
        playbackMessage.value = '暂时无法获取播放地址';
        return;
      }
      ruid = response.uid;
      if (response.roomId case final roomId?) {
        this.roomId = roomId;
      }
      liveTime.value = response.liveTime;
      startLiveTimer();
      isPortrait.value = response.isPortrait ?? false;
      stream = playurl.stream;
      _initStreamIndex();
      await Future.wait([
        ?initLiveUrl(
          streamIndex: streamIndex,
          formatIndex: formatIndex,
          codecIndex: codecIndex,
          liveUrlIndex: liveUrlIndex,
        ),
        if (!isLoaded.value && Accounts.main.isLogin) _fetchBlockRules(),
      ]);
      isLoaded.value = true;
    } else {
      playbackMessage.value = res.toString();
    }
  }

  late List<Stream> stream;
  int streamIndex = 0;
  int formatIndex = 0;
  int codecIndex = 0;
  int liveUrlIndex = 0;

  void _initStreamIndex() {
    final pref = Pref.liveStream;
    if (pref != null) {
      try {
        final String protocolName = pref[0];
        final String formatName = pref[1];
        final String codecName = pref[2];
        for (var (i, s) in stream.indexed) {
          if (s.protocolName == protocolName) {
            streamIndex = i;
            for (var (j, f) in s.format.indexed) {
              if (f.formatName == formatName) {
                formatIndex = j;
                for (var (k, c) in f.codec.indexed) {
                  if (c.codecName == codecName) {
                    codecIndex = k;
                    return;
                  }
                }
              }
            }
          }
        }
      } catch (_) {}
    }
  }

  Future<void>? initLiveUrl({
    int streamIndex = 0,
    int formatIndex = 0,
    int codecIndex = 0,
    int liveUrlIndex = 0,
  }) {
    this.streamIndex = streamIndex;
    this.formatIndex = formatIndex;
    this.codecIndex = codecIndex;
    this.liveUrlIndex = liveUrlIndex;

    final CodecItem item = stream
        .getOrFirst(streamIndex)
        .format
        .getOrFirst(formatIndex)
        .codec
        .getOrFirst(codecIndex);
    // 以服务端返回的码率为准
    currentQn = item.currentQn;
    acceptQnList = item.acceptQn.map((e) {
      return (
        code: e,
        desc: LiveQuality.fromCode(e)?.desc ?? e.toString(),
      );
    }).toList();
    currentQnDesc.value =
        LiveQuality.fromCode(currentQn)?.desc ?? currentQn.toString();
    videoUrl = VideoUtils.getLiveCdnUrl(item, index: liveUrlIndex);
    return playerInit()?.whenComplete(_startSizeSub);
  }

  Future<void> queryLiveInfoH5() async {
    final res = await LiveHttp.liveRoomInfoH5(roomId: roomId);
    if (res case Success(:final response)) {
      roomInfoH5.value = response;
      final account = Accounts.main;
      final uid = response.roomInfo?.uid;
      anchorRelation.value = null;
      if (account.isLogin && uid != null) {
        UserHttp.userRelation(uid)
            .then((value) {
              if (!_closed &&
                  identical(account, Accounts.main) &&
                  roomInfoH5.value?.roomInfo?.uid == uid) {
                if (value case Success(:final response)) {
                  anchorRelation.value = response.attribute;
                }
              }
            })
            .catchError((Object _) {});
      }
      refreshTopViewers();
      title.value = response.roomInfo?.title ?? '';
      watchedShow.value = response.watchedShow?.textLarge;
      videoPlayerServiceHandler?.onVideoDetailChange(response, roomId, heroTag);
    } else {
      res.toast();
    }
  }

  void scrollToBottom() {
    EasyThrottle.throttle(
      'liveDm',
      const Duration(milliseconds: 500),
      () => WidgetsBinding.instance.addPostFrameCallback(_scrollToBottom),
    );
  }

  void _scrollToBottom([_]) {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.linearToEaseOut,
      );
    }
  }

  void handleJumpToBottom() {
    disableAutoScroll.value = false;
    if (shouldRefresh) {
      messages.refresh();
      WidgetsBinding.instance.addPostFrameCallback(_jumpToBottom);
    } else {
      _jumpToBottom();
    }
  }

  void _jumpToBottom([_]) {
    if (scrollController.hasClients) {
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
    }
  }

  void closeLiveMsg() {
    _messageSession.stop();
    dmInfo = null;
  }

  void _releaseMessageStream() {
    _msgStream?.close();
    _msgStream = null;
  }

  bool _messageMatches(int generation, int room, Object account) =>
      !_closed &&
      _messageSession.isCurrent(generation) &&
      roomId == room &&
      identical(account, Accounts.heartbeat);

  @pragma('vm:notify-debugger-on-exception')
  Future<void> prefetch() async {
    final room = roomId;
    final account = Accounts.heartbeat;
    final generation = _messageSession.generation;
    final res = await LiveHttp.liveRoomDmPrefetch(roomId: room);
    if (!_messageMatches(generation, room, account)) return;
    if (res case Success(:final response)) {
      if (response != null && response.isNotEmpty) {
        messages.addAll(
          response.where(
            (item) =>
                messageVisible(item) && !isBlocked(item.text, item.extra.mid),
          ),
        );
        scrollToBottom();
      }
    } else {
      if (kDebugMode) {
        Utils.reportError(res.toString());
      }
    }
  }

  Future<void> getSuperChatMsg() async {
    final room = roomId;
    final account = Accounts.heartbeat;
    final generation = _messageSession.generation;
    final res = await LiveHttp.superChatMsg(room);
    if (!_messageMatches(generation, room, account)) return;
    if (res.dataOrNull?.list case final list? when list.isNotEmpty) {
      if (settings.enabled(LiveRoomOption.superChats)) {
        superChatMsg.addAll(
          list.where(
            (item) =>
                !superChatMsg.any((old) => old.id == item.id) &&
                messageVisible(item),
          ),
        );
      }
    }
  }

  void clearSC() {
    superChatMsg.removeWhere((e) => e.expired);
  }

  Future<void> _fetchBlockRules() async {
    final account = Accounts.main;
    final room = roomId;
    final res = await LiveHttp.getLiveInfoByUser(roomId);
    if (_closed || room != roomId || !identical(account, Accounts.main)) return;
    if (res case Success(:final response?)) {
      if (response.keywordList case final keywordList?) {
        _keywordList = keywordList;
      }
      if (response.shieldUserList case final shieldUserList?) {
        _shieldUids = shieldUserList.map((e) => e.uid).toSet();
      }
    }
  }

  void updateBlockRules(List<String> keywords, Set<int> uids) {
    _keywordList = List<String>.from(keywords);
    _shieldUids = Set<int>.from(uids);
    messages.refresh();
  }

  void addShieldUser(int uid) {
    _shieldUids = {..._shieldUids, uid};
    messages.refresh();
  }

  bool isBlocked(String text, Object uid) {
    return _keywordList.any(text.contains) || _shieldUids.contains(uid);
  }

  void startLiveMsg() {
    if (_closed) return;
    final account = Accounts.heartbeat;
    if (messageConnectionState.value == LiveMessageConnectionState.stopped &&
        _messageRoom == roomId &&
        identical(_messageAccount, account)) {
      return;
    }
    if (_messageSession.running &&
        _messageRoom == roomId &&
        identical(_messageAccount, account)) {
      return;
    }
    _messageRoom = roomId;
    if (!identical(_messageAccount, account)) {
      deliveryTracker.clear();
      deliveryRevision.value++;
    }
    _messageAccount = account;
    _messageSession.start(restart: true);
    if (messages.isEmpty) {
      prefetch();
      if (showSuperChat) getSuperChatMsg();
    }
  }

  void retryLiveMessages() {
    if (_closed || !plPlayerController.playerStatus.isPlaying) return;
    _messageSession.stop();
    startLiveMsg();
  }

  Future<bool> _connectMessages(int generation) async {
    final room = roomId;
    final account = Accounts.heartbeat;
    final res = await LiveHttp.liveRoomGetDanmakuToken(roomId: room);
    if (!_messageMatches(generation, room, account)) return false;
    if (res case Success(:final response)) {
      dmInfo = response;
      return initDm(response, generation: generation, account: account);
    }
    return false;
  }

  void listener() {
    final userScrollDirection = scrollController.position.userScrollDirection;
    if (userScrollDirection == .forward) {
      disableAutoScroll.value = true;
    } else if (userScrollDirection == .reverse) {
      final pos = scrollController.position;
      if (pos.maxScrollExtent - pos.pixels <= 100 && disableAutoScroll.value) {
        disableAutoScroll.value = false;
        refreshMsgIfNeeded();
      }
    }
  }

  void refreshMsgIfNeeded() {
    if (shouldRefresh) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        messages.refresh();
      });
    }
  }

  @override
  void onClose() {
    _settingsWorker?.dispose();
    _cornerEmoteTimer?.cancel();
    _closed = true;
    deliveryTracker.dispose();
    roomFeatures.dispose();
    giftEffects.dispose();
    _messageSession.dispose();
    _receivedGiftIds.clear();
    _stopSizeSub();
    cancelLikeTimer();
    cancelLiveTimer();
    savedDanmaku?.clear();
    savedDanmaku = null;
    messages.clear();
    if (showSuperChat) {
      superChatMsg.clear();
      fsSC.value = null;
    }
    scrollController
      ..removeListener(listener)
      ..dispose();
    pageController?.dispose();
    danmakuController = null;
    super.onClose();
  }

  // 修改画质
  Future<void>? changeQn(int qn) {
    if (currentQn == qn) {
      return null;
    }
    currentQn = qn;
    currentQnDesc.value =
        LiveQuality.fromCode(currentQn)?.desc ?? currentQn.toString();
    return queryLiveUrl();
  }

  Future<bool> initDm(
    LiveDmInfoData info, {
    required int generation,
    required Object account,
  }) {
    final room = roomId;
    if (info.hostList.isEmpty) {
      return Future.value(false);
    }
    final stream = LiveMessageStream(
      streamToken: info.token,
      roomId: room,
      uid: Accounts.heartbeat.mid,
      servers: info.hostList
          .map((host) => 'wss://${host.host}:${host.wssPort}/sub')
          .toList(),
      onDisconnected: () => _messageSession.connectionLost(generation),
    );
    _msgStream = stream;
    stream.addEventListener((event) {
      if (_messageMatches(generation, room, account)) _danmakuListener(event);
    });
    return stream.init();
  }

  void addDm(dynamic msg, [DanmakuContentItem<DanmakuExtra>? item]) {
    _trimDm();

    if (plPlayerController.showDanmaku) {
      if (item != null && plPlayerController.enableShowLiveDanmaku.value) {
        danmakuController?.addDanmaku(item);
      }
      if (autoScroll && !disableAutoScroll.value) {
        messages.add(msg);
        scrollToBottom();
        return;
      }
    }

    messages.addOnly(msg);
  }

  @pragma('vm:notify-debugger-on-exception')
  void _danmakuListener(dynamic obj) {
    try {
      roomFeatures.onEvent(obj);
      final notice = LiveRoomNotice.parse(obj, roomId);
      if (notice != null &&
          messageVisible(notice) &&
          !isBlocked(notice.text, notice.uid)) {
        if (notice.id.isEmpty || _receivedNoticeIds.add(notice.id)) {
          addDm(notice);
        }
        if (_receivedNoticeIds.length > 500) {
          _receivedNoticeIds.remove(_receivedNoticeIds.first);
        }
      }
      // logger.i(' 原始弹幕消息 ======> ${jsonEncode(obj)}');
      switch ('${obj['cmd']}'.split(':').first) {
        case 'PREPARING':
          playbackMessage.value = '主播已结束直播';
          plPlayerController.pause();
          break;
        case 'LIVE':
          queryLiveUrl();
          break;
        case 'DANMU_MSG':
          final parsed = LiveMessageParser.danmaku(
            obj,
            showMedal: GlobalData().showMedal,
          );
          if (parsed != null) {
            deliveryTracker.observe(
              uid: parsed.message.extra.mid,
              text: parsed.message.text,
              id: parsed.message.extra.id.toString(),
              timestamp: int.tryParse(parsed.message.extra.ts.toString()),
            );
          }
          if (parsed == null ||
              !messageVisible(parsed.message) ||
              isBlocked(parsed.message.text, parsed.message.extra.mid)) {
            return;
          }
          final emoteUrl = liveAssetUrl(parsed.message.uemote?.url);
          if (parsed.message.uemote?.inPlayerArea == true &&
              emoteUrl.isNotEmpty &&
              settings.enabled(LiveRoomOption.cornerEmotes)) {
            _cornerEmoteTimer?.cancel();
            cornerEmoteUrl.value = emoteUrl;
            _cornerEmoteTimer = Timer(
              const Duration(seconds: 3),
              () => cornerEmoteUrl.value = null,
            );
          }
          addDm(
            parsed.message,
            DanmakuContentItem(
              parsed.message.text,
              color: DanmakuOptions.blockColorful
                  ? Colors.white
                  : DmUtils.decimalToColor(parsed.color),
              type: DmUtils.getPosition(parsed.mode),
              selfSend: isLogin && parsed.message.extra.mid == mid,
              extra: parsed.message.extra,
            ),
          );
          break;
        case 'SEND_GIFT':
        case 'SEND_GIFT_V2':
        case 'GUARD_BUY':
          for (final gift in LiveGiftMessage.parseAll(obj)) {
            if (isBlocked(gift.giftName, gift.uid)) {
              continue;
            }
            if (gift.id.isNotEmpty) {
              if (!_receivedGiftIds.add(gift.id)) continue;
              if (_receivedGiftIds.length > 1000) {
                _receivedGiftIds.remove(_receivedGiftIds.first);
              }
            }
            if (messageVisible(gift)) addDm(gift);
            if (settings.enabled(LiveRoomOption.giftEffects)) {
              giftEffects.add(gift);
            }
          }
          break;
        case 'SUPER_CHAT_MESSAGE'
            when showSuperChat && settings.enabled(LiveRoomOption.superChats):
          final item = SuperChatItem.fromJson(obj['data'], roomId);
          if (!messageVisible(item) ||
              superChatMsg.any((old) => old.id == item.id)) {
            return;
          }
          superChatMsg.insert(0, item);
          addDm(item);
          if (Platform.isAndroid && AndroidHelper.isPipMode) return;
          if (plPlayerController.showDanmaku &&
              (isFullScreen || plPlayerController.isDesktopPip)) {
            fsSC.value = item.copyWith(
              endTime: math.min(
                item.endTime,
                DateTime.now().millisecondsSinceEpoch ~/ 1000 + 10,
              ),
            );
          }
          break;
        case 'SUPER_CHAT_MESSAGE_DELETE':
          final ids = LiveMessageParser.map(obj['data'])['ids'];
          if (ids is List) {
            final deleted = ids.map((id) => '$id').toSet();
            superChatMsg.removeWhere((item) => deleted.contains('${item.id}'));
            messages.removeWhere(
              (item) => item is SuperChatItem && deleted.contains('${item.id}'),
            );
            if (deleted.contains('${fsSC.value?.id}')) fsSC.value = null;
          }
          break;
        case 'WATCHED_CHANGE':
          watchedShow.value = obj['data']['text_large'];
          break;
        case 'ONLINE_RANK_COUNT':
          onlineCount.value = NumUtils.numFormat(obj['data']['count']);
          refreshTopViewers();
          break;
        case 'ROOM_CHANGE':
          title.value = obj['data']['title'];
          break;
      }
    } catch (e, s) {
      if (kDebugMode) {
        Utils.reportError(e, s);
      }
    }
  }

  final RxInt likeClickTime = 0.obs;
  Timer? likeClickTimer;

  void cancelLikeTimer() {
    likeClickTimer?.cancel();
    likeClickTimer = null;
  }

  void onLikeTapDown(_) {
    cancelLikeTimer();
    likeClickTime.value++;
  }

  void onLikeTapUp([_]) {
    likeClickTimer ??= Timer(const Duration(milliseconds: 800), onLike);
  }

  Future<void> onLike() async {
    if (!isLogin) {
      likeClickTime.value = 0;
      return;
    }
    final res = await LiveHttp.liveLikeReport(
      clickTime: likeClickTime.value,
      roomId: roomId,
      uid: mid,
      anchorId: roomInfoH5.value?.roomInfo?.uid,
    );
    if (res.isSuccess) {
      SmartDialog.showToast('点赞成功');
    } else {
      res.toast();
    }
    likeClickTime.value = 0;
  }

  void toastNotLogin() {
    SmartDialog.showToast('账号未登录');
  }

  void onSendDanmaku([bool fromEmote = false]) {
    if (kReleaseMode && !isLogin) {
      toastNotLogin();
      return;
    }
    Get.key.currentState!.push(
      PublishRoute(
        barrierColor: Colors.transparent,
        pageBuilder: (context, animation, secondaryAnimation) {
          return Theme(
            data: ThemeUtils.darkTheme,
            child: LiveSendDmPanel(
              fromEmote: fromEmote,
              liveRoomController: this,
              items: savedDanmaku,
              autofocus: !fromEmote,
              onSave: (msg) {
                if (msg.isEmpty) {
                  savedDanmaku?.clear();
                  savedDanmaku = null;
                } else {
                  savedDanmaku = msg.toList();
                }
              },
            ),
          );
        },
        transitionDuration: fromEmote
            ? const Duration(milliseconds: 400)
            : PlatformUtils.isDesktop
            ? const Duration(milliseconds: 350)
            : const Duration(milliseconds: 400),
      ),
    );
  }

  Future<LoadingState<Map<String, dynamic>>> sendTrackedDanmaku({
    required String message,
    int? dmType,
    Object? emoticonOptions,
    int replyMid = 0,
    String replayDmid = '',
    int mode = 1,
    int color = 0xffffff,
  }) async {
    final account = Accounts.main;
    final entry = deliveryTracker.begin(
      account.mid,
      message,
      connected:
          messageConnectionState.value == LiveMessageConnectionState.connected,
    );
    try {
      final result = await LiveHttp.sendLiveMsg(
        roomId: roomId,
        msg: message,
        dmType: dmType,
        emoticonOptions: emoticonOptions,
        replyMid: replyMid,
        replayDmid: replayDmid,
        mode: mode,
        color: color,
      );
      if (result case Success(:final response)) {
        deliveryTracker.accepted(
          entry,
          id: (response['id_str'] ?? response['dmid_str'] ?? response['dmid'])
              ?.toString(),
        );
      } else {
        deliveryTracker.failed(entry, reason: result.toString());
      }
      return result;
    } catch (_) {
      deliveryTracker.failed(entry, unknown: true);
      return const Error('网络异常，发送结果未知，请先查看弹幕回显');
    }
  }

  Future<void> onBuySuperChat(BuildContext context) =>
      showLiveSuperChatPurchase(
        context,
        roomId: roomId,
        anchorUid: ruid,
        anchorName: roomInfoH5.value?.anchorInfo?.baseInfo?.uname ?? '当前主播',
        areaId: roomInfoH5.value?.roomInfo?.areaId,
        parentAreaId: roomInfoH5.value?.roomInfo?.parentAreaId,
      );

  void onAtUser(DanmakuMsg item) {
    savedDanmaku = [
      RichTextItem.fromStart(
        '@${item.name} ',
        rawText: item.extra.mid.toString(),
        type: .at,
        id: item.extra.id.toString(),
      ),
    ];
    onSendDanmaku();
  }

  void reportSC(SuperChatItem item) {
    if (!isLogin) {
      toastNotLogin();
      return;
    }
    autoWrapReportDialog(
      Get.context!,
      ban: false,
      ReportOptions.liveDanmakuReport,
      withContent: ReportOptions.liveDanmakuReportCheck,
      contentRequired: ReportOptions.liveDanmakuReportCheck,
      (reasonType, reasonDesc, banUid) {
        return LiveHttp.superChatReport(
          id: item.id,
          roomId: roomId,
          uid: item.uid,
          msg: item.message,
          reason: ReportOptions.liveDanmakuReport['']![reasonType]!,
          ts: item.ts,
          token: item.token,
        );
      },
    );
  }
}
