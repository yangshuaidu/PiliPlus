import 'package:PiliPlus/models_new/live/gift/live_gift.dart';

class LiveDanmakuStyleOption {
  const LiveDanmakuStyleOption(this.value, this.name, this.enabled);
  final int value;
  final String name;
  final bool enabled;
}

class LiveDanmakuStyleConfig {
  const LiveDanmakuStyleConfig(this.modes, this.colors);
  final List<LiveDanmakuStyleOption> modes;
  final Map<String, List<LiveDanmakuStyleOption>> colors;
  static bool _enabled(dynamic value) => value == true || liveInt(value) == 1;
  factory LiveDanmakuStyleConfig.parse(Map<String, dynamic> data) {
    final modes = <LiveDanmakuStyleOption>[
      for (final item in liveMaps(data['mode']))
        if (liveInt(item['mode']) case final mode?
            when {1, 4, 5}.contains(mode))
          LiveDanmakuStyleOption(
            mode,
            '${item['name'] ?? const {1: '滚动', 4: '底部', 5: '顶部'}[mode]}',
            _enabled(item['status']),
          ),
    ];
    final colors = <String, List<LiveDanmakuStyleOption>>{};
    for (final group in liveMaps(data['group'])) {
      colors['${group['name'] ?? '弹幕颜色'}'] = [
        for (final item in liveMaps(group['color']))
          if (int.tryParse(
                '${item['color_hex']}'
                    .replaceFirst('#', '')
                    .replaceFirst('0x', ''),
                radix: 16,
              )
              case final color? when color >= 0 && color <= 0xffffff)
            LiveDanmakuStyleOption(
              color,
              '${item['name'] ?? '颜色'}',
              _enabled(item['status']),
            ),
      ];
    }
    return LiveDanmakuStyleConfig(modes, colors);
  }
  bool permits(int mode, int color) =>
      modes.any((m) => m.value == mode && m.enabled) &&
      colors.values.expand((v) => v).any((c) => c.value == color && c.enabled);
}
