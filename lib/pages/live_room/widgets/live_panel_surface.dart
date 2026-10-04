import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoTheme, CupertinoThemeData;
import 'package:material_ui/material_ui.dart';

const liveAccent = Color(0xFFFB7299);
const livePanelBackground = Color(0xFF1C1B23);

class LiveChoiceChip extends StatelessWidget {
  const LiveChoiceChip({super.key, required this.label, required this.selected,
    required this.onSelected});
  final Widget label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: label, selected: selected, onSelected: onSelected, showCheckmark: false,
    labelStyle: const TextStyle(fontSize: 12),
    labelPadding: const EdgeInsets.symmetric(horizontal: 7),
    padding: const EdgeInsets.symmetric(vertical: 2),
    visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
  );
}

class LivePaymentFooter extends StatelessWidget {
  const LivePaymentFooter({super.key, required this.amount,
    required this.actionKey, required this.onNext});
  final String amount;
  final Key actionKey;
  final VoidCallback? onNext;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white12))),
    child: Row(children: [
      Expanded(child: Text(amount, style: const TextStyle(fontSize: 13),
        maxLines: 2, overflow: TextOverflow.ellipsis)),
      const SizedBox(width: 12),
      FilledButton(key: actionKey, onPressed: onNext,
        style: FilledButton.styleFrom(minimumSize: const Size(96, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        child: const Text('下一步', style: TextStyle(fontSize: 13))),
    ]),
  );
}

/// Compact bottom panels in portrait; a trailing panel leaves the video visible
/// in landscape. Keyboard space and safe areas are deducted before sizing.
Size livePanelSize(
  MediaQueryData media, {
  bool gift = false,
  double sourceAspectRatio = 16 / 9,
}) {
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
      ? math.min(
          496.0,
          math.min(
            height * .66,
            sourceAspectRatio < 1
                ? height
                : math.max(240.0, height - 72 - size.width / sourceAspectRatio),
          ),
        )
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
  const LivePanelSurface({
    super.key,
    required this.child,
    this.gift = false,
    this.sourceAspectRatio = 16 / 9,
    this.accent = liveAccent,
    this.background = livePanelBackground,
  });
  final Widget child;
  final bool gift;
  final double sourceAspectRatio;
  final Color accent, background;

  @override
  Widget build(BuildContext context) {
    final size = livePanelSize(
      MediaQuery.of(context),
      gift: gift,
      sourceAspectRatio: sourceAspectRatio,
    );
    final base = Theme.of(context);
    final colors = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    ).copyWith(primary: accent, surface: background);
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
          data: CupertinoThemeData(
            brightness: Brightness.dark,
            primaryColor: accent,
          ),
          child: Material(
            color: background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(top: false, child: child),
          ),
        ),
      ),
    );
  }
}
