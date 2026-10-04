import 'package:PiliPlus/pages/live_room/widgets/live_panel_surface.dart';
import 'package:material_ui/material_ui.dart';

class LiveRoomComposer extends StatelessWidget {
  const LiveRoomComposer({super.key, required this.bottomPadding,
    required this.onCompose, required this.onEmoji, required this.onGift,
    required this.likeButton});
  final double bottomPadding;
  final VoidCallback onCompose, onEmoji, onGift;
  final Widget likeButton;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(12, 5, 12, 5 + bottomPadding),
    child: SizedBox(height: 34, child: Row(children: [
      Expanded(child: Material(color: const Color(0x70263041),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(onTap: onCompose, borderRadius: BorderRadius.circular(24),
          child: Row(children: [
            const SizedBox(width: 12),
            const Expanded(child: Text('发个弹幕聊聊', maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: Colors.white70))),
            IconButton(tooltip: '表情弹幕', onPressed: onEmoji,
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.emoji_emotions_outlined, size: 19, color: Colors.white70)),
          ])))),
      const SizedBox(width: 6),
      SizedBox.square(dimension: 34, child: likeButton),
      const SizedBox(width: 6),
      IconButton.filled(tooltip: '礼物', onPressed: onGift,
        style: IconButton.styleFrom(backgroundColor: liveAccent,
          foregroundColor: Colors.white, fixedSize: const Size(34, 34),
          minimumSize: const Size(34, 34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap, padding: EdgeInsets.zero),
        icon: const Icon(Icons.card_giftcard_rounded, size: 22)),
    ])),
  );
}
