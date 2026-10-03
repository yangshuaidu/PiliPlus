import 'package:PiliPlus/models_new/live/live_danmaku/live_user_badges.dart';
import 'package:material_ui/material_ui.dart';

List<InlineSpan> liveBadgeSpans(
  LiveUserBadges badges, {
  bool includeMedal = true,
}) {
  if (badges.anonymous) return const [];
  WidgetSpan badge(String label, Color color, {IconData? icon, String? tip}) =>
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 2),
          child: Tooltip(
            message: tip ?? label,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 11, color: Colors.white),
                    const SizedBox(width: 2),
                  ],
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 105),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.1,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  final guard = const {1: '总督', 2: '提督', 3: '舰长'}[badges.guard];
  return [
    if (badges.rank > 0 && badges.rank <= 100)
      badge(
        '榜${badges.rank}',
        const Color(0xffff795f),
        tip: '官方消息携带的榜单名次 ${badges.rank}',
      ),
    if (badges.wealth > 0)
      badge(
        '${badges.wealth}',
        const Color(0xff8b9fdc),
        icon: Icons.workspace_premium,
        tip: '荣耀等级 ${badges.wealth}',
      ),
    if (guard != null)
      badge(
        guard,
        badges.guard == 1
            ? const Color(0xffe89342)
            : badges.guard == 2
            ? const Color(0xffbb73d9)
            : const Color(0xff548cec),
        icon: Icons.anchor,
      ),
    if (includeMedal && badges.medalName.isNotEmpty && badges.medalLevel > 0)
      badge(
        '${badges.medalName} ${badges.medalLevel}',
        _badgeColor(badges.medalColor) ?? const Color(0xff658fec),
      ),
    if (badges.titleImage.isNotEmpty)
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Image.network(
            badges.titleImage,
            width: 72,
            height: 22,
            errorBuilder: (_, _, _) =>
                const Text('头衔', style: TextStyle(fontSize: 10)),
          ),
        ),
      )
    else if (badges.title.isNotEmpty)
      badge(badges.title, const Color(0xffa57ccc)),
    if (badges.manager) badge('房', const Color(0xffed9537), tip: '房管'),
  ];
}

Color? _badgeColor(String value) {
  if (!RegExp(r'^#[a-fA-F0-9]{6}([a-fA-F0-9]{2})?$').hasMatch(value))
    return null;
  return Color(0xff000000 | int.parse(value.substring(1, 7), radix: 16));
}

Color? liveNameColor(String value) => _badgeColor(value);
