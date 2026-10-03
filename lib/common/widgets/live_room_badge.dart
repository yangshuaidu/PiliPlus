import 'package:PiliPlus/common/assets.dart';
import 'package:PiliPlus/utils/extension/num_ext.dart';
import 'package:material_ui/material_ui.dart';

/// The badge handles its own tap, including while a room lookup is pending.
/// This keeps taps from opening a surrounding conversation or profile instead.
class LiveRoomBadge extends StatefulWidget {
  final Future<void> Function() onOpen;
  final double height;
  const LiveRoomBadge({super.key, required this.onOpen, this.height = 15});

  @override
  State<LiveRoomBadge> createState() => _LiveRoomBadgeState();
}

class _LiveRoomBadgeState extends State<LiveRoomBadge> {
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await widget.onOpen();
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Tooltip(
    message: '进入直播间',
    child: Semantics(
      label: '直播中，进入直播间',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _open,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: _opening ? 0.25 : 1,
                  child: Image.asset(
                    Assets.livingRect,
                    height: widget.height,
                    cacheHeight: widget.height.cacheSize(context),
                    filterQuality: FilterQuality.low,
                    excludeFromSemantics: true,
                  ),
                ),
                if (_opening)
                  SizedBox.square(
                    dimension: widget.height,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
