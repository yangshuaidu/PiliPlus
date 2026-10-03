import 'package:PiliPlus/models_new/live/live_medal_wall/uinfo_medal.dart';
import 'package:PiliPlus/models_new/live/gift/live_gift.dart';

class LiveContributionRankItem {
  int? uid;
  String? name;
  String? face;
  int? score;
  UinfoMedal? uinfoMedal;
  bool anonymous;

  LiveContributionRankItem({
    this.uid,
    this.name,
    this.face,
    this.score,
    this.uinfoMedal,
    this.anonymous = false,
  });

  factory LiveContributionRankItem.fromJson(Map<String, dynamic> json) {
    final uinfo = liveMap(json['uinfo']);
    final base = liveMap(uinfo['base']);
    final anonymous =
        liveBool(base['is_mystery']) == true ||
        liveBool(json['is_mystery']) == true ||
        liveBool(json['is_anonymous']) == true;
    UinfoMedal? medal;
    if (!anonymous && uinfo['medal'] is Map) {
      try {
        medal = UinfoMedal.fromJson(liveMap(uinfo['medal']));
      } catch (_) {}
    }
    return LiveContributionRankItem(
      uid: anonymous ? null : liveInt(json['uid'] ?? uinfo['uid']),
      name: anonymous ? '匿名观众' : (json['name'] ?? base['name'])?.toString(),
      face: anonymous ? null : (json['face'] ?? base['face'])?.toString(),
      score: liveInt(json['score']),
      anonymous: anonymous,
      uinfoMedal: medal,
    );
  }
}
