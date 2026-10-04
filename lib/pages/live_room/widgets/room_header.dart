import 'package:PiliPlus/pages/live_room/widgets/live_panel_surface.dart';
import 'package:material_ui/material_ui.dart';

class LiveAnchorChip extends StatelessWidget {
  const LiveAnchorChip({
    super.key,
    required this.avatar,
    required this.name,
    required this.subtitle,
    required this.followed,
    required this.onProfile,
    required this.onFollow,
  });
  final Widget avatar;
  final String name, subtitle;
  final bool followed;
  final VoidCallback onProfile;
  final VoidCallback? onFollow;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(3, 3, 4, 3),
    decoration: BoxDecoration(
      color: const Color(0x45212B36),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      spacing: 5,
      children: [
        GestureDetector(
          onTap: onProfile,
          child: SizedBox.square(dimension: 34, child: avatar),
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onProfile,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
        TextButton(
          onPressed: onFollow,
          style: TextButton.styleFrom(
            backgroundColor: liveAccent,
            foregroundColor: Colors.white,
            minimumSize: const Size(45, 30),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            followed ? '已关注' : '+ 关注',
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ],
    ),
  );
}

class LiveAudienceButton extends StatelessWidget {
  const LiveAudienceButton({
    super.key,
    required this.avatars,
    required this.count,
    required this.onTap,
  });
  final List<Widget> avatars;
  final String count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final visible = avatars.take(3).toList();
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Tooltip(
        message: '观众与大航海榜',
        child: SizedBox(
          height: 40,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (visible.isNotEmpty)
                SizedBox(
                  width: 27 + (visible.length - 1) * 20,
                  height: 27,
                  child: Stack(
                    children: [
                      for (final (index, avatar) in visible.indexed)
                        Positioned(
                          left: index * 20.0,
                          child: Container(
                            width: 27,
                            height: 27,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const [
                                  Color(0xFFE2BA69),
                                  Color(0xFFC2CDD9),
                                  Color(0xFFC3947C),
                                ][index],
                                width: 1.5,
                              ),
                            ),
                            child: avatar,
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(width: 3),
              Container(
                key: const ValueKey('live-audience-count'),
                width: 28,
                height: 28,
                padding: const EdgeInsets.all(3),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0x55212B36),
                  shape: BoxShape.circle,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    count,
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
