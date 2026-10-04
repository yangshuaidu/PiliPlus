import 'package:PiliPlus/models_new/live/live_danmaku_style.dart';
import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/http/api.dart';
import 'package:PiliPlus/http/constants.dart';
import 'package:PiliPlus/http/browser_ua.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/login.dart';
import 'package:PiliPlus/http/retry_interceptor.dart';
import 'package:PiliPlus/models/common/account_type.dart';
import 'package:PiliPlus/models/common/live/live_contribution_rank_type.dart';
import 'package:PiliPlus/models/common/live/live_search_type.dart';
import 'package:PiliPlus/models_new/live/live_area_list/area_item.dart';
import 'package:PiliPlus/models_new/live/live_area_list/area_list.dart';
import 'package:PiliPlus/models_new/live/live_contribution_rank/data.dart';
import 'package:PiliPlus/models_new/live/live_danmaku/danmaku_msg.dart';
import 'package:PiliPlus/models_new/live/live_dm_block/data.dart';
import 'package:PiliPlus/models_new/live/live_dm_block/shield_info.dart';
import 'package:PiliPlus/models_new/live/live_dm_block/shield_user_list.dart';
import 'package:PiliPlus/models_new/live/live_dm_info/data.dart';
import 'package:PiliPlus/models_new/live/live_emote/data.dart';
import 'package:PiliPlus/models_new/live/live_emote/datum.dart';
import 'package:PiliPlus/models_new/live/live_feed_index/data.dart';
import 'package:PiliPlus/models_new/live/live_follow/data.dart';
import 'package:PiliPlus/models_new/live/live_medal_wall/data.dart';
import 'package:PiliPlus/models_new/live/live_room_info_h5/data.dart';
import 'package:PiliPlus/models_new/live/live_room_play_info/data.dart';
import 'package:PiliPlus/models_new/live/live_search/data.dart';
import 'package:PiliPlus/models_new/live/live_second_list/data.dart';
import 'package:PiliPlus/models_new/live/live_superchat/data.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/app_sign.dart';
import 'package:PiliPlus/utils/wbi_sign.dart';
import 'package:dio/dio.dart';

abstract final class LiveHttp {
  static Account get recommend => Accounts.get(AccountType.recommend);

  static Future<Map<String, dynamic>> liveGiftMaterials(
    int roomId,
    int anchorUid,
  ) async {
    final response = await Request().get(
      '${HttpString.liveBaseUrl}/xlive/web-room/v1/giftPanel/roomGiftList',
      queryParameters: {
        'room_id': roomId,
        'ruid': anchorUid,
        'platform': 'pc',
        'source': 'live',
        'build': 0,
      },
    );
    final data = response.data;
    return data['code'] == 0 && data['data'] is Map
        ? Map<String, dynamic>.from(data['data'])
        : {};
  }

  static Future<LoadingState<Map<String, dynamic>>> liveActivityInfo(
    int roomId, {
    bool anchor = false,
  }) async {
    final response = await Request().get(
      '${HttpString.liveBaseUrl}/xlive/lottery-interface/v1/${anchor ? 'Anchor/Check' : 'lottery/getLotteryInfoWeb'}',
      queryParameters: {'roomid': roomId, if (!anchor) 'need_guard': true},
    );
    final data = response.data;
    return data['code'] == 0
        ? Success(
            data['data'] is Map
                ? Map<String, dynamic>.from(data['data'])
                : <String, dynamic>{},
          )
        : Error('${data['message'] ?? data['msg'] ?? '活动信息不可用'}');
  }

  static Future<LoadingState<Map<String, dynamic>>> liveRoomWebInfo(
    int roomId,
  ) async {
    final response = await Request().get(
      '${HttpString.liveBaseUrl}/xlive/web-room/v1/index/getInfoByRoom',
      queryParameters: await WbiSign.makSign({
        'room_id': roomId,
        'web_location': 444.8,
      }),
    );
    final data = response.data;
    return data['code'] == 0 && data['data'] is Map
        ? Success(Map<String, dynamic>.from(data['data']))
        : Error('${data['message'] ?? '直播间扩展信息不可用'}');
  }

  static Future<LoadingState<Map<String, dynamic>>> livePkInfo(
    int roomId,
    int pkId, {
    bool legacy = false,
    int? pkVersion,
  }) async {
    final response = await Request().get(
      '${HttpString.liveBaseUrl}${legacy ? '/xlive/general-interface/v1/battle/getInfoById' : '/xlive/general-interface/v2/pk/info'}',
      queryParameters: {
        'room_id': roomId,
        'pk_id': pkId,
        if (legacy && pkVersion != null)
          'pk_version': pkVersion == 3 ? 6 : pkVersion,
      },
    );
    final data = response.data;
    return data['code'] == 0 && data['data'] is Map
        ? Success(Map<String, dynamic>.from(data['data']))
        : Error('${data['message'] ?? 'PK 信息不可用'}');
  }

  static Future<LoadingState<Map<String, dynamic>>> liveGuardRank({
    required int roomId,
    required int ruid,
    required int page,
    required int type,
  }) async {
    final response = await Request().get(
      '${HttpString.liveBaseUrl}/xlive/app-room/v2/guardTab/topListNew',
      queryParameters: {
        'roomid': roomId,
        'ruid': ruid,
        'page': page,
        'page_size': 20,
        'typ': type,
        'platform': 'web',
      },
    );
    final data = response.data;
    if (data['code'] == 0 && data['data'] is Map) {
      return Success(Map<String, dynamic>.from(data['data']));
    }
    return Error('${data['message'] ?? data['msg'] ?? '大航海榜单不可用'}');
  }

  static Future<LiveDanmakuStyleConfig> liveDanmakuStyles(Object roomId) async {
    final account = Accounts.main;
    final response = await Request().get(
      '${HttpString.liveBaseUrl}/xlive/web-room/v1/dM/GetDMConfigByGroup',
      queryParameters: {'room_id': roomId},
      options: Options(extra: {'account': account}),
    );
    if (!identical(account, Accounts.main)) throw StateError('账号已变化，请重新打开样式面板');
    final data = response.data;
    if (data is! Map || data['code'] != 0 || data['data'] is! Map)
      throw StateError(
        '${data is Map ? data['message'] ?? '样式权限读取失败' : '样式权限读取失败'}',
      );
    return LiveDanmakuStyleConfig.parse(
      Map<String, dynamic>.from(data['data']),
    );
  }

  static Future<LoadingState<Map<String, dynamic>>> sendLiveMsg({
    required Object roomId,
    required Object msg,
    Object? dmType,
    Object? emoticonOptions,
    int replyMid = 0,
    String replayDmid = '',
    int mode = 1,
    int color = 0xffffff,
  }) async {
    final account = Accounts.main;
    final csrf = account.csrf;
    if (mode != 1 || color != 0xffffff) {
      try {
        final styles = await liveDanmakuStyles(roomId);
        if (!styles.permits(mode, color))
          return const Error('所选弹幕样式权限已变化，请重新选择');
      } catch (_) {
        return const Error('未能核验弹幕样式权限，本次未发送，请稍后重试');
      }
    }
    final signature = await WbiSign.makSign({'web_location': 444.8});
    if (!account.isLogin || !identical(account, Accounts.main)) {
      return const Error('账号已变化，请重新发送');
    }
    // A lost reply does not authorize retransmitting the same chat message.
    // The clone shares the main adapter and must not close it.
    final client = Request.dio.clone()
      ..interceptors.removeWhere(
        (i) => i is RetryInterceptor || i is LogInterceptor,
      );
    final res = await client.post(
      Api.sendLiveMsg,
      queryParameters: signature,
      options: Options(
        extra: {'account': account},
        followRedirects: false,
        maxRedirects: 0,
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
      data: FormData.fromMap({
        'bubble': 0,
        'msg': msg,
        'color': color,
        'mode': mode,
        'dm_type': ?dmType,
        if (emoticonOptions != null)
          'emoticonOptions': emoticonOptions
        else ...{
          'room_type': 0,
          'jumpfrom': 0,
          'reply_mid': replyMid,
          'reply_attr': 0,
          'replay_dmid': replayDmid,
          'statistics': '{"appId":100,"platform":5}',
          'reply_type': 0,
          'reply_uname': '',
        },
        'fontsize': 25,
        'rnd': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'roomid': roomId,
        'csrf': csrf,
        'csrf_token': csrf,
      }),
    );
    if (res.data['code'] == 0) {
      final data = res.data['data'];
      return Success(data is Map ? Map<String, dynamic>.from(data) : {});
    } else {
      return Error(res.data['message']);
    }
  }

  static Future<LoadingState<RoomPlayInfoData>> liveRoomInfo({
    required Object roomId,
    Object? qn,
    bool onlyAudio = false,
  }) async {
    final res = await Request().get(
      Api.liveRoomInfo,
      queryParameters: await WbiSign.makSign({
        'room_id': roomId,
        'protocol': '0,1',
        'format': '0,1,2',
        'codec': '0,1,2',
        'qn': ?qn,
        'platform': 'web',
        'ptype': 8,
        'dolby': 5,
        'panorama': 1,
        if (onlyAudio) 'only_audio': 1,
        'web_location': 444.8,
      }),
    );
    if (res.data['code'] == 0) {
      try {
        return Success(RoomPlayInfoData.fromJson(res.data['data']));
      } catch (e) {
        return Error(e.toString());
      }
    } else {
      return Error(res.data['message']);
    }
  }

  static Future<LoadingState<RoomInfoH5Data>> liveRoomInfoH5({
    required Object roomId,
  }) async {
    // Mobile room metadata carries the anchor's app skin. The web background
    // can be a platform default even when a custom mobile skin is configured.
    try {
      final params = <String, dynamic>{
        'room_id': roomId,
        'platform': 'android',
        'mobi_app': 'android',
        'device': 'android',
        'build': 8000000,
      };
      AppSign.appSign(params);
      final mobile = await Request().get(
        '${HttpString.liveBaseUrl}/xlive/app-room/v1/index/getInfoByRoom',
        queryParameters: params,
      );
      if (mobile.data['code'] == 0 &&
          mobile.data['data'] is Map<String, dynamic>) {
        return Success(RoomInfoH5Data.fromJson(mobile.data['data']));
      }
    } catch (_) {
      // Retain room information when the app endpoint is unavailable.
    }
    final res = await Request().get(
      Api.liveRoomInfoH5,
      queryParameters: {'room_id': roomId},
    );
    if (res.data['code'] == 0) {
      return Success(RoomInfoH5Data.fromJson(res.data['data']));
    } else {
      return Error(res.data['message']);
    }
  }

  static Future<LoadingState<List<DanmakuMsg>?>> liveRoomDmPrefetch({
    required Object roomId,
  }) async {
    final res = await Request().get(
      Api.liveRoomDmPrefetch,
      queryParameters: {'roomid': roomId},
      options: Options(
        headers: {
          'referer': 'https://live.bilibili.com/$roomId',
          'user-agent': BrowserUa.pc,
        },
      ),
    );
    if (res.data['code'] == 0) {
      try {
        return Success(
          (res.data['data']?['room'] as List?)
              ?.map((e) => DanmakuMsg.fromPrefetch(e))
              .toList(),
        );
      } catch (e) {
        return Error(e.toString());
      }
    } else {
      return Error(res.data['message']);
    }
  }

  static Future<LoadingState<LiveDmInfoData>> liveRoomGetDanmakuToken({
    required Object roomId,
  }) async {
    final res = await Request().get(
      Api.liveRoomDmToken,
      queryParameters: await WbiSign.makSign({
        'id': roomId,
        'web_location': 444.8,
      }),
    );
    if (res.data['code'] == 0) {
      try {
        return Success(LiveDmInfoData.fromJson(res.data['data']));
      } catch (e) {
        return Error(e.toString());
      }
    } else {
      return Error(res.data['message']);
    }
  }

  static Future<LoadingState<List<LiveEmoteDatum>?>> getLiveEmoticons({
    required int roomId,
  }) async {
    final res = await Request().get(
      Api.getLiveEmoticons,
      queryParameters: {
        'platform': 'pc',
        'room_id': roomId,
      },
    );
    if (res.data['code'] == 0) {
      return Success(LiveEmoteData.fromJson(res.data['data']).data);
    } else {
      return Error(res.data['message']);
    }
  }

  static Future<LoadingState<LiveIndexData>> liveFeedIndex({
    required int pn,
    bool moduleSelect = false,
  }) async {
    final params = {
      'access_key': ?recommend.accessKey,
      'channel': 'master',
      'actionKey': 'appkey',
      'build': 8430300,
      'version': '8.43.0',
      'c_locale': 'zh_CN',
      'device': 'android',
      'device_name': 'android',
      'device_type': 0,
      'fnval': 912,
      'disable_rcmd': 0,
      'https_url_req': 1,
      if (moduleSelect) 'module_select': 1,
      'mobi_app': 'android',
      'network': 'wifi',
      'page': pn,
      'platform': 'android',
      if (recommend.isLogin) 'relation_page': 1,
      's_locale': 'zh_CN',
      'scale': 2,
      'statistics': Constants.statisticsApp,
    };
    AppSign.appSign(params);
    final res = await Request().get(
      Api.liveFeedIndex,
      queryParameters: params,
      options: Options(
        headers: {
          'buvid': LoginHttp.buvid,
          'fp_local': '1111111111111111111111111111111111111111111111111111111111111111',
          'fp_remote': '1111111111111111111111111111111111111111111111111111111111111111',
          'session_id': '11111111',
          'env': 'prod',
          'app-key': 'android',
          'User-Agent': Constants.userAgentApp,
          'x-bili-trace-id': Constants.traceId,
          'x-bili-aurora-eid': '',
          'x-bili-aurora-zone': '',
          'bili-http-engine': 'cronet',
        },
      ),
    );
    if (res.data['code'] == 0) {
      return Success(LiveIndexData.fromJson(res.data['data']));
    } else {
      return Error(res.data['message']);
    }
  }

  static Future<LoadingState<LiveFollowData>> liveFollow(int page) async {
    final res = await Request().get(
      Api.liveFollow,
      queryParameters: {
        'page': page,
        'page_size': 9,
        'ignoreRecord': 1,
        'hit_ab': true,
      },
    );
    if (res.data['code'] == 0) {
      return Success(LiveFollowData.fromJson(res.data['data']));
    } else {
      return Error(res.data['message']);
    }
  }

  static Future<LoadingState<LiveSecondData>> liveSecondList({
    required int pn,
    required Object? areaId,
    required Object? parentAreaId,
    String? sortType,
  }) async {
    final params = {
      'access_key': ?recommend.accessKey,
      'actionKey': 'appkey',
      'channel': 'master',
      'area_id': ?areaId,
      'parent_area_id': ?parentAreaId,
      'build': 8430300,
      'version': '8.43.0',
      'c_locale': 'zh_CN',
      'device': 'android',
      'device_name': 'android',
      'device_type': 0,
      'fnval': 912,
      'disable_rcmd': 0,
      'https_url_req': 1,
      'mobi_app': 'android',
      'module_select': 0,
      'network': 'wifi',
      'page': pn,
      'page_size': 20,
      'platform': 'android',
      'qn': 0,
      'sort_type': ?sortType,
      'tag_version': 1,
      's_locale': 'zh_CN',
      'scale': 2,
      'statistics': Constants.statisticsApp,
    };
    AppSign.appSign(params);
    final res = await Request().get(
      Api.liveSecondList,
      queryParameters: params,
      options: Options(
        headers: {
          'buvid': LoginHttp.buvid,
          'fp_local': '1111111111111111111111111111111111111111111111111111111111111111',
          'fp_remote': '1111111111111111111111111111111111111111111111111111111111111111',
          'session_id': '11111111',
          'env': 'prod',
          'app-key': 'android',
          'User-Agent': Constants.userAgentApp,
          'x-bili-trace-id': Constants.traceId,
          'x-bili-aurora-eid': '',
          'x-bili-aurora-zone': '',
          'bili-http-engine': 'cronet',
        },
      ),
    );
    if (res.data['code'] == 0) {
      return Success(LiveSecondData.fromJson(res.data['data']));
    } else {
      return Error(res.data['message']);
    }
  }

  static Future<LoadingState<List<AreaList>?>> liveAreaList() async {
    final params = {
      'access_key': ?recommend.accessKey,
      'actionKey': 'appkey',
      'build': 8430300,
      'channel': 'master',
      'version': '8.43.0',
      'c_locale': 'zh_CN',
      'device': 'android',
      'disable_rcmd': 0,
      'mobi_app': 'android',
      'platform': 'android',
      's_locale': 'zh_CN',
      'statistics': Constants.statisticsApp,
    };
    AppSign.appSign(params);
    final res = await Request().get(
      Api.liveAreaList,
      queryParameters: params,
    );
    if (res.data['code'] == 0) {
      return Success(
        (res.data['data']?['list'] as List?)
            ?.map((e) => AreaList.fromJson(e))
            .toList(),
      );
    } else {
      return Error(res.data['message']);
    }
  }

  static Future<LoadingState<List<AreaItem>>> getLiveFavTag() async {
    final params = {
      'access_key': ?Accounts.main.accessKey,
      'actionKey': 'appkey',
      'build': 8430300,
      'channel': 'master',
      'version': '8.43.0',
      'c_locale': 'zh_CN',
      'device': 'android',
      'disable_rcmd': 0,
      'mobi_app': 'android',
      'platform': 'android',
      's_locale': 'zh_CN',
      'statistics': Constants.statisticsApp,
    };
    AppSign.appSign(params);
    final res = await Request().get(
      Api.getLiveFavTag,
      queryParameters: params,
    );

    if (res.data['code'] == 0) {
      return Success(
        (res.data['data']?['tags'] as List?)
                ?.map((e) => AreaItem.fromJson(e))
                .toList() ??
            <AreaItem>[],
      );
    } else {
      return Error(res.data['message']);
    }
  }

  static Future<LoadingState<void>> setLiveFavTag({
    required String ids,
  }) async {
    final data = {
      'tags': ids,
      'access_key': Accounts.main.accessKey,
      'actionKey': 'appkey',
      'build': 8430300,
      'channel': 'master',
      'version': '8.43.0',
      'c_locale': 'zh_CN',
      'device': 'android',
      'disable_rcmd': 0,
      'mobi_app': 'android',
      'platform': 'android',
      's_locale': 'zh_CN',
      'statistics': Constants.statisticsApp,
    };
    AppSign.appSign(data);
    final res = await Request().post(
      Api.setLiveFavTag,
      data: data,
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );

    if (res.data['code'] == 0) {
      return const Success(null);
    } else {
      return Error(res.data['message']);
    }
  }

  static Future<LoadingState<List<AreaItem>?>> liveRoomAreaList({
    required Object parentid,
  }) async {
    final params = {
      'access_key': ?recommend.accessKey,
      'actionKey': 'appkey',
      'build': 8430300,
      'channel': 'master',
      'version': '8.43.0',
      'c_locale': 'zh_CN',
      'device': 'android',
      'disable_rcmd': 0,
      'need_entrance': 1,
      'parent_id': parentid,
      'source_id': 2,
      'mobi_app': 'android',
      'platform': 'android',
      's_locale': 'zh_CN',
      'statistics': Constants.statisticsApp,
    };
    AppSign.appSign(params);
    final res = await Request().get(
      Api.liveRoomAreaList,
      queryParameters: params,
    );
    if (res.data['code'] == 0) {
      return Success(
        (res.data['data'] as List?)?.map((e) => AreaItem.fromJson(e)).toList(),
      );
    } else {
      return Error(res.data['message']);
    }
  }

  static Future<LoadingState<LiveSearchData>> liveSearch({
    required int page,
    required String keyword,
    required LiveSearchType type,
  }) async {
    final params = {
      'access_key': ?recommend.accessKey,
      'actionKey': 'appkey',
      'build': 8430300,
      'channel': 'master',
      'version': '8.43.0',
      'c_locale': 'zh_CN',
      'device': 'android',
      'page': page,
      'pagesize': 30,
      'keyword': keyword,
      'disable_rcmd': 0,
      'mobi_app': 'android',
      'platform': 'android',
      's_locale': 'zh_CN',
      'statistics': Constants.statisticsApp,
      'type': type.name,
    };
    AppSign.appSign(params);
    final res = await Request().get(
      Api.liveSearch,
      queryParameters: params,
    );
    if (res.data['code'] == 0) {
      return Success(LiveSearchData.fromJson(res.data['data']));
    } else {
      return Error(res.data['message']);
    }
  }

  static Future<LoadingState<ShieldInfo?>> getLiveInfoByUser(
    Object roomId,
  ) async {
    final res = await Request().get(
      Api.getLiveInfoByUser,
      queryParameters: await WbiSign.makSign({
        'room_id': roomId,
        'from': 0,
        'not_mock_enter_effect': 1,
        'web_location': 444.8,
      }),
    );
    if (res.data['code'] == 0) {
      return Success(LiveDmBlockData.fromJson(res.data['data']).shieldInfo);
    } else {
      return Error(res.data['message']);
    }
  }

  static Future<LoadingState<void>> liveSetSilent({
    required String type,
    required int level,
  }) async {
    final csrf = Accounts.main.csrf;
    final res = await Request().post(
      Api.liveSetSilent,
      data: {
        'type': type,
        'level': level,
        'csrf': csrf,
        'csrf_token': csrf,
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    if (res.data['code'] == 0) {
      return const Success(null);
    } else {
      return Error(res.data['message']);
    }
  }

  static Future<LoadingState<void>> addShieldKeyword({
    required String keyword,
  }) async {
    final account = Accounts.main;
    final csrf = account.csrf;
    final res = await Request().post(
      Api.addShieldKeyword,
      data: {
        'keyword': keyword,
        'csrf': csrf,
        'csrf_token': csrf,
      },
      options: Options(
        extra: {'account': account},
        contentType: Headers.formUrlEncodedContentType,
      ),
    );
    if (res.data['code'] == 0) {
      return const Success(null);
    } else {
      return Error(res.data['message']);
    }
  }

  static Future<LoadingState<void>> delShieldKeyword({
    required String keyword,
  }) async {
    final account = Accounts.main;
    final csrf = account.csrf;
    final res = await Request().post(
      Api.delShieldKeyword,
      data: {
        'keyword': keyword,
        'csrf': csrf,
        'csrf_token': csrf,
      },
      options: Options(
        extra: {'account': account},
        contentType: Headers.formUrlEncodedContentType,
      ),
    );
    if (res.data['code'] == 0) {
      return const Success(null);
    } else {
      return Error(res.data['message']);
    }
  }

  static Future<LoadingState<ShieldUserList>> liveShieldUser({
    required Object uid,
    required Object roomid,
    required int type,
  }) async {
    final account = Accounts.main;
    final csrf = account.csrf;
    final res = await Request().post(
      Api.liveShieldUser,
      data: {
        'uid': uid,
        'roomid': roomid,
        'type': type,
        'csrf': csrf,
        'csrf_token': csrf,
      },
      options: Options(
        extra: {'account': account},
        contentType: Headers.formUrlEncodedContentType,
      ),
    );
    if (res.data['code'] == 0) {
      return Success(ShieldUserList.fromJson(res.data['data']));
    } else {
      return Error(res.data['message']);
    }
  }

  static Future<LoadingState<void>> liveLikeReport({
    required int clickTime,
    required Object roomId,
    required Object uid,
    Object? anchorId,
  }) async {
    final res = await Request().post(
      Api.liveLikeReport,
      data: await WbiSign.makSign({
        'click_time': clickTime,
        'room_id': roomId,
        'uid': uid,
        'anchor_id': ?anchorId,
        'web_location': 444.8,
        'csrf': Accounts.heartbeat.csrf,
      }),
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    if (res.data['code'] == 0) {
      return const Success(null);
    } else {
      return Error(res.data['message']);
    }
  }

  @pragma('vm:notify-debugger-on-exception')
  static Future<LoadingState<SuperChatData>> superChatMsg(
    int roomId,
  ) async {
    final res = await Request().get(
      Api.superChatMsg,
      queryParameters: {
        'room_id': roomId,
      },
    );
    if (res.data['code'] == 0) {
      try {
        return Success(SuperChatData.fromJson(res.data['data'], roomId));
      } catch (e, s) {
        return Error('$e\n\n$s');
      }
    } else {
      return Error(res.data['message']);
    }
  }

  static Future<LoadingState<void>> liveDmReport({
    required int roomId,
    required Object mid,
    required String msg,
    required String reason,
    required int reasonId,
    required int dmType,
    required Object idStr,
    required Object ts,
    required Object sign,
  }) async {
    final csrf = Accounts.main.csrf;
    final data = {
      'id': 0,
      'roomid': roomId,
      'tuid': mid,
      'msg': msg,
      'reason': reason,
      'ts': ts,
      'sign': sign,
      'reason_id': reasonId,
      'token': '',
      'dm_type': dmType,
      'id_str': idStr,
      'csrf_token': csrf,
      'csrf': csrf,
      'visit_id': '',
    };
    final res = await Request().post(
      Api.liveDmReport,
      data: data,
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    if (res.data['code'] == 0) {
      return const Success(null);
    } else {
      return Error(res.data['message']);
    }
  }

  static Future<LoadingState<LiveContributionRankData>> liveContributionRank({
    required Object ruid,
    required Object roomId,
    required int page,
    required LiveContributionRankType type,
  }) async {
    final res = await Request().get(
      Api.liveContributionRank,
      queryParameters: await WbiSign.makSign({
        'ruid': ruid,
        'room_id': roomId,
        'page': page,
        'page_size': 100,
        'type': type.name,
        'switch': type.sw1tch,
        'platform': 'web',
        'web_location': 444.8,
      }),
    );
    if (res.data['code'] == 0) {
      try {
        return Success(LiveContributionRankData.fromJson(res.data['data']));
      } catch (e, s) {
        return Error('$e\n\n$s');
      }
    } else {
      return Error(res.data['message']);
    }
  }

  static Future<LoadingState<void>> superChatReport({
    required int id,
    required Object roomId,
    required Object uid,
    required String msg,
    required String reason,
    required int ts,
    required String token,
  }) async {
    final csrf = Accounts.main.csrf;
    final res = await Request().post(
      Api.superChatReport,
      data: {
        'id': id,
        'roomid': roomId,
        'uid': uid,
        'msg': msg,
        'reason': reason,
        'ts': ts,
        'sign': '',
        'reason_id': reason,
        'token': token,
        'id_str': id.toString(),
        'csrf_token': csrf,
        'csrf': csrf,
        'visit_id': '',
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    if (res.data['code'] == 0) {
      return const Success(null);
    } else {
      return Error(res.data['message']);
    }
  }

  static Future<LoadingState<MedalWallData>> liveMedalWall({
    required Object mid,
  }) async {
    final res = await Request().get(
      Api.liveMedalWall,
      queryParameters: {'target_id': mid},
    );
    if (res.data['code'] == 0) {
      return Success(MedalWallData.fromJson(res.data['data']));
    } else {
      return Error(res.data['message']);
    }
  }

  static Future<LoadingState<void>> liveFeedback(
    Object roomId,
    Object id,
    String type, {
    int page = 1,
  }) async {
    final params = {
      'access_key': ?recommend.accessKey,
      'actionKey': 'appkey',
      'build': 8430300,
      'channel': 'master',
      'c_locale': 'zh_CN',
      'device': 'android',
      'disable_rcmd': 0,
      'mobi_app': 'android',
      'platform': 'android',
      's_locale': 'zh_CN',
      'statistics': Constants.statisticsApp,
      'version': '8.43.0',
      'id': id,
      'id_type': type,
      'room_id': roomId,
      'type': 'dislike',
      'page': page,
    };
    AppSign.appSign(params);
    final res = await Request().get(
      Api.liveFeedback,
      queryParameters: params,
    );
    if (res.data['code'] == 0) {
      return const Success(null);
    } else {
      return Error(res.data['message']);
    }
  }
}
