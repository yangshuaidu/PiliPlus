import 'package:PiliPlus/pages/live_room/widgets/live_panel_surface.dart';
import 'package:material_ui/material_ui.dart';

class LiveMenuAction {
  const LiveMenuAction(this.label, this.icon, this.onSelected);
  final String label;
  final IconData icon;
  final VoidCallback onSelected;
}

/// The route returns before starting the next action, so only one sheet owns
/// input and focus at a time.
Future<void> showLiveActionMenu(
  BuildContext context, {
  required String title,
  required List<LiveMenuAction> actions,
  List<LiveMenuAction> sharing = const [],
}) async {
  final selected = await showLivePanel<LiveMenuAction>(
    context,
    (context) => LivePanelSurface(
      child: Column(
        children: [
          LiveSheetHeading(title: title),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  if (sharing.isNotEmpty) ...[
                    _ActionGrid(actions: sharing, columns: 3),
                    const Divider(height: 24),
                  ],
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final largeText =
                          MediaQuery.textScalerOf(context).scale(12) > 17;
                      return _ActionGrid(
                        actions: actions,
                        columns: largeText || constraints.maxWidth < 330
                            ? 3
                            : 4,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
  if (context.mounted) selected?.onSelected();
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.actions, required this.columns});
  final List<LiveMenuAction> actions;
  final int columns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: 4,
      runSpacing: 10,
      children: [
        for (final action in actions)
          SizedBox(
            width: (constraints.maxWidth - (columns - 1) * 4) / columns,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.pop(context, action),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .07),
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox.square(
                        dimension: 46,
                        child: Icon(action.icon, size: 23, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      action.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, height: 1.3),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class LiveSheetHeading extends StatelessWidget {
  const LiveSheetHeading({super.key, required this.title, this.onBack});
  final String title;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SizedBox(height: 9),
      Container(
        width: 32,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(left: 16, right: 8),
        child: Row(
          children: [
            if (onBack != null)
              IconButton(
                tooltip: '返回',
                onPressed: onBack,
                icon: const Icon(Icons.chevron_left),
              ),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              tooltip: '关闭',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, size: 21),
            ),
          ],
        ),
      ),
    ],
  );
}
