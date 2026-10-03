import 'dart:convert';

import 'package:PiliPlus/models_new/live/gift/live_gift.dart';

enum LiveRedPacketType {
  gift(1, '礼物红包'),
  guard(2, '上舰红包'),
  battery(3, '电池红包');

  const LiveRedPacketType(this.id, this.label);
  final int id;
  final String label;
}

class LiveRedPacketPackage {
  const LiveRedPacketPackage({
    required this.id,
    required this.price,
    required this.enabled,
    required this.tips,
    required this.awards,
    required this.counts,
    required this.danmaku,
    required this.defaultRequirement,
  });
  final int id, price, defaultRequirement;
  final bool enabled;
  final String tips;
  final List<({String image, String name, int count})> awards;
  final List<int> counts;
  final List<({int id, String text})> danmaku;
  String get title => awards.isEmpty
      ? '${liveBatteryAmount(price)} 电池'
      : awards
            .map((a) => '${a.name.isEmpty ? '奖品' : a.name} × ${a.count}')
            .join('、');
  String get fingerprint => jsonEncode({
    'id': id,
    'price': price,
    'enabled': enabled,
    'tips': tips,
    'counts': counts,
    'requirement': defaultRequirement,
    'danmu': danmaku.map((d) => [d.id, d.text]).toList(),
    'awards': awards.map((a) => [a.image, a.name, a.count]).toList(),
  });
}

class LiveRedPacketConfig {
  const LiveRedPacketConfig(
    this.type,
    this.packages,
    this.durations,
    this.requirements,
  );
  final LiveRedPacketType type;
  final List<LiveRedPacketPackage> packages;
  final List<int> durations;
  final Map<int, String> requirements;

  static List<dynamic> _list(Iterable<dynamic> candidates) {
    for (final value in candidates) {
      if (value is List && value.isNotEmpty) return value;
    }
    return [];
  }

  static int _number(Iterable<dynamic> values) {
    for (final value in values) {
      if (value != null && value != '') return liveInt(value) ?? 0;
    }
    return 0;
  }

  static List<int> _positive(List<dynamic> values) =>
      values.map(liveInt).whereType<int>().where((v) => v > 0).toSet().toList();

  factory LiveRedPacketConfig.parse(
    LiveRedPacketType type,
    Map<String, dynamic> root,
  ) {
    final battery = liveMap(root['battery']);
    final isBattery = type == LiveRedPacketType.battery;
    final grades = isBattery
        ? _list([battery['grades'], root['grades'], root['item']])
        : _list([root['item']]);
    final durations = _positive(
      _list([
        root['duration_options'],
        root['durationOptions'],
        battery['duration_options'],
        battery['durationOptions'],
      ]),
    );
    final requirements = <int, String>{};
    for (final raw in _list([
      root['join_requirement_options'],
      root['joinRequirementOptions'],
      battery['join_requirement_options'],
      battery['joinRequirementOptions'],
    ])) {
      final item = liveMap(raw);
      final id = liveInt(
        raw is Map
            ? item['value'] ?? item['id'] ?? item['join_requirement']
            : raw,
      );
      if (id == null) continue;
      final label =
          item['text'] ??
          item['name'] ??
          item['title'] ??
          item['desc'] ??
          const {0: '全部观众', 1: '已关注观众', 2: '粉丝团成员'}[id];
      if (label != null) requirements[id] = '$label';
    }
    // The official battery form uses duration=0 and requirement=0 when its
    // optional selectors are absent. Gift/guard durations remain mandatory.
    if (isBattery && durations.isEmpty) durations.add(0);
    if (isBattery && requirements.isEmpty) requirements[0] = '全部观众';
    final enable = battery['enable'] ?? battery['is_enable'] ?? root['enable'];
    final packages = <LiveRedPacketPackage>[];
    for (final (index, raw) in grades.indexed) {
      final item = liveMap(raw);
      final price = isBattery
          ? _number([
              item['total_battery'],
              item['totalBattery'],
              item['total_price'],
              item['totalPrice'],
            ])
          : liveInt(item['gold_num']) ?? 0;
      final counts = isBattery
          ? _positive(
              _list([
                item['num_options'],
                item['numOptions'],
                item['award_num_options'],
                item['awardNumOptions'],
                item['battery_num_options'],
                item['batteryNumOptions'],
                [
                  item['award_num'],
                  item['awardNum'],
                  item['battery_num'],
                  item['batteryNum'],
                  item['total_num'],
                  item['totalNum'],
                ],
              ]),
            )
          : _positive([item['award_total_num']]);
      final awards = <({String image, String name, int count})>[];
      for (final award in _list([item['award_info']])) {
        final value = liveMap(award);
        // Guard text icon fields are images, not the name of the prize.
        awards.add((
          image: '${value['award_pic'] ?? ''}',
          name:
              '${value['award_name'] ?? value['gift_name'] ?? (type == LiveRedPacketType.guard ? '舰长' : '礼物')}',
          count: liveInt(value['award_num']) ?? 0,
        ));
      }
      final danmaku = <({int id, String text})>[];
      for (final raw in _list([
        item['danmu'],
        if (isBattery) battery['danmu'],
        if (isBattery) root['danmu'],
      ])) {
        final value = liveMap(raw);
        if (value['danmu'] is String) {
          danmaku.add((id: liveInt(value['id']) ?? 0, text: value['danmu']));
        }
      }
      packages.add(
        LiveRedPacketPackage(
          id: liveInt(item['id']) ?? (isBattery ? index + 1 : 0),
          price: price,
          enabled:
              price > 0 &&
              liveInt(item['can'] ?? (isBattery ? 1 : 0)) == 1 &&
              (!isBattery || (enable != false && enable != 0)),
          tips: '${item['tips'] ?? ''}',
          awards: awards,
          counts: counts,
          danmaku: danmaku,
          defaultRequirement: _number([
            item['join_requirement'],
            item['joinRequirement'],
          ]),
        ),
      );
    }
    return LiveRedPacketConfig(type, packages, durations, requirements);
  }
}

class LiveRedPacketSelection {
  const LiveRedPacketSelection({
    required this.type,
    required this.package,
    required this.duration,
    required this.count,
    required this.requirement,
    this.danmakuId = 0,
    this.danmakuText = '',
    this.requirementText = '',
  });
  final LiveRedPacketType type;
  final LiveRedPacketPackage package;
  final int duration, count, requirement, danmakuId;
  final String danmakuText;
  final String requirementText;
}

class LiveRedPacketConfirmation {
  const LiveRedPacketConfirmation(
    this.selection,
    this.uid,
    this.identity,
    this.operationId,
    this.expiresAt,
  );
  final LiveRedPacketSelection selection;
  final int uid;
  final Object identity;
  final String operationId;
  final DateTime expiresAt;
}
