import 'package:PiliPlus/models_new/live/live_contribution_rank/item.dart';
import 'package:PiliPlus/models_new/live/gift/live_gift.dart';

class LiveContributionRankData {
  List<LiveContributionRankItem>? item;
  int? count;
  String? countText;
  LiveContributionRankItem? own;

  LiveContributionRankData({
    this.item,
    this.count,
    this.countText,
    this.own,
  });

  factory LiveContributionRankData.fromJson(Map<String, dynamic> json) =>
      LiveContributionRankData(
        count: liveInt(json['count'] ?? json['total_count']),
        countText: json['count_text']?.toString(),
        own: json['own_info'] is Map
            ? LiveContributionRankItem.fromJson(liveMap(json['own_info']))
            : null,
        item: (json['item'] as List<dynamic>?)
            ?.map(
              (e) =>
                  LiveContributionRankItem.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      );
}
