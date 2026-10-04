import 'package:PiliPlus/pages/live_room/controller.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/widgets/play_pause_btn.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class BottomControl extends StatelessWidget {
  const BottomControl({
    super.key,
    required this.plPlayerController,
    required this.liveRoomCtr,
    required this.onMore,
    required this.onQuality,
  });
  final PlPlayerController plPlayerController;
  final LiveRoomController liveRoomCtr;
  final VoidCallback onMore, onQuality;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    child: Material(
      type: MaterialType.transparency,
      child: Row(
        children: [
          SizedBox.square(
            dimension: 44,
            child: PlayOrPauseButton(plPlayerController: plPlayerController),
          ),
          const SizedBox(width: 5),
          const Icon(Icons.circle, color: Color(0xFFFB7299), size: 6),
          const SizedBox(width: 5),
          const Text(
            '直播',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const Spacer(),
          TextButton(
            onPressed: onQuality,
            child: Obx(
              () => Text(
                liveRoomCtr.currentQnDesc.value,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
          if (!plPlayerController.isDesktopPip)
            IconButton(
              tooltip: plPlayerController.isFullScreen.value ? '退出全屏' : '全屏',
              onPressed: () => plPlayerController.triggerFullScreen(
                status: !plPlayerController.isFullScreen.value,
              ),
              icon: Icon(
                plPlayerController.isFullScreen.value
                    ? Icons.fullscreen_exit
                    : Icons.fullscreen,
                color: Colors.white,
                size: 24,
              ),
            ),
          IconButton(
            tooltip: '更多',
            onPressed: onMore,
            icon: const Icon(Icons.more_horiz, color: Colors.white, size: 22),
          ),
        ],
      ),
    ),
  );
}
