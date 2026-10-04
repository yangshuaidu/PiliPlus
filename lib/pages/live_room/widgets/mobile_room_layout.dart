import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Room skin is independent of the player and never used as a video cover.
class LiveRoomBackdrop extends StatelessWidget {
  const LiveRoomBackdrop({super.key, this.image});
  final ImageProvider? image;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF121218),
    child: image == null
        ? const SizedBox.expand()
        : Image(
            image: image!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, _, _) => const SizedBox.expand(),
          ),
  );
}

/// Shared by the live page and render tests. Player dimensions come from the
/// stream; device orientation only selects this mobile arrangement.
class LiveMobileRoomLayout extends StatelessWidget {
  const LiveMobileRoomLayout({
    super.key,
    required this.portraitSource,
    required this.aspectRatio,
    required this.padding,
    required this.header,
    required this.videoBuilder,
    required this.chat,
    required this.composer,
    required this.onCleanScreen,
    this.cleanScreen = false,
  });
  final bool portraitSource, cleanScreen;
  final double aspectRatio;
  final EdgeInsets padding;
  final Widget header, chat, composer;
  final Widget Function(Size) videoBuilder;
  final VoidCallback onCleanScreen;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final size = box.biggest;
      final headerHeight = padding.top + 62;
      final composerHeight = padding.bottom + 44;
      if (!portraitSource) {
        final ratio = aspectRatio > 0 && aspectRatio.isFinite
            ? aspectRatio
            : 16 / 9;
        final videoHeight = math.min(
          size.width / ratio,
          math.max(0.0, size.height - headerHeight - composerHeight - 8),
        );
        return Column(
          children: [
            SizedBox(height: headerHeight, child: header),
            const SizedBox(height: 8),
            SizedBox(
              key: const ValueKey('live-source-video'),
              width: size.width,
              height: videoHeight,
              child: videoBuilder(Size(size.width, videoHeight)),
            ),
            Expanded(child: chat),
            composer,
          ],
        );
      }
      return Stack(
        children: [
          Positioned.fill(
            key: const ValueKey('live-source-video'),
            child: videoBuilder(size),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x66000000),
                      Colors.transparent,
                      Colors.transparent,
                      Color(0x99000000),
                    ],
                    stops: [0, .25, .5, 1],
                  ),
                ),
              ),
            ),
          ),
          if (!cleanScreen) ...[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: headerHeight,
              child: header,
            ),
            Positioned(
              left: 0,
              right: 48,
              bottom: composerHeight + 5,
              height: size.height * .29,
              child: chat,
            ),
            Positioned(left: 0, right: 0, bottom: 0, child: composer),
          ],
          Positioned(
            right: 10,
            bottom: cleanScreen ? padding.bottom + 12 : composerHeight + 10,
            child: IconButton.filledTonal(
              tooltip: cleanScreen ? '退出清屏' : '清屏',
              onPressed: onCleanScreen,
              icon: Icon(
                cleanScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                size: 19,
              ),
            ),
          ),
        ],
      );
    },
  );
}
