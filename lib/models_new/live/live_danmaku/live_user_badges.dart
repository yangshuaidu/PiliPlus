import 'package:PiliPlus/models_new/live/gift/live_gift.dart';

String liveAssetUrl(dynamic value) {
  final text = value is String ? value : '';
  final url = text.startsWith('//') ? 'https:$text' : text;
  final uri = Uri.tryParse(url);
  return uri != null &&
          (uri.scheme == 'https' || uri.scheme == 'http') &&
          uri.host.isNotEmpty
      ? url
      : '';
}

/// Public identity decoration only; anonymous users never inherit raw badges.
class LiveUserBadges {
  const LiveUserBadges({
    this.rank = 0,
    this.wealth = 0,
    this.guard = 0,
    this.manager = false,
    this.title = '',
    this.titleImage = '',
    this.medalName = '',
    this.medalLevel = 0,
    this.medalColor = '',
    this.nameColor = '',
    this.anonymous = false,
    this.medalAnchorUid = 0,
    this.medalRoomId = 0,
    this.medalAnchorName = '',
    this.titleId = '',
  });
  final int rank, wealth, guard, medalLevel;
  final bool manager, anonymous;
  final String title, titleImage, medalName, medalColor, nameColor;
  final int medalAnchorUid, medalRoomId;
  final String medalAnchorName, titleId;
  static dynamic _at(dynamic list, int index) =>
      list is List && index < list.length ? list[index] : null;
  factory LiveUserBadges.parse(
    Map<String, dynamic> user, {
    dynamic info,
    Map<String, dynamic> data = const {},
  }) {
    final base = liveMap(user['base']);
    final anonymous =
        liveBool(base['is_mystery']) == true ||
        liveBool(data['is_mystery']) == true ||
        user['anonymous'] == true ||
        liveMap(user['anon']).isNotEmpty;
    if (anonymous) return const LiveUserBadges(anonymous: true);
    final medal = liveMap(
      user['medal'] ?? data['medal_info'] ?? data['fans_medal'],
    );
    final oldMedal = _at(info, 3);
    final title = liveMap(user['title']);
    final titleValue =
        '${title['name'] ?? title['title'] ?? title['title_css_id'] ?? title['TitleCssId'] ?? _at(_at(info, 5), 1) ?? ''}';
    // CSS keys are not a human-readable title. A neutral title badge retains
    // its presence until the official asset/name is supplied.
    final titleName = RegExp(r'^[A-Za-z0-9_\-]+$').hasMatch(titleValue)
        ? (titleValue.isEmpty ? '' : '头衔')
        : titleValue;
    final light = liveInt(
      medal['is_light'] ?? medal['light'] ?? _at(oldMedal, 11),
    );
    return LiveUserBadges(
      rank:
          liveInt(
            data['online_rank'] ??
                liveMap(data['contribution'])['grade'] ??
                liveMap(user['level'])['online_rank'] ??
                _at(_at(info, 4), 3),
          ) ??
          0,
      wealth:
          liveInt(
            liveMap(user['wealth'])['level'] ??
                data['wealth_level'] ??
                liveMap(data['wealth_info'])['level'] ??
                _at(_at(info, 16), 0),
          ) ??
          0,
      guard:
          liveInt(
            liveMap(user['guard'])['level'] ??
                data['guard_level'] ??
                medal['guard_level'] ??
                medal['privilege'] ??
                _at(info, 7),
          ) ??
          0,
      manager: liveBool(data['isadmin'] ?? _at(_at(info, 2), 2)) == true,
      title: titleName,
      titleId: titleValue,
      medalAnchorUid:
          liveInt(medal['ruid'] ?? medal['target_id'] ?? _at(oldMedal, 12)) ??
          0,
      medalRoomId:
          liveInt(
            medal['room_id'] ?? medal['anchor_roomid'] ?? _at(oldMedal, 3),
          ) ??
          0,
      medalAnchorName: '${medal['anchor_uname'] ?? _at(oldMedal, 2) ?? ''}',
      titleImage: liveAssetUrl(title['url'] ?? title['image']),
      medalName: light == 0
          ? ''
          : '${medal['name'] ?? medal['medal_name'] ?? _at(oldMedal, 1) ?? ''}',
      medalLevel: liveInt(medal['level'] ?? _at(oldMedal, 0)) ?? 0,
      medalColor: '${medal['v2_medal_color_start'] ?? ''}',
      nameColor:
          '${base['name_color_str'] ?? data['uname_color'] ?? _at(_at(info, 2), 7) ?? ''}',
    );
  }
}
