import 'package:PiliPlus/models_new/live/live_wealth_assets.dart';
import 'package:material_ui/material_ui.dart';

/// Uses the complete official level artwork, including its printed number.
class LiveWealthBadge extends StatelessWidget {
  const LiveWealthBadge({
    super.key,
    required this.level,
    this.height = 16,
    this.image,
  });
  final int level;
  final double height;
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    if (level <= 0) return const SizedBox.shrink();
    final url = liveWealthAssets[level];
    Widget fallback() =>
        Text('Lv.$level', style: TextStyle(fontSize: height * .7));
    return Semantics(
      label: '荣耀等级 $level',
      child: SizedBox(
        width: height * 36 / 16,
        height: height,
        child: url == null
            ? fallback()
            : Image(
                image: image ?? NetworkImage(url),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => fallback(),
              ),
      ),
    );
  }
}
