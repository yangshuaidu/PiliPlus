import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoTheme, CupertinoThemeData;
import 'package:material_ui/material_ui.dart';

const liveAccent = Color(0xFFFB7299);
const livePanelBackground = Color(0xFF1C1B23);

/// Compact bottom panels in portrait; a trailing panel leaves the video visible
/// in landscape. Keyboard space and safe areas are deducted before sizing.
Size livePanelSize(MediaQueryData media, {bool gift = false}) {
  final size = media.size;
  final height = math.max(
    0.0,
    size.height - media.padding.top - media.viewInsets.bottom,
  );
  final side = size.width >= 600 && size.width > size.height;
  if (side) return Size(math.min(420.0, size.width * .48), height);
  final desired = media.viewInsets.bottom > 0 || height < 400
      ? height * .9
      : gift
      ? math.min(496.0, math.min(height * .66, height - 70 - size.width / (16 / 9)))
      : math.min(420.0, height * .48);
  return Size(math.min(520.0, size.width), desired);
}

Future<T?> showLivePanel<T>(BuildContext context, WidgetBuilder builder) =>
    showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭面板',
      barrierColor: Colors.black.withValues(alpha: .12),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, _, _) {
        final media = MediaQuery.of(context);
        final side =
            media.size.width >= 600 && media.size.width > media.size.height;
        return Padding(
          padding: EdgeInsets.only(
            top: media.padding.top,
            bottom: media.viewInsets.bottom,
            right: side ? media.padding.right : 0,
          ),
          child: Align(
            alignment: side ? Alignment.centerRight : Alignment.bottomCenter,
            child: builder(context),
          ),
        );
      },
      transitionBuilder: (context, animation, _, child) => SlideTransition(
        position: Tween(begin: const Offset(0, .12), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: FadeTransition(opacity: animation, child: child),
      ),
    );

class LivePanelSurface extends StatelessWidget {
  const LivePanelSurface({super.key, required this.child, this.gift = false});
  final Widget child;
  final bool gift;

  @override
  Widget build(BuildContext context) {
    final size = livePanelSize(MediaQuery.of(context), gift: gift);
    final base = Theme.of(context);
    final colors = ColorScheme.fromSeed(
      seedColor: liveAccent,
      brightness: Brightness.dark,
    ).copyWith(primary: liveAccent, surface: livePanelBackground);
    return SizedBox(
      key: const ValueKey('live-panel-surface'),
      width: size.width,
      height: size.height,
      child: Theme(
        data: base.copyWith(
          brightness: Brightness.dark,
          colorScheme: colors,
          textTheme: base.textTheme.apply(
            bodyColor: Colors.white,
            displayColor: Colors.white,
          ),
          iconTheme: const IconThemeData(color: Colors.white70),
          dividerColor: Colors.white12,
        ),
        child: CupertinoTheme(
          data: const CupertinoThemeData(
            brightness: Brightness.dark,
            primaryColor: liveAccent,
          ),
          child: Material(
            color: livePanelBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(top: false, child: child),
          ),
        ),
      ),
    );
  }
}
