import 'package:PiliPlus/models_new/live/gift/live_gift.dart';
import 'package:PiliPlus/models_new/live/live_danmaku/live_user_badges.dart';
import 'package:PiliPlus/models_new/live/live_medal_wall/uinfo_medal.dart';
import 'package:PiliPlus/models_new/live/live_superchat/user_info.dart';
import 'package:PiliPlus/utils/bili_utils.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/parse_int.dart';
import 'package:PiliPlus/utils/parse_string.dart';
import 'package:PiliPlus/utils/utils.dart';

class SuperChatItem {
  int id;
  int uid;
  int price;
  String? backgroundImage;
  String backgroundColor;
  String backgroundBottomColor;
  String backgroundPriceColor;
  String messageFontColor;
  int startSime;
  int endTime;
  String message;
  String token;
  int ts;
  UserInfo userInfo;
  late bool expired = false;
  late bool deleted = false;
  UinfoMedal? medalInfo;
  int roomid;

  SuperChatItem({
    required this.id,
    required this.uid,
    required this.price,
    this.backgroundImage,
    required this.backgroundColor,
    required this.backgroundBottomColor,
    required this.backgroundPriceColor,
    required this.messageFontColor,
    required this.startSime,
    required this.endTime,
    required this.message,
    required this.token,
    required this.ts,
    required this.userInfo,
    this.medalInfo,
    required this.roomid,
  });

  static SuperChatItem get random {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return SuperChatItem.fromJson(
      {
        "id": Utils.random.nextInt(2147483647),
        "uid": 0,
        "price": 66,
        "start_time": now,
        "end_time": now + 5,
        "message": Utils.generateRandomString(55),
        "user_info": {
          "face": "",
          'face_frame': BiliUtils.liveGuardPendant(Utils.random.nextInt(4)),
          "uname": "UNAME",
        },
        'token': '',
        'ts': now,
        'uinfo': {
          'medal': {
            "name": "Medal",
            "level": Utils.random.nextInt(40),
            "id": 123,
            "ruid": 456,
            "v2_medal_color_start": "#4C7DFF99",
            "v2_medal_color_text": "#FFFFFF",
          },
        },
      },
      Utils.random.nextInt(2147483647),
    );
  }

  factory SuperChatItem.fromJson(Map<String, dynamic> json, int roomid) {
    final user = liveMap(json['uinfo']);
    final base = liveMap(user['base']);
    final legacy = liveMap(json['user_info']);
    final badges = LiveUserBadges.parse(user, data: json);
    UinfoMedal? medal;
    if (!badges.anonymous && GlobalData().showMedal) {
      try {
        medal = UinfoMedal.lightMedal(user['medal']);
      } catch (_) {}
    }
    return SuperChatItem(
      id: safeToInt(json['id']) ?? 0,
      uid: badges.anonymous ? 0 : safeToInt(user['uid'] ?? json['uid']) ?? 0,
      price: safeToInt(json['price']) ?? 0,
      backgroundImage: nonNullOrEmptyString(json['background_image']),
      backgroundColor: json['background_color'] ?? '#EDF5FF',
      backgroundBottomColor: json['background_bottom_color'] ?? '#2A60B2',
      backgroundPriceColor: json['background_price_color'] ?? '#7497CD',
      messageFontColor: json['message_font_color'] ?? '#FFFFFF',
      startSime: safeToInt(json['start_time']) ?? 0,
      endTime: safeToInt(json['end_time']) ?? 0,
      message: '${json['message'] ?? ''}',
      token: '${json['token'] ?? ''}',
      ts: safeToInt(json['ts']) ?? 0,
      userInfo: UserInfo.fromJson({
        ...legacy,
        'uname': badges.anonymous
            ? '匿名观众'
            : base['name'] ?? legacy['uname'] ?? '观众',
        'face': badges.anonymous ? '' : base['face'] ?? legacy['face'] ?? '',
        'face_frame': badges.anonymous ? null : legacy['face_frame'],
        'name_color': base['name_color_str'] ?? legacy['name_color'],
      }),
      medalInfo: medal,
      roomid: roomid,
    );
  }

  SuperChatItem copyWith({
    int? id,
    int? uid,
    int? price,
    String? backgroundColor,
    String? backgroundBottomColor,
    String? backgroundPriceColor,
    String? messageFontColor,
    int? startSime,
    int? endTime,
    String? message,
    String? token,
    int? ts,
    UserInfo? userInfo,
    bool? expired,
    UinfoMedal? medalInfo,
  }) {
    return SuperChatItem(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      price: price ?? this.price,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundBottomColor:
          backgroundBottomColor ?? this.backgroundBottomColor,
      backgroundPriceColor: backgroundPriceColor ?? this.backgroundPriceColor,
      messageFontColor: messageFontColor ?? this.messageFontColor,
      startSime: startSime ?? this.startSime,
      endTime: endTime ?? this.endTime,
      message: message ?? this.message,
      token: token ?? this.token,
      ts: ts ?? this.ts,
      userInfo: userInfo ?? this.userInfo,
      medalInfo: medalInfo ?? this.medalInfo,
      roomid: roomid,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'uid': uid,
    'price': price,
    'background_image': backgroundImage,
    'background_color': backgroundColor,
    'background_bottom_color': backgroundBottomColor,
    'background_price_color': backgroundPriceColor,
    'message_font_color': messageFontColor,
    'start_time': startSime,
    'end_time': endTime,
    'message': message,
    'token': token,
    'ts': ts,
    'user_info': userInfo.toJson(),
    'medal': ?medalInfo?.toJson(),
    'roomid': roomid,
  };
}
